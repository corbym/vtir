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
                    PlaybackState::Paused => {
                        *playback_state = PlaybackState::Playing;
                        *status = "Playing".to_string();
                    }
                    PlaybackState::Stopped => {
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
        });
    }
}
