//! Toolbar: transport controls, play mode, channel allocation button.

use eframe::egui;
use crate::app::PlayMode;

#[derive(Default)]
pub struct Toolbar;

impl Toolbar {
    pub fn show(
        &mut self,
        ui: &mut egui::Ui,
        is_playing: &mut bool,
        play_mode: &mut PlayMode,
        status: &mut String,
    ) {
        ui.horizontal(|ui| {
            // Transport buttons
            let play_label = if *is_playing { "⏸ Pause" } else { "▶ Play" };
            if ui.button(play_label).clicked() {
                *is_playing = !*is_playing;
                *status = if *is_playing { "Playing".to_string() } else { "Paused".to_string() };
                // TODO: wire up AudioPlayer command channel (PLAN.md §4.1)
            }
            if ui.button("⏹ Stop").clicked() {
                *is_playing = false;
                *status = "Stopped".to_string();
            }

            ui.separator();

            // Play-mode selector
            ui.label("Mode:");
            ui.selectable_value(play_mode, PlayMode::Module,  "Module");
            ui.selectable_value(play_mode, PlayMode::Pattern, "Pattern");
            ui.selectable_value(play_mode, PlayMode::Line,    "Line");
        });
    }
}
