//! Root application state and eframe `App` implementation.

use eframe::egui;
use vti_core::{Module, Pattern, Sample, SampleTick, Ornament, ChannelLine, AdditionalCommand};
use vti_ay::chip::ChipType;
use vti_ay::config::AyConfig;
use vti_ay::synth::Synthesizer;
use vti_core::playback::{Engine, PlayVars, init_tracker_parameters, PlayResult};
use vti_audio::AudioPlayer;
use vti_core::formats;

#[cfg(target_arch = "wasm32")]
use crate::wasm_file;
#[cfg(target_arch = "wasm32")]
use crate::pending_file;

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

    /// If `Some`, an egui modal error dialog is shown with this message.
    /// Mirrors the Delphi `MessageBox(…, MB_ICONEXCLAMATION)` on load failure.
    pub error_dialog: Option<String>,
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

// ─── Demo module ─────────────────────────────────────────────────────────────

/// Build the demo module that plays on start-up.
///
/// Three-channel arpeggio (I–V–vi–IV chord progression) with a decaying noise
/// drum on channel C at beats 1 and 3.  The pattern is 16 rows long and loops
/// forever so the user hears something interesting the moment they press Play.
///
/// Note encoding: octave N starts at note `(N-1)*12`; C-1 = 0, C-4 = 36, etc.
fn make_demo_module() -> Module {
    let mut module = Module::default();
    module.initial_delay = 3; // 3 interrupt ticks per row (50 Hz → ~17 ms per row)

    // ─── Sample 1 – lead arpeggio tone ───────────────────────────────────────
    // Sustains at full amplitude; loops on the single tick.
    let mut lead = Sample::default();
    lead.length = 1;
    lead.loop_pos = 0;
    lead.items[0] = SampleTick {
        amplitude: 14,
        mixer_ton: true,    // tone ON
        mixer_noise: false, // noise OFF
        ..SampleTick::default()
    };
    module.samples[1] = Some(Box::new(lead));

    // ─── Sample 2 – bass arpeggio tone ───────────────────────────────────────
    // Same as sample 1 but quieter for the lower register.
    let mut bass_samp = Sample::default();
    bass_samp.length = 1;
    bass_samp.loop_pos = 0;
    bass_samp.items[0] = SampleTick {
        amplitude: 10,
        mixer_ton: true,
        mixer_noise: false,
        ..SampleTick::default()
    };
    module.samples[2] = Some(Box::new(bass_samp));

    // ─── Sample 3 – noise drum ────────────────────────────────────────────────
    // Eight ticks of decaying noise; loops on the final silent tick so that
    // the drum stops naturally without a sound-off note.
    let mut drum = Sample::default();
    drum.length = 8;
    drum.loop_pos = 7; // stay on tick 7 (amplitude 0) once the decay finishes
    let drum_amps: [u8; 8] = [15, 13, 11, 9, 7, 5, 2, 0];
    for (i, &amp) in drum_amps.iter().enumerate() {
        drum.items[i] = SampleTick {
            amplitude: amp,
            mixer_ton: false,  // no tone – pure noise hit
            mixer_noise: true, // noise ON
            // add_to_envelope_or_noise sets the noise period when mixer_noise=true
            add_to_envelope_or_noise: 12, // noise period → snappy drum timbre
            ..SampleTick::default()
        };
    }
    module.samples[3] = Some(Box::new(drum));

    // ─── Ornament 0 – already installed as zero-offset default ───────────────

    // ─── Ornament 1 – major arpeggio [0, +4, +7] ─────────────────────────────
    // Steps through the root, major third and perfect fifth of any chord.
    let mut orn_major = Ornament::default();
    orn_major.length = 3;
    orn_major.loop_pos = 0;
    orn_major.items[0] = 0;
    orn_major.items[1] = 4;
    orn_major.items[2] = 7;
    module.ornaments[1] = Some(Box::new(orn_major));

    // ─── Ornament 2 – minor arpeggio [0, +3, +7] ─────────────────────────────
    let mut orn_minor = Ornament::default();
    orn_minor.length = 3;
    orn_minor.loop_pos = 0;
    orn_minor.items[0] = 0;
    orn_minor.items[1] = 3;
    orn_minor.items[2] = 7;
    module.ornaments[2] = Some(Box::new(orn_minor));

    // ─── Pattern 0 – 16-row I–V–vi–IV progression ────────────────────────────
    // With initial_delay=3 and a 3-step looping ornament the arpeggio cycles
    // C→E→G (or the chord variant) once per row, producing a classic chiptune
    // arpeggio effect.
    //
    // Row  0: C major (C-5 / C-3) + noise drum on Ch C
    // Row  4: G major (G-4 / G-3)
    // Row  8: A minor (A-4 / A-3) + noise drum on Ch C
    // Row 12: F major (F-4 / F-3)
    let make_chan = |note: i8, sample: u8, ornament: u8, volume: u8| ChannelLine {
        note,
        sample,
        ornament,
        volume,
        envelope: 0,
        additional_command: AdditionalCommand::default(),
    };

    let pat_idx = Module::pat_idx(0);
    let mut pat = Pattern::default();
    pat.length = 16;

    // Row 0: C major (I)
    pat.items[0].channel[0] = make_chan(48, 1, 1, 15); // C-5 lead
    pat.items[0].channel[1] = make_chan(24, 2, 1, 12); // C-3 bass
    pat.items[0].channel[2] = make_chan(0,  3, 0, 15); // noise drum

    // Row 4: G major (V)
    pat.items[4].channel[0] = make_chan(43, 1, 1, 15); // G-4 lead
    pat.items[4].channel[1] = make_chan(31, 2, 1, 12); // G-3 bass

    // Row 8: A minor (vi)
    pat.items[8].channel[0] = make_chan(45, 1, 2, 15); // A-4 lead (minor arpeggio)
    pat.items[8].channel[1] = make_chan(33, 2, 2, 12); // A-3 bass
    pat.items[8].channel[2] = make_chan(0,  3, 0, 15); // noise drum

    // Row 12: F major (IV)
    pat.items[12].channel[0] = make_chan(41, 1, 1, 15); // F-4 lead
    pat.items[12].channel[1] = make_chan(29, 2, 1, 12); // F-3 bass

    module.patterns[pat_idx] = Some(Box::new(pat));

    // ─── Position list (single looping position) ──────────────────────────────
    module.positions.length = 1;
    module.positions.value[0] = 0;
    module.positions.loop_pos = 0;

    module
}

impl VortexTrackerApp {
    pub fn new(_cc: &eframe::CreationContext<'_>) -> Self {
        let mut modules = vec![make_demo_module()];

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
            error_dialog: None,
        }
    }

    fn active_module(&self) -> &Module {
        &self.modules[self.active_module]
    }

    fn active_module_mut(&mut self) -> &mut Module {
        &mut self.modules[self.active_module]
    }

    /// Set the status bar text and raise a modal error dialog with the same
    /// message.  Mirrors the Delphi `MessageBox(…, MB_ICONEXCLAMATION)` called
    /// whenever a file fails to open or parse.
    fn set_error(&mut self, msg: impl Into<String>) {
        let msg = msg.into();
        self.status = msg.clone();
        self.error_dialog = Some(msg);
    }

    /// Try to open the audio output device and return an `AudioPlayer`.
    /// Logs a warning and returns `None` if the device is unavailable.
    fn try_open_audio() -> Option<AudioPlayer> {
        match AudioPlayer::start(44100) {
            Ok(p)  => { log::info!("audio player started"); Some(p) }
            Err(e) => { log::warn!("audio unavailable: {e}"); None }
        }
    }

    /// Open a file-picker dialog and load the chosen module.
    ///
    /// Supported extensions: `.vtm`, `.pt3`, `.pt2`, `.pt1`, `.stc`, `.stp`.
    /// On WASM this is a no-op (file access is handled separately via the
    /// browser `<input type="file">` element — see PLAN.md §8).
    #[cfg(not(target_arch = "wasm32"))]
    fn open_file_dialog(&mut self) {
        let path = rfd::FileDialog::new()
            .add_filter(
                "Tracker modules",
                &["vtm", "pt3", "pt2", "pt1", "stc", "stp"],
            )
            .add_filter("VTM text (*.vtm)", &["vtm"])
            .add_filter("Pro Tracker 3 (*.pt3)", &["pt3"])
            .add_filter("Pro Tracker 2 (*.pt2)", &["pt2"])
            .add_filter("Pro Tracker 1 (*.pt1)", &["pt1"])
            .add_filter("Sound Tracker Compiled (*.stc)", &["stc"])
            .add_filter("Sound Tracker Pro (*.stp)", &["stp"])
            .add_filter("All files", &["*"])
            .pick_file();

        let Some(path) = path else {
            return; // user cancelled
        };

        match std::fs::read(&path) {
            Err(e) => {
                self.set_error(format!("Open failed: {e}"));
            }
            Ok(bytes) => {
                let filename = path
                    .file_name()
                    .and_then(|n| n.to_str())
                    .unwrap_or("file");
                match formats::load(&bytes, filename) {
                    Ok(module) => {
                        self.is_playing = false;
                        self.modules = vec![module];
                        self.active_module = 0;
                        self.reset_playback();
                        self.status = format!("Loaded: {}", filename);
                    }
                    Err(e) => {
                        self.set_error(format!("Parse error: {e}"));
                    }
                }
            }
        }
    }

    #[cfg(target_arch = "wasm32")]
    fn open_file_dialog(&mut self) {
        if !wasm_file::open_picker_supported() {
            self.status =
                "File open: File System Access API not supported in this browser".to_string();
            return;
        }
        self.status = "Opening file…".to_string();
        wasm_file::spawn_open_file();
    }

    /// Open a save-file dialog and write the current module as a VTM text file.
    #[cfg(not(target_arch = "wasm32"))]
    fn save_vtm_dialog(&mut self) {
        let path = rfd::FileDialog::new()
            .add_filter("VTM text (*.vtm)", &["vtm"])
            .set_file_name("module.vtm")
            .save_file();

        let Some(path) = path else {
            return; // user cancelled
        };

        let text = formats::save_vtm(&self.modules[self.active_module]);
        match std::fs::write(&path, text.as_bytes()) {
            Ok(()) => {
                let name = path
                    .file_name()
                    .and_then(|n| n.to_str())
                    .unwrap_or("file");
                self.status = format!("Saved: {}", name);
            }
            Err(e) => {
                self.status = format!("Save failed: {e}");
            }
        }
    }

    /// Open a save-file dialog and write the current module as a PT3 binary file.
    #[cfg(not(target_arch = "wasm32"))]
    fn save_pt3_dialog(&mut self) {
        let path = rfd::FileDialog::new()
            .add_filter("Pro Tracker 3 (*.pt3)", &["pt3"])
            .set_file_name("module.pt3")
            .save_file();

        let Some(path) = path else {
            return; // user cancelled
        };

        match formats::save_pt3(&self.modules[self.active_module]) {
            Ok(bytes) => match std::fs::write(&path, &bytes) {
                Ok(()) => {
                    let name = path
                        .file_name()
                        .and_then(|n| n.to_str())
                        .unwrap_or("file");
                    self.status = format!("Saved: {}", name);
                }
                Err(e) => {
                    self.status = format!("Save failed: {e}");
                }
            },
            Err(e) => {
                self.status = format!("Export failed: {e}");
            }
        }
    }

    #[cfg(target_arch = "wasm32")]
    fn save_vtm_dialog(&mut self) {
        let text = formats::save_vtm(&self.modules[self.active_module]);
        let bytes = text.into_bytes();
        let filename = "module.vtm".to_string();

        if wasm_file::save_picker_supported() {
            self.status = "Saving…".to_string();
            wasm_file::spawn_save_file(filename, bytes);
        } else {
            // Fallback for browsers without the File System Access API
            // (e.g. Firefox).  Download via a temporary object URL with
            // Content-Type: application/octet-stream so the browser does not
            // sniff the VTM text and misidentify it.
            // Unlike spawn_save_file (async), download_blob is synchronous, so
            // we update status directly here rather than via pending_save_status.
            match wasm_file::download_blob(&filename, &bytes) {
                Ok(()) => self.status = format!("Saved: {filename}"),
                Err(e) => {
                    self.status = format!(
                        "Save failed: {}",
                        e.as_string().unwrap_or_else(|| format!("{e:?}"))
                    );
                }
            }
        }
    }

    #[cfg(target_arch = "wasm32")]
    fn save_pt3_dialog(&mut self) {
        let filename = "module.pt3".to_string();
        match formats::save_pt3(&self.modules[self.active_module]) {
            Ok(bytes) => {
                if wasm_file::save_picker_supported() {
                    self.status = "Saving…".to_string();
                    wasm_file::spawn_save_file(filename, bytes);
                } else {
                    match wasm_file::download_blob(&filename, &bytes) {
                        Ok(()) => self.status = format!("Saved: {filename}"),
                        Err(e) => {
                            self.status = format!(
                                "Save failed: {}",
                                e.as_string().unwrap_or_else(|| format!("{e:?}"))
                            );
                        }
                    }
                }
            }
            Err(e) => {
                self.status = format!("Export failed: {e}");
            }
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

    /// Drain any pending WASM file-operation results and apply them to app state.
    ///
    /// Called once per frame (at the top of `update`) on WASM targets.
    /// Results are produced by [`wasm_file::spawn_open_file`] /
    /// [`wasm_file::spawn_save_file`] running asynchronously in the background.
    #[cfg(target_arch = "wasm32")]
    fn poll_wasm_file_ops(&mut self) {
        if let Some(pf) = pending_file::take_pending_open() {
            match formats::load(&pf.bytes, &pf.name) {
                Ok(module) => {
                    self.is_playing = false;
                    self.modules = vec![module];
                    self.active_module = 0;
                    self.reset_playback();
                    self.status = format!("Loaded: {}", pf.name);
                }
                Err(e) => {
                        self.set_error(format!("Parse error: {e}"));
                    }
            }
        }

        if let Some(result) = pending_file::take_pending_save_status() {
            self.status = match result {
                Ok(msg) => msg,
                Err(msg) => msg,
            };
        }
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
        // ── Drain pending WASM file operations ────────────────────────────
        #[cfg(target_arch = "wasm32")]
        self.poll_wasm_file_ops();

        // ── Load error dialog ──────────────────────────────────────────────
        // Mirrors the Delphi `MessageBox(…, MB_ICONEXCLAMATION)` shown when a
        // file fails to open or parse.  The dialog is modal: other UI is still
        // rendered beneath it but the window stays on top until dismissed.
        if self.error_dialog.is_some() {
            let mut open = true;
            let mut ok_clicked = false;
            egui::Window::new("Load Error")
                .collapsible(false)
                .resizable(false)
                .anchor(egui::Align2::CENTER_CENTER, egui::Vec2::ZERO)
                .open(&mut open)
                .show(ctx, |ui| {
                    if let Some(msg) = &self.error_dialog {
                        ui.label(msg.as_str());
                    }
                    ui.add_space(8.0);
                    if ui.button("OK").clicked() {
                        ok_clicked = true;
                    }
                });
            if !open || ok_clicked {
                self.error_dialog = None;
            }
        }

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
                        self.open_file_dialog();
                        ui.close_menu();
                    }
                    if ui.button("Save as VTM…").clicked() {
                        self.save_vtm_dialog();
                        ui.close_menu();
                    }
                    if ui.button("Save as PT3…").clicked() {
                        self.save_pt3_dialog();
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
            let play_pos = if self.is_playing {
                // `current_line` is always one ahead of the row being rendered:
                // `pattern_play_current_line` interprets a row then increments the
                // pointer before returning (mirrors the Pascal `Pattern_PlayCurrentLine`
                // convention, which is why `umredrawtracks` applies `line - 1` when
                // unpacking the position from the posted Windows message).
                let display_line = self.play_vars.current_line.saturating_sub(1);
                Some((self.play_vars.current_pattern, display_line))
            } else {
                None
            };
            self.pattern_editor.show(ui, module, play_pos);
        });
    }
}
