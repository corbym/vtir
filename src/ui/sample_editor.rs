//! Sample editor panel.
//!
//! Displays and edits one PT3 sample (instrument).
//! Full editing (hex drag-values for each tick field) is TODO — PLAN.md §5.

use eframe::egui;
use vti_core::Module;

pub struct SampleEditor {
    pub selected: usize,
}

impl Default for SampleEditor {
    fn default() -> Self {
        Self { selected: 1 }
    }
}

impl SampleEditor {
    pub fn show(&mut self, ui: &mut egui::Ui, module: &mut Module) {
        ui.horizontal(|ui| {
            ui.label("Sample:");
            ui.add(egui::DragValue::new(&mut self.selected).range(1..=31));
        });

        let Some(Some(sample)) = module.samples.get(self.selected) else {
            if ui.button("Create sample").clicked() {
                module.samples[self.selected] = Some(Box::new(vti_core::Sample::default()));
            }
            return;
        };

        let len = sample.length as usize;

        egui::ScrollArea::vertical()
            .auto_shrink([false, false])
            .max_height(160.0)
            .show(ui, |ui| {
                egui::Grid::new("sample_grid")
                    .num_columns(10)
                    .striped(true)
                    .min_col_width(6.0)
                    .show(ui, |ui| {
                        ui.label("#");
                        ui.label("Ton");
                        ui.label("TonAcc");
                        ui.label("Amp");
                        ui.label("AmpSlide");
                        ui.label("AmpUp");
                        ui.label("EnvEn");
                        ui.label("ENAcc");
                        ui.label("AddEn");
                        ui.label("Mixer");
                        ui.end_row();

                        for i in 0..len {
                            let tick = &sample.items[i];
                            ui.label(format!("{:02}", i));
                            ui.label(format!("{:+}", tick.add_to_ton));
                            ui.label(if tick.ton_accumulation { "T" } else { "." });
                            ui.label(format!("{:X}", tick.amplitude));
                            ui.label(if tick.amplitude_sliding { "S" } else { "." });
                            ui.label(if tick.amplitude_slide_up { "U" } else { "." });
                            ui.label(if tick.envelope_enabled { "E" } else { "." });
                            ui.label(if tick.envelope_or_noise_accumulation {
                                "A"
                            } else {
                                "."
                            });
                            ui.label(format!("{:+}", tick.add_to_envelope_or_noise));
                            ui.label(format!(
                                "{}{}",
                                if tick.mixer_ton { "T" } else { "." },
                                if tick.mixer_noise { "N" } else { "." }
                            ));
                            ui.end_row();
                        }
                    });
            });

        ui.label("TODO: editable tick fields — PLAN.md §5");
    }
}
