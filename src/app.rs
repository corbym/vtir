//! Root application state and eframe `App` implementation.

use eframe::egui;
use vti_core::Module;

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
            status: "Ready".to_string(),
        }
    }

    fn active_module(&self) -> &Module {
        &self.modules[self.active_module]
    }

    fn active_module_mut(&mut self) -> &mut Module {
        &mut self.modules[self.active_module]
    }
}

impl eframe::App for VortexTrackerApp {
    fn update(&mut self, ctx: &egui::Context, _frame: &mut eframe::Frame) {
        // ── Menu bar ───────────────────────────────────────────────────────
        egui::TopBottomPanel::top("menu_bar").show(ctx, |ui| {
            egui::menu::bar(ui, |ui| {
                ui.menu_button("File", |ui| {
                    if ui.button("New").clicked() {
                        self.modules = vec![Module::default()];
                        self.active_module = 0;
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
            self.toolbar.show(ui, &mut self.is_playing, &mut self.play_mode, &mut self.status);
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
