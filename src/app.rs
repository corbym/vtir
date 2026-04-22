//! Root application state and eframe `App` implementation.

use eframe::egui;
use vti_core::{Module, Pattern, Sample, SampleTick, Ornament, ChannelLine, AdditionalCommand};
use vti_ay::chip::ChipType;
use vti_ay::config::AyConfig;
use vti_ay::synth::Synthesizer;
use vti_core::playback::{Engine, PlayVars, init_tracker_parameters, PlayResult,
    get_module_time, get_position_time, get_position_time_ex};
use vti_audio::AudioPlayer;
use vti_ay::config::{SAMPLE_RATE_DEF, NUMBER_OF_CHANNELS_DEF};
use vti_core::formats;
use crate::pending_file::OpenTarget;

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
    pub playback_state: PlaybackState,
    pub play_mode: PlayMode,

    // Audio engine
    audio: Option<AudioPlayer>,
    synth: Synthesizer,
    play_vars: Vec<PlayVars>,
    /// Samples to render per 50 Hz interrupt tick.
    samples_per_tick: u32,
    /// `ctx.input(|i| i.time)` at the last engine tick.
    last_tick_time: f64,

    // Status bar text
    pub status: String,

    /// If `Some`, an egui modal error dialog is shown with this message.
    /// Mirrors the Delphi `MessageBox(…, MB_ICONEXCLAMATION)` on load failure.
    pub error_dialog: Option<String>,

    /// Number of output channels: 1 = mono, 2 = stereo (default).
    /// Mirrors `VTOptions.NumberOfChannels` from the original Delphi app.
    pub num_channels: u8,

    /// Per-chip filenames (base name only, no directory), matching `modules`.
    /// `None` for new / unsaved modules.
    pub module_filenames: Vec<Option<String>>,

    /// Currently emulated chip model — applies to all chips in this session.
    /// Mirrors `VTOptions.ChipType` from the Pascal original (`TChipTypes`).
    /// Default: `ChipType::AY`.
    pub chip_type: ChipType,
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

/// Three-state transport model that mirrors the Pascal original.
///
/// - `Stopped` — no playback; next Play starts from position 0.
/// - `Playing` — the engine advances and audio is pushed to the device.
/// - `Paused`  — the engine is frozen at its current position; audio is
///               silenced.  Next Play resumes without resetting position.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Default)]
pub enum PlaybackState {
    #[default]
    Stopped,
    Playing,
    Paused,
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
        Self::new_with_modules(vec![make_demo_module()], vec![None])
    }

    fn new_with_modules(mut modules: Vec<Module>, mut module_filenames: Vec<Option<String>>) -> Self {
        if modules.is_empty() {
            modules.push(make_demo_module());
        }
        if module_filenames.len() != modules.len() {
            module_filenames.resize(modules.len(), None);
        }

        // Audio / synthesis setup
        let cfg = AyConfig::default();
        let samples_per_tick = cfg.sample_tiks_in_interrupt();
        let synth = Synthesizer::new(cfg, modules.len().clamp(1, 2), ChipType::AY);
        let play_vars = modules
            .iter_mut()
            .map(|module| {
                let mut play_vars = PlayVars::default();
                init_tracker_parameters(module, &mut play_vars, true);
                play_vars.delay = module.initial_delay as i8;
                play_vars.current_pattern = if module.positions.length > 0 {
                    module.positions.value[0] as i32
                } else {
                    0
                };
                play_vars
            })
            .collect();

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
            playback_state: PlaybackState::Stopped,
            play_mode: PlayMode::default(),
            audio,
            synth,
            play_vars,
            samples_per_tick,
            last_tick_time: 0.0,
            status: "Ready".to_string(),
            error_dialog: None,
            num_channels: NUMBER_OF_CHANNELS_DEF,
            module_filenames,
            chip_type: ChipType::AY,
        }
    }

    fn turbo_sound_enabled(&self) -> bool {
        self.modules.len() > 1
    }

    fn module_filename(&self, idx: usize) -> Option<&str> {
        self.module_filenames.get(idx).and_then(|n| n.as_deref())
    }

    fn active_filename(&self) -> Option<&str> {
        self.module_filename(self.active_module)
    }

    fn module_slot_label(&self, idx: usize) -> String {
        if let Some(name) = self.module_filename(idx) {
            name.to_string()
        } else {
            let title = self.modules[idx].title.trim();
            if title.is_empty() {
                format!("Chip {}", idx + 1)
            } else {
                title.to_string()
            }
        }
    }

    fn set_active_module_slot(&mut self, idx: usize) {
        if idx >= self.modules.len() || self.active_module == idx {
            return;
        }
        self.active_module = idx;
        if self.turbo_sound_enabled() {
            self.status = format!(
                "Editing TurboSound chip {}: {}",
                idx + 1,
                self.module_slot_label(idx)
            );
        }
    }

    fn install_loaded_module(&mut self, target: OpenTarget, module: Module, filename: String) {
        self.playback_state = PlaybackState::Stopped;
        self.last_tick_time = 0.0;

        match target {
            OpenTarget::Primary => {
                self.modules = vec![module];
                self.module_filenames = vec![Some(filename.clone())];
                self.active_module = 0;
                self.status = format!("Loaded: {}", filename);
            }
            OpenTarget::Secondary => {
                if self.modules.len() == 1 {
                    self.modules.push(module);
                    self.module_filenames.push(Some(filename.clone()));
                } else {
                    self.modules[1] = module;
                    self.module_filenames[1] = Some(filename.clone());
                }
                self.active_module = 1;
                self.status = format!("TurboSound chip 2 loaded: {}", filename);
            }
        }

        self.reset_playback_for_all_modules();
        self.rebuild_synth_for_modules();
    }

    fn install_loaded_modules(&mut self, target: OpenTarget, mut modules: Vec<Module>, filename: String) {
        if modules.is_empty() {
            self.set_error("Parse error: no module data found");
            return;
        }

        if target == OpenTarget::Primary && modules.len() >= 2 {
            let primary = modules.remove(0);
            let secondary = modules.remove(0);

            self.playback_state = PlaybackState::Stopped;
            self.last_tick_time = 0.0;
            self.modules = vec![primary, secondary];
            self.module_filenames = vec![
                Some(format!("{} (chip 1)", filename)),
                Some(format!("{} (chip 2)", filename)),
            ];
            self.active_module = 0;
            self.reset_playback_for_all_modules();
            self.rebuild_synth_for_modules();
            self.status = format!("Loaded TurboSound: {}", filename);
            return;
        }

        self.install_loaded_module(target, modules.remove(0), filename);
    }

    fn disable_secondary_chip(&mut self) {
        if !self.turbo_sound_enabled() {
            return;
        }

        self.playback_state = PlaybackState::Stopped;
        self.last_tick_time = 0.0;
        self.modules.truncate(1);
        self.module_filenames.truncate(1);
        self.active_module = 0;
        self.reset_playback_for_all_modules();
        self.rebuild_synth_for_modules();
        self.status = "TurboSound chip 2 disabled".to_string();
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
        // Must use the same sample rate as AyConfig::default() so the Bresenham
        // upsampler in Synthesizer produces samples at the rate the hardware
        // device expects.  Using 44100 here while the synth runs at 48000 caused
        // all music to play at 44100/48000 ≈ 0.92× speed (about 1.5 semitones flat).
        match AudioPlayer::start(SAMPLE_RATE_DEF) {
            Ok(p)  => { log::info!("audio player started"); Some(p) }
            Err(e) => { log::warn!("audio unavailable: {e}"); None }
        }
    }

    /// Open a file-picker dialog and load the chosen module.
    ///
    /// Supported extensions: `.vtm`, `.pt3`, `.pt2`, `.pt1`, `.stc`, `.stp`,
    /// `.ay` (ZXAY), `.sqt`, `.asc`, `.as0`, `.gtr`, `.fls`.
    /// On WASM this is a no-op (file access is handled separately via the
    /// browser `<input type="file">` element — see STORY-066).
    #[cfg(not(target_arch = "wasm32"))]
    fn open_module_dialog(&mut self, _ctx: &egui::Context, target: OpenTarget) {
        let path = rfd::FileDialog::new()
            .add_filter(
                "Tracker modules",
                &[
                    "vtm", "pt3", "pt2", "pt1", "stc", "stp", "ay",
                    "sqt", "asc", "as0", "gtr", "fls",
                ],
            )
            .add_filter("VTM text (*.vtm)", &["vtm"])
            .add_filter("Pro Tracker 3 (*.pt3)", &["pt3"])
            .add_filter("Pro Tracker 2 (*.pt2)", &["pt2"])
            .add_filter("Pro Tracker 1 (*.pt1)", &["pt1"])
            .add_filter("Sound Tracker Compiled (*.stc)", &["stc"])
            .add_filter("Sound Tracker Pro (*.stp)", &["stp"])
            .add_filter("ZXAY container (*.ay)", &["ay"])
            .add_filter("Square Tracker (*.sqt)", &["sqt"])
            .add_filter("ASC Sound Master v1 (*.asc)", &["asc"])
            .add_filter("ASC Sound Master v0 (*.as0)", &["as0"])
            .add_filter("Global Tracker (*.gtr)", &["gtr"])
            .add_filter("Flying Ledger Sound (*.fls)", &["fls"])
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
                match formats::load_modules(&bytes, filename) {
                    Ok(modules) => {
                        self.install_loaded_modules(target, modules, filename.to_string());
                    }
                    Err(e) => {
                        self.set_error(format!("Parse error: {e}"));
                    }
                }
            }
        }
    }

    #[cfg(target_arch = "wasm32")]
    fn open_module_dialog(&mut self, ctx: &egui::Context, target: OpenTarget) {
        if !wasm_file::open_picker_supported() {
            self.status =
                "File open: File System Access API not supported in this browser".to_string();
            return;
        }
        self.status = match target {
            OpenTarget::Primary => "Opening file…".to_string(),
            OpenTarget::Secondary => "Opening TurboSound chip 2…".to_string(),
        };
        wasm_file::spawn_open_file(ctx.clone(), target);
    }

    /// Return the stem (name without extension) of the active slot filename, or
    /// `"module"` as a fallback for new/unnamed modules.
    fn filename_stem(&self) -> String {
        self.active_filename()
            .as_deref()
            .and_then(|n| {
                let p = std::path::Path::new(n);
                p.file_stem().and_then(|s| s.to_str())
            })
            .unwrap_or("module")
            .to_string()
    }

    /// Open a save-file dialog and write the current module as a VTM text file.
    #[cfg(not(target_arch = "wasm32"))]
    fn save_vtm_dialog(&mut self, _ctx: &egui::Context) {
        let default_name = format!("{}.vtm", self.filename_stem());
        let path = rfd::FileDialog::new()
            .add_filter("VTM text (*.vtm)", &["vtm"])
            .set_file_name(&default_name)
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
    fn save_pt3_dialog(&mut self, _ctx: &egui::Context) {
        let default_name = format!("{}.pt3", self.filename_stem());
        let path = rfd::FileDialog::new()
            .add_filter("Pro Tracker 3 (*.pt3)", &["pt3"])
            .set_file_name(&default_name)
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

    /// Open a save-file dialog and export the current module with the ZX
    /// Spectrum player.  The output format is chosen by file extension:
    /// `.$c` → Hobeta code, `.$m` → Hobeta mem, `.ay` → AY file,
    /// `.scl` → Sinclair image, `.tap` → tape.  Defaults to `.tap`.
    ///
    /// This mirrors `SaveforZXMenuClick` in `legacy/main.pas`, placed under
    /// the same `Exports` submenu as the original Pascal UI.
    #[cfg(not(target_arch = "wasm32"))]
    fn save_zx_dialog(&mut self, _ctx: &egui::Context) {
        use formats::zx_export::{ZxExportOptions, ZxFormat};

        let stem = self.filename_stem();
        let module = &self.modules[self.active_module];
        let opts_base = ZxExportOptions {
            load_addr: 0xC000,
            format: ZxFormat::Tap,
            looping: false,
            name: stem.clone(),
            title: module.title.clone(),
            author: module.author.clone(),
        };

        let default_name = format!("{stem}.tap");
        let path = rfd::FileDialog::new()
            .add_filter("ZX Spectrum tape (*.tap)", &["tap"])
            .add_filter("AY emulator file (*.ay)", &["ay"])
            .add_filter("Sinclair disc image (*.scl)", &["scl"])
            .add_filter("Hobeta code block (*.$c)", &["$c"])
            .add_filter("Hobeta memory block (*.$m)", &["$m"])
            .set_file_name(&default_name)
            .save_file();

        let Some(path) = path else {
            return; // user cancelled
        };

        // Choose format from the saved extension.
        let ext = path
            .extension()
            .and_then(|e| e.to_str())
            .unwrap_or("")
            .to_lowercase();
        let format = match ext.as_str() {
            "ay"                                 => ZxFormat::AyFile,
            "scl"                                => ZxFormat::Scl,
            "$c" | "c"                           => ZxFormat::HobetaCode,
            "$m" | "m"                           => ZxFormat::HobetaMem,
            _                                    => ZxFormat::Tap,
        };
        let opts = ZxExportOptions { format, ..opts_base };

        match formats::save_zx(module, &opts) {
            Ok(bytes) => match std::fs::write(&path, &bytes) {
                Ok(()) => {
                    let name = path
                        .file_name()
                        .and_then(|n| n.to_str())
                        .unwrap_or("file");
                    self.status = format!("Exported: {}", name);
                }
                Err(e) => self.status = format!("Export failed: {e}"),
            },
            Err(e) => self.status = format!("Export failed: {e}"),
        }
    }

    #[cfg(target_arch = "wasm32")]
    fn save_vtm_dialog(&mut self, ctx: &egui::Context) {
        let text = formats::save_vtm(&self.modules[self.active_module]);
        let bytes = text.into_bytes();
        let filename = format!("{}.vtm", self.filename_stem());

        if wasm_file::save_picker_supported() {
            self.status = "Saving…".to_string();
            wasm_file::spawn_save_file(ctx.clone(), filename, bytes);
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
    fn save_pt3_dialog(&mut self, ctx: &egui::Context) {
        let filename = format!("{}.pt3", self.filename_stem());
        match formats::save_pt3(&self.modules[self.active_module]) {
            Ok(bytes) => {
                if wasm_file::save_picker_supported() {
                    self.status = "Saving…".to_string();
                    wasm_file::spawn_save_file(ctx.clone(), filename, bytes);
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

    /// WASM: export current module with ZX Spectrum player (downloads `.tap`).
    #[cfg(target_arch = "wasm32")]
    fn save_zx_dialog(&mut self, ctx: &egui::Context) {
        use formats::zx_export::{ZxExportOptions, ZxFormat};
        let stem = self.filename_stem();
        let module = &self.modules[self.active_module];
        let opts = ZxExportOptions {
            load_addr: 0xC000,
            format: ZxFormat::Tap,
            looping: false,
            name: stem.clone(),
            title: module.title.clone(),
            author: module.author.clone(),
        };
        let filename = format!("{stem}.tap");
        match formats::save_zx(module, &opts) {
            Ok(bytes) => {
                if wasm_file::save_picker_supported() {
                    self.status = "Exporting…".to_string();
                    wasm_file::spawn_save_file(ctx.clone(), filename, bytes);
                } else {
                    match wasm_file::download_blob(&filename, &bytes) {
                        Ok(()) => self.status = format!("Exported: {filename}"),
                        Err(e) => self.status = format!(
                            "Export failed: {}",
                            e.as_string().unwrap_or_else(|| format!("{e:?}"))
                        ),
                    }
                }
            }
            Err(e) => self.status = format!("Export failed: {e}"),
        }
    }

    fn rebuild_synth_for_modules(&mut self) {
        let chips = self.modules.len().clamp(1, 2);
        let cfg = AyConfig { num_channels: self.num_channels, ..AyConfig::default() };
        self.synth = Synthesizer::new(cfg, chips, self.chip_type);
    }

    /// Change the emulated chip model and rebuild the level tables.
    ///
    /// Mirrors `TMainForm.SetEmulatingChip(aChipType)` from `main.pas`:
    /// updates `VTOptions.ChipType` and calls
    /// `PlaybackBufferMaker.Calculate_Level_Tables` so the change is immediately
    /// audible without restarting playback.
    pub fn set_emulating_chip(&mut self, chip_type: ChipType) {
        self.chip_type = chip_type;
        self.synth.set_chip_type(chip_type);
    }

    fn reset_playback_for_all_modules(&mut self) {
        self.play_vars = vec![PlayVars::default(); self.modules.len()];
        for i in 0..self.modules.len() {
            init_tracker_parameters(&mut self.modules[i], &mut self.play_vars[i], true);
            self.play_vars[i].delay = self.modules[i].initial_delay as i8;
            self.play_vars[i].current_position = 0;
            self.play_vars[i].current_pattern = if self.modules[i].positions.length > 0 {
                self.modules[i].positions.value[0] as i32
            } else {
                0
            };
        }
        self.active_module = self.active_module.min(self.modules.len().saturating_sub(1));
    }


    /// Drain any pending WASM file-operation results and apply them to app state.
    ///
    /// Called once per frame (at the top of `update`) on WASM targets.
    /// Results are produced by [`wasm_file::spawn_open_file`] /
    /// [`wasm_file::spawn_save_file`] running asynchronously in the background.
    #[cfg(target_arch = "wasm32")]
    fn poll_wasm_file_ops(&mut self) {
        if let Some(pf) = pending_file::take_pending_open() {
            match formats::load_modules(&pf.bytes, &pf.name) {
                Ok(modules) => {
                    self.install_loaded_modules(pf.target, modules, pf.name);
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
        let chip_count = self.modules.len().min(2);
        for chip_idx in 0..chip_count {
            let mut ay_regs = vti_core::AyRegisters::default();
            let result = {
                let module = &mut self.modules[chip_idx];
                let vars = &mut self.play_vars[chip_idx];
                let mut engine = Engine { module, vars };
                let mode = if chip_idx == self.active_module {
                    self.play_mode
                } else {
                    PlayMode::Module
                };
                match mode {
                    PlayMode::Module => engine.module_play_current_line(&mut ay_regs),
                    PlayMode::Pattern => engine.pattern_play_current_line(&mut ay_regs),
                    PlayMode::Line => {
                        engine.pattern_play_only_current_line(&mut ay_regs);
                        PlayResult::Updated
                    }
                }
            };

            if chip_idx == self.active_module
                && result == PlayResult::ModuleLoop
                && self.play_mode == PlayMode::Module
            {
                // Module looped — keep playing (normal loop behaviour)
            }

            self.synth.apply_registers(chip_idx, &ay_regs);
        }

        for chip_idx in chip_count..2 {
            self.synth
                .apply_registers(chip_idx, &vti_core::AyRegisters::default());
        }

        // Quality mode: run chip at correct AY clock rate with Bresenham upsampler.
        // Performance mode (future): render_frame(samples_per_tick).
        self.synth.render_frame_quality();
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

        // ── Window title: show filename or module title ────────────────────
        {
            let slot_prefix = if self.turbo_sound_enabled() {
                format!("Chip {} — ", self.active_module + 1)
            } else {
                String::new()
            };
            let title = match self.active_filename() {
                Some(name) => format!("Vortex Tracker II — {slot_prefix}{name}"),
                None => {
                    let t = &self.modules[self.active_module].title;
                    if t.is_empty() {
                        "Vortex Tracker II".to_string()
                    } else {
                        format!("Vortex Tracker II — {slot_prefix}{t}")
                    }
                }
            };
            ctx.send_viewport_cmd(egui::ViewportCommand::Title(title));
        }

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
        if self.playback_state == PlaybackState::Playing {
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
                        self.module_filenames = vec![None];
                        self.active_module = 0;
                        self.playback_state = PlaybackState::Stopped;
                        self.last_tick_time = 0.0;
                        self.reset_playback_for_all_modules();
                        self.rebuild_synth_for_modules();
                        self.status = "New module created".to_string();
                        ui.close_menu();
                    }
                    if ui.button("Open…").clicked() {
                        self.open_module_dialog(ctx, OpenTarget::Primary);
                        ui.close_menu();
                    }
                    if ui.button("Save as VTM…").clicked() {
                        self.save_vtm_dialog(ctx);
                        ui.close_menu();
                    }
                    if ui.button("Save as PT3…").clicked() {
                        self.save_pt3_dialog(ctx);
                        ui.close_menu();
                    }
                    // ── Exports submenu (matches legacy "Exports1" TMenuItem) ──
                    ui.menu_button("Exports", |ui| {
                        if ui.button("Save with ZX Spectrum player…").clicked() {
                            self.save_zx_dialog(ctx);
                            ui.close_menu();
                        }
                    });
                    ui.separator();
                    if ui.button("Quit").clicked() {
                        ctx.send_viewport_cmd(egui::ViewportCommand::Close);
                    }
                });
                ui.menu_button("Turbo Sound", |ui| {
                    if ui.button("Load 2nd sound chip module…").clicked() {
                        self.open_module_dialog(ctx, OpenTarget::Secondary);
                        ui.close_menu();
                    }

                    let disable_button = ui.add_enabled(
                        self.turbo_sound_enabled(),
                        egui::Button::new("Disable 2nd sound chip"),
                    );
                    if disable_button.clicked() {
                        self.disable_secondary_chip();
                        ui.close_menu();
                    }

                    ui.separator();

                    if ui
                        .selectable_label(self.active_module == 0, format!("Edit chip 1 ({})", self.module_slot_label(0)))
                        .clicked()
                    {
                        self.set_active_module_slot(0);
                        ui.close_menu();
                    }

                    let chip2_text = if self.turbo_sound_enabled() {
                        format!("Edit chip 2 ({})", self.module_slot_label(1))
                    } else {
                        "Edit chip 2 (disabled)".to_string()
                    };
                    let chip2_button = ui.add_enabled(
                        self.turbo_sound_enabled(),
                        egui::SelectableLabel::new(self.active_module == 1, chip2_text),
                    );
                    if chip2_button.clicked() {
                        self.set_active_module_slot(1);
                        ui.close_menu();
                    }
                });
                ui.menu_button("Options", |ui| {
                    let mut mono = self.num_channels == 1;
                    let was_mono = mono;
                    ui.radio_value(&mut mono, false, "Stereo");
                    ui.radio_value(&mut mono, true,  "Mono");
                    if mono != was_mono {
                        self.num_channels = if mono { 1 } else { 2 };
                        self.playback_state = PlaybackState::Stopped;
                        self.last_tick_time = 0.0;
                        self.rebuild_synth_for_modules();
                        self.status = if mono {
                            "Mono output".to_string()
                        } else {
                            "Stereo output".to_string()
                        };
                        ui.close_menu();
                    }

                    ui.separator();

                    // Chip type selection — mirrors TOptionsDlg.ChipSelClick in options.pas.
                    // ItemIndex 0 → AY_Chip, ItemIndex 1 → YM_Chip.
                    ui.label("Chip type:");
                    let current = self.chip_type;
                    if ui.radio_value(&mut self.chip_type, ChipType::AY, "AY-3-8910").changed()
                        && current != ChipType::AY
                    {
                        self.set_emulating_chip(ChipType::AY);
                        self.status = "Chip: AY-3-8910".to_string();
                        ui.close_menu();
                    }
                    if ui.radio_value(&mut self.chip_type, ChipType::YM, "YM2149F").changed()
                        && current != ChipType::YM
                    {
                        self.set_emulating_chip(ChipType::YM);
                        self.status = "Chip: YM2149F".to_string();
                        ui.close_menu();
                    }
                });
                ui.menu_button("Help", |ui| {
                    if ui.button("About").clicked() {
                        // TODO: about dialog (STORY-051)
                        self.status = "Vortex Tracker II — Rust port. Original by Sergey Bulba.".to_string();
                        ui.close_menu();
                    }
                });
            });
        });

        // ── Toolbar ────────────────────────────────────────────────────────
        egui::TopBottomPanel::top("toolbar").show(ctx, |ui| {
            let prev_state = self.playback_state;
            let prev_chip_type = self.chip_type;
            let chip_labels: Vec<String> = (0..self.modules.len())
                .map(|idx| self.module_slot_label(idx))
                .collect();
            self.toolbar.show(
                ui,
                &mut self.playback_state,
                &mut self.play_mode,
                &mut self.status,
                &mut self.active_module,
                &chip_labels,
                &mut self.chip_type,
            );

            // If the toolbar toggle changed the chip type, apply it via set_emulating_chip.
            // Mirrors ToggleChipExecute → SetEmulatingChip in main.pas.
            if self.chip_type != prev_chip_type {
                let new_chip = self.chip_type;
                self.synth.set_chip_type(new_chip);
                self.status = match new_chip {
                    ChipType::AY   => "Chip: AY-3-8910".to_string(),
                    ChipType::YM   => "Chip: YM2149F".to_string(),
                    ChipType::None => unreachable!("chip_type must never be None in the UI"),
                };
            }

            match (prev_state, self.playback_state) {
                // Stopped → Playing: reset position and start audio from the beginning.
                (PlaybackState::Stopped, PlaybackState::Playing) => {
                    self.reset_playback_for_all_modules();
                    self.last_tick_time = 0.0;
                    // Open the audio device on first Play press (satisfies the browser
                    // autoplay policy on WASM; harmless no-op on subsequent presses).
                    if self.audio.is_none() {
                        self.audio = Self::try_open_audio();
                    }
                    let audio_status = if self.audio.is_some() { "Playing" } else { "Playing (no audio device)" };
                    self.status = audio_status.to_string();
                }
                // Paused → Playing: resume from the current position (no reset).
                (PlaybackState::Paused, PlaybackState::Playing) => {
                    // Reset the tick timer so we don't try to catch up on the gap
                    // that elapsed while paused, which would cause a burst of ticks.
                    self.last_tick_time = 0.0;
                    if self.audio.is_none() {
                        self.audio = Self::try_open_audio();
                    }
                    let audio_status = if self.audio.is_some() { "Playing" } else { "Playing (no audio device)" };
                    self.status = audio_status.to_string();
                }
                // Playing → Paused: freeze at current position; silence the AY chip
                // so no stale tone leaks through the audio buffer while paused.
                (PlaybackState::Playing, PlaybackState::Paused) => {
                    let silence = vti_core::AyRegisters::default();
                    for chip_idx in 0..self.modules.len().min(2) {
                        self.synth.apply_registers(chip_idx, &silence);
                    }
                }
                // Any → Stopped: reset position so next Play starts from the beginning.
                (_, PlaybackState::Stopped) => {
                    self.reset_playback_for_all_modules();
                    self.last_tick_time = 0.0;
                }
                // All other transitions are no-ops (e.g. Stopped→Stopped).
                _ => {}
            }

            self.active_module = self.active_module.min(self.modules.len().saturating_sub(1));
        });

        // ── Status bar ─────────────────────────────────────────────────────
        egui::TopBottomPanel::bottom("status_bar").show(ctx, |ui| {
            ui.horizontal(|ui| {
                // Chip type label — mirrors ToggleChip.Caption in main.pas.
                let chip_label = match self.chip_type {
                    ChipType::AY   => "AY",
                    ChipType::YM   => "YM",
                    ChipType::None => unreachable!("chip_type must never be None in the UI"),
                };
                ui.label(chip_label);
                ui.separator();

                // When playing or paused, show position and timing in the status bar.
                if self.playback_state != PlaybackState::Stopped {
                    let module = &self.modules[self.active_module];
                    let total_ticks = get_module_time(module);
                    let vars = &self.play_vars[self.active_module];
                    let pos = vars.current_position;
                    let line = vars.current_line.saturating_sub(1);
                    let (pos_ticks, pos_delay) = get_position_time(module, pos);
                    let row_ticks = get_position_time_ex(module, pos, pos_delay, line);
                    let elapsed = pos_ticks + row_ticks;
                    let fmt_ticks = |t: u32| -> String {
                        let secs = t / 50;
                        format!("{:02}:{:02}", secs / 60, secs % 60)
                    };
                    ui.label(format!(
                        "chip {}/{}  pos {}/{}  {}  {} / {}",
                        self.active_module + 1,
                        self.modules.len(),
                        pos,
                        module.positions.length.saturating_sub(1),
                        &self.status,
                        fmt_ticks(elapsed),
                        fmt_ticks(total_ticks),
                    ));
                } else {
                    if self.turbo_sound_enabled() {
                        ui.label(format!(
                            "chip {}/{}  {}",
                            self.active_module + 1,
                            self.modules.len(),
                            &self.status
                        ));
                    } else {
                        ui.label(&self.status);
                    }
                }
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
            let play_pos = if self.playback_state != PlaybackState::Stopped {
                let vars = &self.play_vars[self.active_module];
                let display_line = vars.current_line.saturating_sub(1);
                Some((vars.current_pattern, display_line))
            } else {
                None
            };
            self.pattern_editor.show(ui, module, play_pos);
        });
    }

    /// Remove transient focus-transfer events before egui processes them.
    ///
    /// See [`collapse_focus_ping_pong`] for the full explanation.
    #[cfg(target_arch = "wasm32")]
    fn raw_input_hook(&mut self, _ctx: &egui::Context, raw_input: &mut egui::RawInput) {
        collapse_focus_ping_pong(&mut raw_input.events);
    }
}

/// Collapse spurious adjacent `WindowFocused(false)` / `WindowFocused(true)` pairs.
///
/// # Why this is needed
///
/// On WASM, when our `touchend` handler calls `input.focus()` on eframe's
/// hidden text-agent `<input>`, the browser fires `canvas.blur()` **synchronously**
/// before the focus reaches the text-agent — at that exact moment neither
/// element has browser focus.  eframe's canvas-blur handler queues
/// `WindowFocused(false)` into the raw input.  The very next
/// `requestAnimationFrame` call restores focus and queues `WindowFocused(true)`.
/// Both events end up in the same egui frame.
///
/// When egui processes `WindowFocused(false)` it clears `Memory::focused_id`,
/// causing any focused `TextEdit` to lose egui focus → `ime = None` → eframe
/// calls `text_agent.blur()` + `canvas.focus()` → the mobile virtual keyboard
/// is dismissed within one frame of appearing.
///
/// An immediately adjacent `false/true` pair represents a *transient* canvas →
/// text-agent focus transfer, not a genuine app-focus loss.  Removing the pair
/// prevents egui from clearing `focused_id` and keeps the keyboard visible.
///
/// This function is extracted (without `#[cfg(target_arch = "wasm32")]`) so it
/// can be unit-tested on native targets.
pub(crate) fn collapse_focus_ping_pong(events: &mut Vec<egui::Event>) {
    let mut i = 0;
    while i + 1 < events.len() {
        let is_pair = matches!(
            (&events[i], &events[i + 1]),
            (egui::Event::WindowFocused(false), egui::Event::WindowFocused(true))
        );
        if is_pair {
            events.remove(i + 1);
            events.remove(i);
        } else {
            i += 1;
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn module_with_title(title: &str) -> Module {
        let mut module = Module::default();
        module.title = title.to_string();
        module.positions.length = 1;
        module.positions.value[0] = 0;
        module
    }

    fn app_for_test() -> VortexTrackerApp {
        VortexTrackerApp::new_with_modules(
            vec![module_with_title("Chip One")],
            vec![Some("chip1.pt3".to_string())],
        )
    }

    // ── collapse_focus_ping_pong unit tests ──────────────────────────────────
    // These tests exercise the Rust logic that prevents the mobile virtual
    // keyboard from immediately disappearing after a tap.  The matching
    // browser-side behaviour (canvas.focus() no-op, touchend handler) is in
    // index.html and cannot be unit-tested in Rust; its correctness must be
    // verified manually on a real device / browser DevTools emulation.

    fn focused(v: bool) -> egui::Event {
        egui::Event::WindowFocused(v)
    }

    #[test]
    fn collapse_removes_single_false_true_pair() {
        let mut events = vec![focused(false), focused(true)];
        collapse_focus_ping_pong(&mut events);
        assert!(events.is_empty(), "pair should be removed");
    }

    #[test]
    fn collapse_removes_multiple_adjacent_pairs() {
        let mut events = vec![
            focused(false), focused(true),
            focused(false), focused(true),
        ];
        collapse_focus_ping_pong(&mut events);
        assert!(events.is_empty(), "both pairs should be removed");
    }

    #[test]
    fn collapse_does_not_remove_standalone_false() {
        let mut events = vec![focused(false)];
        collapse_focus_ping_pong(&mut events);
        assert_eq!(events.len(), 1, "single false should be kept");
        assert!(matches!(events[0], egui::Event::WindowFocused(false)));
    }

    #[test]
    fn collapse_does_not_remove_standalone_true() {
        let mut events = vec![focused(true)];
        collapse_focus_ping_pong(&mut events);
        assert_eq!(events.len(), 1);
    }

    #[test]
    fn collapse_does_not_remove_true_false_pair() {
        // true/false = normal focus-out sequence; must NOT be collapsed
        let mut events = vec![focused(true), focused(false)];
        collapse_focus_ping_pong(&mut events);
        assert_eq!(events.len(), 2, "true/false pair must be preserved");
    }

    #[test]
    fn collapse_preserves_surrounding_events() {
        let mut events = vec![
            egui::Event::PointerGone,
            focused(false),
            focused(true),
            egui::Event::PointerGone,
        ];
        collapse_focus_ping_pong(&mut events);
        assert_eq!(events.len(), 2, "only the false/true pair should be removed");
        assert!(matches!(events[0], egui::Event::PointerGone));
        assert!(matches!(events[1], egui::Event::PointerGone));
    }

    #[test]
    fn collapse_mixed_genuine_loss_and_ping_pong() {
        // A genuine WindowFocused(false) at the end (no matching true) must survive.
        let mut events = vec![
            focused(false), // ping-pong start
            focused(true),  // ping-pong end  → pair removed
            focused(false), // genuine app blur → kept
        ];
        collapse_focus_ping_pong(&mut events);
        assert_eq!(events.len(), 1, "only the genuine false should remain");
        assert!(matches!(events[0], egui::Event::WindowFocused(false)));
    }

    #[test]
    fn installing_secondary_module_preserves_primary_and_selects_chip_two() {
        let mut app = app_for_test();

        app.install_loaded_module(
            OpenTarget::Secondary,
            module_with_title("Chip Two"),
            "chip2.pt3".to_string(),
        );

        assert_eq!(app.modules.len(), 2);
        assert_eq!(app.module_filename(0), Some("chip1.pt3"));
        assert_eq!(app.module_filename(1), Some("chip2.pt3"));
        assert_eq!(app.active_module, 1, "newly loaded second chip should become active");
        assert!(app.turbo_sound_enabled());
    }

    #[test]
    fn disabling_secondary_chip_returns_to_single_chip_mode() {
        let mut app = app_for_test();
        app.install_loaded_module(
            OpenTarget::Secondary,
            module_with_title("Chip Two"),
            "chip2.pt3".to_string(),
        );

        app.disable_secondary_chip();

        assert_eq!(app.modules.len(), 1);
        assert_eq!(app.module_filenames.len(), 1);
        assert_eq!(app.active_module, 0);
        assert!(!app.turbo_sound_enabled());
        assert_eq!(app.module_filename(0), Some("chip1.pt3"));
    }

    #[test]
    fn filename_stem_tracks_active_chip_filename() {
        let mut app = app_for_test();
        app.install_loaded_module(
            OpenTarget::Secondary,
            module_with_title("Chip Two"),
            "chip2.pt3".to_string(),
        );

        assert_eq!(app.filename_stem(), "chip2");
        app.set_active_module_slot(0);
        assert_eq!(app.filename_stem(), "chip1");
    }
}
