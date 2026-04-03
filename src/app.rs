//! Root application state and eframe `App` implementation.

use eframe::egui;
use vti_core::Module;
use vti_ay::chip::ChipType;
use vti_ay::config::AyConfig;
use vti_ay::synth::Synthesizer;
use vti_core::playback::{Engine, PlayVars, init_tracker_parameters, PlayResult};
use vti_audio::AudioPlayer;

use crate::ui::{PatternEditor, SampleEditor, OrnamentEditor, Toolbar};

/// Top-level application state.
pub struct VortexTrackerApp {
    /// The currently open modules (Turbo-Sound allows up to 2).
    pub modules: Vec<Module>,
    /// Index of the currently focused module.
    pub active_module: usize,

    // UI panels
    pub toolbar: Toolbar,
    pub pattern_editor: PatternEditor,
    pub sample_editor: SampleEditor,
    pub ornament_editor: OrnamentEditor,

    /// Which editor panel is shown in the bottom half.
    pub bottom_panel: BottomPanel,

    // Playback state
    pub is_playing: bool,
    pub play_mode: PlayMode,

    // Audio engine
    audio: Option<AudioPlayer>,
    synth: Synthesizer,
    play_vars: PlayVars,
    /// Samples to render per 50 Hz interrupt tick.
    samples_per_tick: u32,
    /// `ctx.input(|i| i.time)` at the last engine tick.
    last_tick_time: f64,

    // Status bar text
    pub status: String,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Default)]
pub enum BottomPanel {
    #[default]
    Sample,
    Ornament,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Default)]
pub enum PlayMode {
    #[default]
    Module,
    Pattern,
    Line,
}

impl VortexTrackerApp {
    pub fn new(_cc: &eframe::CreationContext<'_>) -> Self {
        let mut modules = vec![Module::default()];

        // Ensure there is at least one pattern to edit
        let pat_idx = vti_core::Module::pat_idx(0);
        modules[0].patterns[pat_idx] = Some(Box::new(vti_core::Pattern::default()));

        // Set up a minimal playable song: one position → pattern 0
        modules[0].positions.value[0] = 0;
        modules[0].positions.length = 1;
        modules[0].positions.loop_pos = 0;
        modules[0].initial_delay = 3;

        // Sample 1: sustained tone (amplitude 13, tone enabled, noise off, looping)
        let mut sample = vti_core::Sample::default();
        sample.length = 1;
        sample.loop_pos = 0;
        sample.items[0].amplitude = 13;
        sample.items[0].mixer_ton = true;   // true → tone bit NOT set → tone channel ON
        sample.items[0].mixer_noise = false; // false → noise bit set → noise channel OFF
        modules[0].samples[1] = Some(Box::new(sample));

        // Pattern 0, row 0: play A-4 (note 45) on channel A with sample 1, volume 15
        let pat = modules[0].patterns[pat_idx].as_mut().unwrap();
        pat.items[0].channel[0].note   = 45;
        pat.items[0].channel[0].sample = 1;
        pat.items[0].channel[0].volume = 15;

        // Audio / synthesis setup
        let cfg = AyConfig::default();
        let samples_per_tick = cfg.sample_tiks_in_interrupt();
        let synth = Synthesizer::new(cfg, 1, ChipType::AY);

        let mut play_vars = PlayVars::default();
        init_tracker_parameters(&mut modules[0], &mut play_vars, true);
        play_vars.delay = modules[0].initial_delay as i8;
        play_vars.current_pattern = modules[0].positions.value[0] as i32;

        // The AudioPlayer is opened lazily — when the user first presses Play.
        // On WASM this is required by the browser autoplay policy (AudioContext
        // must be created inside a user-gesture handler).  On native platforms
        // there is no such restriction, but lazy init works equally well there.
        let audio = None;

        Self {
            modules,
            active_module: 0,
            toolbar: Toolbar::default(),
            pattern_editor: PatternEditor::default(),
            sample_editor: SampleEditor::default(),
            ornament_editor: OrnamentEditor::default(),
            bottom_panel: BottomPanel::default(),
            is_playing: false,
            play_mode: PlayMode::default(),
            audio,
            synth,
            play_vars,
            samples_per_tick,
            last_tick_time: 0.0,
            status: "Ready".to_string(),
        }
    }

    fn active_module(&self) -> &Module {
        &self.modules[self.active_module]
    }

    fn active_module_mut(&mut self) -> &mut Module {
        &mut self.modules[self.active_module]
    }

    /// Try to open the audio output device and return an `AudioPlayer`.
    /// Logs a warning and returns `None` if the device is unavailable.
    fn try_open_audio() -> Option<AudioPlayer> {
        match AudioPlayer::start(44100) {
            Ok(p)  => { log::info!("audio player started"); Some(p) }
            Err(e) => { log::warn!("audio unavailable: {e}"); None }
        }
    }

    /// Re-initialise playback state so the next Play starts from the beginning.
    fn reset_playback(&mut self) {
        init_tracker_parameters(&mut self.modules[self.active_module], &mut self.play_vars, true);
        self.play_vars.delay = self.modules[self.active_module].initial_delay as i8;
        self.play_vars.current_pattern =
            if self.modules[self.active_module].positions.length > 0 {
                self.modules[self.active_module].positions.value[0] as i32
            } else {
                0
            };
    }

    /// Render one 50 Hz tracker tick: advance the engine, synthesise samples, push to audio.
    fn tick_audio(&mut self) {
        let mut ay_regs = vti_core::AyRegisters::default();

        let result = {
            let module = &mut self.modules[self.active_module];
            let vars   = &mut self.play_vars;
            let mut engine = Engine { module, vars };
            match self.play_mode {
                PlayMode::Module  => engine.module_play_current_line(&mut ay_regs),
                PlayMode::Pattern => engine.pattern_play_current_line(&mut ay_regs),
                PlayMode::Line    => {
                    engine.pattern_play_only_current_line(&mut ay_regs);
                    PlayResult::Updated
                }
            }
        };

        if result == PlayResult::ModuleLoop && self.play_mode == PlayMode::Module {
            // Module looped — keep playing (normal loop behaviour)
        }

        self.synth.apply_registers(0, &ay_regs);
        self.synth.render_frame(self.samples_per_tick);
        let samples = self.synth.drain(self.samples_per_tick as usize);

        if let Some(ref player) = self.audio {
            player.push_samples(&samples);
        }
    }
}

impl eframe::App for VortexTrackerApp {
    fn update(&mut self, ctx: &egui::Context, _frame: &mut eframe::Frame) {
        // ── Audio tick driver ──────────────────────────────────────────────
        // Tick the tracker engine at ~50 Hz whenever playback is active.
        const TICK_INTERVAL: f64 = 1.0 / 50.0;
        if self.is_playing {
            let now = ctx.input(|i| i.time);
            if self.last_tick_time == 0.0 {
                self.last_tick_time = now;
            }
            while self.last_tick_time + TICK_INTERVAL <= now {
                self.last_tick_time += TICK_INTERVAL;
                self.tick_audio();
            }
            // Schedule a repaint in ~10 ms so the audio loop stays smooth.
            ctx.request_repaint_after(std::time::Duration::from_millis(10));
        }

        // ── Menu bar ───────────────────────────────────────────────────────
        egui::TopBottomPanel::top("menu_bar").show(ctx, |ui| {
            egui::menu::bar(ui, |ui| {
                ui.menu_button("File", |ui| {
                    if ui.button("New").clicked() {
                        self.modules = vec![Module::default()];
                        self.active_module = 0;
                        self.is_playing = false;
                        self.reset_playback();
                        self.status = "New module created".to_string();
                        ui.close_menu();
                    }
                    if ui.button("Open…").clicked() {
                        // TODO: rfd file dialog + format detection (PLAN.md §5)
                        self.status = "Open not yet implemented".to_string();
                        ui.close_menu();
                    }
                    if ui.button("Save…").clicked() {
                        // TODO: PT3 writer (PLAN.md §3.3)
                        self.status = "Save not yet implemented".to_string();
                        ui.close_menu();
                    }
                    ui.separator();
                    if ui.button("Quit").clicked() {
                        ctx.send_viewport_cmd(egui::ViewportCommand::Close);
                    }
                });
                ui.menu_button("Help", |ui| {
                    if ui.button("About").clicked() {
                        // TODO: about dialog (PLAN.md §6)
                        self.status = "Vortex Tracker II — Rust port. Original by Sergey Bulba.".to_string();
                        ui.close_menu();
                    }
                });
            });
        });

        // ── Toolbar ────────────────────────────────────────────────────────
        egui::TopBottomPanel::top("toolbar").show(ctx, |ui| {
            let was_playing = self.is_playing;
            self.toolbar.show(ui, &mut self.is_playing, &mut self.play_mode, &mut self.status);
            // When play transitions false→true, reset the playback cursor.
            if !was_playing && self.is_playing {
                self.reset_playback();
                self.last_tick_time = 0.0;
                // Open the audio device on first Play press (satisfies the browser
                // autoplay policy on WASM; harmless no-op on subsequent presses).
                if self.audio.is_none() {
                    self.audio = Self::try_open_audio();
                }
                let audio_status = if self.audio.is_some() { "Playing" } else { "Playing (no audio device)" };
                self.status = audio_status.to_string();
            }
            // When stopped, reset so next Play starts from the beginning.
            if was_playing && !self.is_playing {
                self.reset_playback();
                self.last_tick_time = 0.0;
            }
        });

        // ── Status bar ─────────────────────────────────────────────────────
        egui::TopBottomPanel::bottom("status_bar").show(ctx, |ui| {
            ui.horizontal(|ui| {
                ui.label(&self.status);
            });
        });

        // ── Bottom editor panel switcher ───────────────────────────────────
        egui::TopBottomPanel::bottom("bottom_tabs").show(ctx, |ui| {
            ui.horizontal(|ui| {
                ui.selectable_value(&mut self.bottom_panel, BottomPanel::Sample,   "Samples");
                ui.selectable_value(&mut self.bottom_panel, BottomPanel::Ornament, "Ornaments");
            });
        });

        // ── Bottom editor panel ────────────────────────────────────────────
        egui::TopBottomPanel::bottom("bottom_editor")
            .resizable(true)
            .default_height(200.0)
            .show(ctx, |ui| {
                let module = &mut self.modules[self.active_module];
                match self.bottom_panel {
                    BottomPanel::Sample => {
                        self.sample_editor.show(ui, module);
                    }
                    BottomPanel::Ornament => {
                        self.ornament_editor.show(ui, module);
                    }
                }
            });

        // ── Central area: pattern editor ──────────────────────────────────
        egui::CentralPanel::default().show(ctx, |ui| {
            let module = &mut self.modules[self.active_module];
            self.pattern_editor.show(ui, module);
        });
    }
}
