//! Toolbar: transport controls, play mode, channel allocation button.

use eframe::egui;
use crate::app::{PlayMode, PlaybackState};

#[derive(Default)]
pub struct Toolbar;

impl Toolbar {
    pub fn show(
        &mut self,
        ui: &mut egui::Ui,
        playback_state: &mut PlaybackState,
        play_mode: &mut PlayMode,
        status: &mut String,
        active_module: &mut usize,
        module_labels: &[String],
    ) {
        ui.horizontal(|ui| {
            // Transport buttons
            let play_label = if *playback_state == PlaybackState::Playing { "⏸ Pause" } else { "▶ Play" };
            if ui.button(play_label).clicked() {
                match *playback_state {
                    PlaybackState::Playing => {
                        *playback_state = PlaybackState::Paused;
                        *status = "Paused".to_string();
                    }
                    PlaybackState::Paused | PlaybackState::Stopped => {
                        *playback_state = PlaybackState::Playing;
                        *status = "Playing".to_string();
                    }
                }
            }
            if ui.button("⏹ Stop").clicked() {
                *playback_state = PlaybackState::Stopped;
                *status = "Stopped".to_string();
            }

            ui.separator();

            // Play-mode selector
            ui.label("Mode:");
            ui.selectable_value(play_mode, PlayMode::Module,  "Module");
            ui.selectable_value(play_mode, PlayMode::Pattern, "Pattern");
            ui.selectable_value(play_mode, PlayMode::Line,    "Line");

            ui.separator();

            ui.label("Chip:");
            for (idx, label) in module_labels.iter().enumerate() {
                if ui
                    .selectable_label(*active_module == idx, format!("{} {}", idx + 1, label))
                    .clicked()
                {
                    *active_module = idx;
                    if module_labels.len() > 1 {
                        *status = format!("Editing TurboSound chip {}: {}", idx + 1, label);
                    }
                }
            }

            if module_labels.len() == 1 {
                ui.weak("TurboSound off");
            }
        });
    }
}
