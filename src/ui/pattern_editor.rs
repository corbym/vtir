//! Pattern editor panel.
//!
//! Displays the current pattern as a grid of rows × 3 channels.
//! Keyboard navigation, note entry and effect entry are TODO — see PLAN.md §5.

use eframe::egui;
use vti_core::{Module, NOTE_NONE, NOTE_SOUND_OFF};
use vti_core::util::note_to_str;

/// Cursor position inside the pattern editor.
#[derive(Default, Clone, Copy)]
struct Cursor {
    row: usize,
    channel: usize,
    field: Field,
}

#[derive(Default, Clone, Copy, PartialEq, Eq)]
enum Field {
    #[default]
    Note,
    Sample,
    Ornament,
    Volume,
    Effect,
}

pub struct PatternEditor {
    cursor: Cursor,
    current_pattern: i32,
    octave: u8,
    scroll_to_cursor: bool,
}

impl Default for PatternEditor {
    fn default() -> Self {
        Self {
            cursor: Cursor::default(),
            current_pattern: 0,
            octave: 4,
            scroll_to_cursor: false,
        }
    }
}

impl PatternEditor {
    pub fn show(&mut self, ui: &mut egui::Ui, module: &mut Module) {
        let pat_idx = Module::pat_idx(self.current_pattern);

        // ── Pattern selector ───────────────────────────────────────────────
        ui.horizontal(|ui| {
            ui.label("Pattern:");
            let mut p = self.current_pattern;
            if ui.add(egui::DragValue::new(&mut p).range(0..=vti_core::MAX_PAT_NUM as i32)).changed() {
                self.current_pattern = p;
                self.cursor.row = 0;
            }
            ui.label(format!("Octave: {}", self.octave));
            if ui.small_button("+").clicked() && self.octave < 8 { self.octave += 1; }
            if ui.small_button("-").clicked() && self.octave > 1 { self.octave -= 1; }
        });

        if module.patterns[pat_idx].is_none() {
            if ui.button("Create pattern").clicked() {
                module.patterns[pat_idx] = Some(Box::new(vti_core::Pattern::default()));
            }
            return;
        }

        let pat_len = module.patterns[pat_idx].as_ref().unwrap().length;

        // ── Grid ──────────────────────────────────────────────────────────
        let row_height = 18.0;
        let col_widths = [60.0_f32, 30.0, 24.0, 24.0, 16.0, 60.0]; // Note, Samp, Orn, Vol, Env, Fx

        egui::ScrollArea::vertical()
            .auto_shrink([false, false])
            .show_rows(ui, row_height, pat_len, |ui, row_range| {
                egui::Grid::new("pattern_grid")
                    .num_columns(1 + 6 * 3)
                    .min_col_width(4.0)
                    .striped(true)
                    .show(ui, |ui| {
                        // Header
                        ui.label("Row");
                        for ch_label in ["Ch.A", "Ch.B", "Ch.C"] {
                            ui.label(ch_label);
                            for _ in 1..6 { ui.label(""); }
                        }
                        ui.end_row();

                        for row in row_range {
                            let is_selected = row == self.cursor.row;
                            let row_data = &module.patterns[pat_idx].as_ref().unwrap().items[row];

                            // Row number
                            let row_label = egui::RichText::new(format!("{:03X}", row))
                                .color(if is_selected { egui::Color32::YELLOW } else { egui::Color32::GRAY })
                                .monospace();
                            if ui.label(row_label).clicked() {
                                self.cursor.row = row;
                            }

                            for ch in 0..3 {
                                let cell = &row_data.channel[ch];
                                let note_str = note_to_str(cell.note);
                                let note_color = match cell.note {
                                    n if n == NOTE_SOUND_OFF => egui::Color32::RED,
                                    n if n == NOTE_NONE => egui::Color32::DARK_GRAY,
                                    _ => egui::Color32::WHITE,
                                };
                                if ui.add(
                                    egui::Label::new(
                                        egui::RichText::new(note_str).monospace().color(note_color)
                                    ).sense(egui::Sense::click())
                                ).clicked() {
                                    self.cursor.row = row;
                                    self.cursor.channel = ch;
                                    self.cursor.field = Field::Note;
                                }

                                let sam = if cell.sample == 0 { "--".to_string() } else { format!("{:02X}", cell.sample) };
                                ui.label(egui::RichText::new(sam).monospace().color(egui::Color32::LIGHT_GREEN));

                                let orn = format!("{:X}", cell.ornament);
                                ui.label(egui::RichText::new(orn).monospace().color(egui::Color32::LIGHT_BLUE));

                                let vol = if cell.volume == 0 { ".".to_string() } else { format!("{:X}", cell.volume) };
                                ui.label(egui::RichText::new(vol).monospace().color(egui::Color32::YELLOW));

                                let env = if cell.envelope == 0 { ".".to_string() } else { format!("{:X}", cell.envelope) };
                                ui.label(egui::RichText::new(env).monospace().color(egui::Color32::LIGHT_RED));

                                let cmd = &cell.additional_command;
                                let fx = if cmd.number == 0 {
                                    "......".to_string()
                                } else {
                                    format!("{:X}{:02X}{:02X}", cmd.number, cmd.delay, cmd.parameter)
                                };
                                ui.label(egui::RichText::new(fx).monospace().color(egui::Color32::from_gray(160)));
                            }
                            ui.end_row();
                        }
                    });
            });

        // ── Keyboard input (TODO: full note entry — PLAN.md §5) ──────────
        ui.input(|i| {
            if i.key_pressed(egui::Key::ArrowDown) && self.cursor.row + 1 < pat_len {
                self.cursor.row += 1;
            }
            if i.key_pressed(egui::Key::ArrowUp) && self.cursor.row > 0 {
                self.cursor.row -= 1;
            }
        });
    }
}
