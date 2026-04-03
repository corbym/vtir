//! Ornament editor panel.
//!
//! Displays and edits one PT3 ornament (arpeggio sequence).
//! Full editing is TODO — PLAN.md §5.

use eframe::egui;
use vti_core::Module;

#[derive(Default)]
pub struct OrnamentEditor {
    pub selected: usize,
}

impl OrnamentEditor {
    pub fn show(&mut self, ui: &mut egui::Ui, module: &mut Module) {
        ui.horizontal(|ui| {
            ui.label("Ornament:");
            ui.add(egui::DragValue::new(&mut self.selected).range(0..=15));
        });

        let Some(Some(ornament)) = module.ornaments.get(self.selected) else {
            if ui.button("Create ornament").clicked() {
                module.ornaments[self.selected] = Some(Box::new(vti_core::Ornament::default()));
            }
            return;
        };

        let len = ornament.length;

        ui.horizontal_wrapped(|ui| {
            for i in 0..len {
                ui.label(
                    egui::RichText::new(format!("{:+03}", ornament.items[i]))
                        .monospace()
                        .color(if ornament.items[i] == 0 {
                            egui::Color32::DARK_GRAY
                        } else {
                            egui::Color32::WHITE
                        }),
                );
            }
        });

        ui.label(format!("Length: {}  Loop: {}", len, ornament.loop_pos));
        ui.label("TODO: editable ornament steps — PLAN.md §5");
    }
}
