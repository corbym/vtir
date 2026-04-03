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
}

impl Default for PatternEditor {
    fn default() -> Self {
        Self {
            cursor: Cursor::default(),
            current_pattern: 0,
            octave: 4,
        }
    }
}

impl PatternEditor {
    /// Show the pattern editor.
    ///
    /// `play_pos` — when the engine is playing, pass `Some((pattern_index, current_line))`.
    /// The editor will follow the playhead: switch to the playing pattern, highlight the
    /// current row and keep it centred in the scroll view.
    pub fn show(&mut self, ui: &mut egui::Ui, module: &mut Module, play_pos: Option<(i32, usize)>) {
        // When playback is active, mirror the engine's current pattern.
        if let Some((pat, _)) = play_pos {
            self.current_pattern = pat;
        }

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

        // Compute the playing line within the current pattern (if any).
        let playing_line: Option<usize> = play_pos.and_then(|(pat, line)| {
            if pat == self.current_pattern { Some(line) } else { None }
        });

        // When following the playhead, centre the playing row in the visible
        // area.  We compute the offset *before* building the ScrollArea so
        // that `show_rows` receives the correct visible range on this frame.
        let available_height = ui.available_height();
        let mut scroll_area = egui::ScrollArea::vertical().auto_shrink([false, false]);
        if let Some(line) = playing_line {
            let centred = (line as f32 * row_height) - (available_height / 2.0);
            scroll_area = scroll_area.vertical_scroll_offset(centred.max(0.0));
        }

        scroll_area
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
                            let is_playing  = playing_line == Some(row);
                            let row_data = &module.patterns[pat_idx].as_ref().unwrap().items[row];

                            // Paint a coloured background strip behind the playing row.
                            if is_playing {
                                let row_rect = ui.cursor().expand(2.0);
                                // We will repaint this rect after all cells; for now use a
                                // painter call layered behind the row text.
                                ui.painter().rect_filled(
                                    egui::Rect::from_min_size(
                                        row_rect.min,
                                        egui::vec2(ui.available_width(), row_height),
                                    ),
                                    2.0,
                                    egui::Color32::from_rgba_premultiplied(0, 80, 60, 120),
                                );
                            }

                            // Row number
                            let row_number_color = if is_playing {
                                egui::Color32::from_rgb(0, 255, 180) // bright cyan-green for playing row
                            } else if is_selected {
                                egui::Color32::YELLOW
                            } else {
                                egui::Color32::GRAY
                            };
                            let row_label = egui::RichText::new(format!("{:03X}", row))
                                .color(row_number_color)
                                .monospace();
                            if ui.label(row_label).clicked() {
                                self.cursor.row = row;
                            }

                            for ch in 0..3 {
                                let cell = &row_data.channel[ch];
                                let note_str = note_to_str(cell.note);
                                // When playing, brighten note text on the active row so it
                                // stands out from the background highlight.
                                let note_color = if is_playing {
                                    match cell.note {
                                        n if n == NOTE_SOUND_OFF => egui::Color32::from_rgb(255, 100, 100),
                                        n if n == NOTE_NONE      => egui::Color32::from_gray(120),
                                        _                        => egui::Color32::WHITE,
                                    }
                                } else {
                                    match cell.note {
                                        n if n == NOTE_SOUND_OFF => egui::Color32::RED,
                                        n if n == NOTE_NONE      => egui::Color32::DARK_GRAY,
                                        _                        => egui::Color32::WHITE,
                                    }
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
