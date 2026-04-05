//! Pattern editor panel.
//!
//! Displays the current pattern as a grid of rows × 3 channels and handles
//! all tracker keyboard input:
//!
//! - **Piano key note entry** — two-row layout mirroring the default VT2
//!   mapping from `legacy/keys.pas::NoteKeysSetDefault`.
//! - **Hex digit entry** — shift-insert on Sample/Ornament/Volume/Envelope/
//!   Effect fields (0–9 / A–F).
//! - **Note-off** — `A` key or `1` key writes `NOTE_SOUND_OFF`.
//! - **Clear cell / field** — `K`, Backspace, or Delete.
//! - **Auto-advance cursor** — moves down by the configurable step size
//!   after each entry (default 1; set to 0 to disable).
//! - **Field navigation** — ←/→ cycle through fields and channels; Tab /
//!   Shift+Tab jump to the next/previous channel's Note column.
//! - **Shift+note key** — plays the note one octave higher (Pascal convention).
//! - **Pattern length editor** — `Len:` DragValue (1–256) in the header row.
//! - **Insert row** — `Ctrl+I` or `Insert`: shifts rows below the cursor down
//!   by one (last row is discarded), clears the cursor row.  Mirrors Pascal
//!   `SCA_PatternInsertLine` / `DoInsertLine`.
//! - **Delete row** — `Ctrl+Backspace` or `Ctrl+Y`: shifts rows above the end
//!   up by one (last row is cleared), removing the cursor row.  Mirrors Pascal
//!   `SCA_PatternDeleteLine` / `DoRemoveLine`.
//! - **Clear row** — `Ctrl+Delete`: resets every channel cell on the cursor
//!   row to its default state.  Mirrors Pascal `SCA_PatternClearLine`.
//!
//! ## WASM / mobile keyboard
//!
//! eframe proxies all browser keyboard input through a hidden
//! `<input type="text">` called the *text agent*.  It calls `input.focus()`
//! on the text agent only when egui outputs a non-`None` `ime` field, which
//! only happens when a [`egui::TextEdit`] widget has egui focus.  The
//! `focus()` call is made from `requestAnimationFrame`, which iOS Safari does
//! **not** treat as a user-gesture context, so the virtual keyboard would
//! never appear.
//!
//! **Two-layer fix:**
//!
//! 1. **`index.html` JavaScript** — on every canvas `touchend` the script
//!    synchronously calls `input.focus()` on the text agent (user-gesture
//!    context, satisfies iOS Safari).  A `blur` listener refocuses the input
//!    for ≈500 ms after a touch so eframe's own `ime`-based management cannot
//!    immediately undo it.  This fix is **app-wide**: it works for every tap
//!    on the canvas, not just pattern-cell taps.
//!
//! 2. **Keyboard anchor** — a small [`egui::TextEdit`] widget (id
//!    `pat_kbd_anchor`) is rendered at the right end of the header row on
//!    WASM targets.  At the end of every `show()` frame, `request_focus` is
//!    called for this widget unconditionally.  This keeps `ime = Some(…)` in
//!    egui's platform output, which causes eframe to call
//!    `text_agent.focus()` every frame, maintaining focus after the
//!    JavaScript's 500 ms window closes.
//!
//! Key events arrive via `ui.input(|i| …)` — both `Event::Key` (hardware /
//! desktop keyboards and most mobile browsers) and `Event::Text` (fallback
//! for browsers that fire `key = "Unidentified"` in `keydown`).
//!
//! An on-screen piano keyboard widget (PLAN.md §5.5) is not yet implemented.

use eframe::egui;
use vti_core::editor::{compute_note, hex_digit_entry, piano_key_to_semitone_offset};
use vti_core::util::note_to_str;
use vti_core::{ChannelLine, Module, NOTE_NONE, NOTE_SOUND_OFF};

/// Number of channels per pattern row.
const NUM_CH: usize = 3;
/// Maximum index for the Sample field (0x1F = 31 samples numbered 1..=31).
const MAX_SAMPLE: u8 = 31;
/// Maximum value for single-nibble fields (Ornament, Volume, Envelope, Effect number).
const MAX_NIBBLE: u8 = 15;

/// Columns within a single channel cell, left to right.
#[derive(Clone, Copy, PartialEq, Eq, Debug, Default)]
enum Field {
    #[default]
    Note,
    Sample,
    Ornament,
    Volume,
    Envelope,
    Effect,
}

impl Field {
    const COUNT: usize = 6;

    fn index(self) -> usize {
        match self {
            Field::Note => 0,
            Field::Sample => 1,
            Field::Ornament => 2,
            Field::Volume => 3,
            Field::Envelope => 4,
            Field::Effect => 5,
        }
    }

    fn from_index(i: usize) -> Self {
        match i % Self::COUNT {
            0 => Field::Note,
            1 => Field::Sample,
            2 => Field::Ornament,
            3 => Field::Volume,
            4 => Field::Envelope,
            _ => Field::Effect,
        }
    }
}

/// Cursor position within the pattern grid.
#[derive(Clone, Copy, Default)]
struct Cursor {
    row: usize,
    channel: usize,
    field: Field,
}

pub struct PatternEditor {
    cursor: Cursor,
    current_pattern: i32,
    /// Current entry octave (1–8).
    octave: u8,
    /// Auto-advance row count after each entry.  0 = disabled.  Negative =
    /// move upward (unusual but supported, matching Pascal `UDAutoStep`).
    /// Range −64..=64.
    step_size: i32,
    /// Set to `true` after cursor-row changes caused by key entry so that
    /// the scroll area re-centres on the new cursor row.
    scroll_to_cursor: bool,
    /// Dummy buffer for the mobile keyboard-anchor `TextEdit`.
    ///
    /// On WASM this widget is rendered at the right end of the header scroll
    /// row.  Focusing it causes eframe to keep the browser text-agent input
    /// focused, which in turn keeps the mobile virtual keyboard visible.
    /// `show()` requests focus for this widget at the end of every frame
    /// (after all other widgets) so `PlatformOutput::ime` is always `Some`,
    /// preventing eframe from blurring the text-agent.
    /// The content is cleared each frame; we never read it directly.
    #[cfg(target_arch = "wasm32")]
    keyboard_anchor: String,
    /// Whether the hidden mobile keyboard-anchor should currently hold focus.
    ///
    /// This is enabled only after taps on editable pattern cells and disabled
    /// on other pointer presses so dismissing the OS keyboard and tapping
    /// elsewhere does not immediately reopen it.
    #[cfg(target_arch = "wasm32")]
    keyboard_anchor_active: bool,
}

impl Default for PatternEditor {
    fn default() -> Self {
        Self {
            cursor: Cursor::default(),
            current_pattern: 0,
            octave: 4,
            step_size: 1,
            scroll_to_cursor: false,
            #[cfg(target_arch = "wasm32")]
            keyboard_anchor: String::new(),
            #[cfg(target_arch = "wasm32")]
            keyboard_anchor_active: false,
        }
    }
}

impl PatternEditor {
    /// Stable egui ID for the keyboard-anchor `TextEdit` widget.
    fn kbd_anchor_id() -> egui::Id {
        egui::Id::new("pat_kbd_anchor")
    }

    /// Directly focus the egui text-agent `<input>` element via the DOM.
    ///
    /// eframe creates a single hidden `<input type="text">` (the text agent)
    /// that acts as the IME / virtual-keyboard proxy.  Calling `focus()` on
    /// it synchronously—or as close to synchronously as possible inside a
    /// `requestAnimationFrame` callback—is what triggers the mobile virtual
    /// keyboard on Chrome for Android and most other browsers.
    ///
    /// iOS Safari additionally requires that `focus()` is called inside a
    /// *direct* user-gesture handler (not rAF).  That case is covered by the
    /// JavaScript snippet in `index.html` which calls `input.focus()` on the
    /// canvas `touchend` event.  This Rust function serves as a belt-and-
    /// suspenders complement for browsers that are more permissive.
    ///
    /// The selector `"input[type=text]"` mirrors the one in `index.html`;
    /// both must be updated if eframe changes how it creates the text agent.
    #[cfg(target_arch = "wasm32")]
    fn focus_text_agent_dom() {
        use wasm_bindgen::JsCast as _;
        let _ = (|| -> Option<()> {
            let doc = web_sys::window()?.document()?;
            let el = doc.query_selector("input[type=text]").ok()??;
            el.unchecked_ref::<web_sys::HtmlElement>().focus().ok()
        })();
    }

    #[cfg(target_arch = "wasm32")]
    fn activate_keyboard_anchor(&mut self, ui: &egui::Ui) {
        self.keyboard_anchor_active = true;
        ui.ctx()
            .memory_mut(|m| m.request_focus(Self::kbd_anchor_id()));
        Self::focus_text_agent_dom();
    }
}

// ─── Private action types ─────────────────────────────────────────────────────

enum Action {
    None,
    SetOctave(u8),
    MoveRow(i32),
    MoveField(i32),
    MoveChannel(i32),
    /// `octave_boost` is 1 when Shift was held (raises entry note one octave).
    Entry {
        octave_boost: u8,
    },
    /// Shift all rows from the cursor downward by 1; clear the cursor row.
    /// Mirrors Pascal `DoInsertLine` / `SCA_PatternInsertLine`.
    InsertRow,
    /// Shift all rows above the pattern end upward by 1; clear the last row.
    /// Mirrors Pascal `DoRemoveLine` / `SCA_PatternDeleteLine`.
    DeleteRow,
    /// Zero every channel cell on the cursor row.
    /// Mirrors Pascal `SCA_PatternClearLine`.
    ClearRow,
}

enum EntryAction {
    None,
    NoteOff,
    ClearCell,
    ClearField,
    WriteNote(i8),
    WriteHex(u8),
}

impl PatternEditor {
    // ─── Public entry point ───────────────────────────────────────────────

    /// Show the pattern editor.
    ///
    /// `play_pos` — when the engine is playing, pass `Some((pattern_index,
    /// current_line))`.  The editor will follow the playhead: switch to the
    /// playing pattern, highlight the current row and keep it centred.
    pub fn show(&mut self, ui: &mut egui::Ui, module: &mut Module, play_pos: Option<(i32, usize)>) {
        // Follow the playhead when playback is active.
        if let Some((pat, _)) = play_pos {
            self.current_pattern = pat;
        }

        let pat_idx = Module::pat_idx(self.current_pattern);

        self.show_header(ui);

        if module.patterns[pat_idx].is_none() {
            if ui.button("Create pattern").clicked() {
                module.patterns[pat_idx] = Some(Box::new(vti_core::Pattern::default()));
            }
            return;
        }

        // Pattern length editor — mirrors Pascal `EdPatLen` / `UDPatLen`.
        {
            let pat = module.patterns[pat_idx].as_mut().unwrap();
            let mut len = pat.length;
            ui.horizontal(|ui| {
                ui.label("Len:");
                if ui
                    .add(
                        egui::DragValue::new(&mut len)
                            .range(1..=vti_core::MAX_PAT_LEN)
                            .speed(1),
                    )
                    .on_hover_text("Pattern length (rows). Range 1–256.")
                    .changed()
                {
                    pat.length = len;
                }
            });
        }

        let pat_len = module.patterns[pat_idx].as_ref().unwrap().length;

        // Clamp cursor to valid range (e.g. after pattern length change).
        if self.cursor.row >= pat_len {
            self.cursor.row = pat_len.saturating_sub(1);
        }

        // ── Key input (before rendering so mutations apply this frame) ────
        // Only skip key handling when a *different* text widget (e.g. the
        // module-title edit field) holds focus.  Allowing the keyboard-anchor
        // TextEdit (pat_kbd_anchor) to keep focus is intentional: that widget
        // exists solely to keep the browser <input> active on WASM so the
        // virtual keyboard stays visible.
        let skip_keys = ui.ctx().memory(|m| match m.focused() {
            None => false,
            Some(id) => id != Self::kbd_anchor_id(),
        });
        if !skip_keys {
            self.process_keys(ui, module, pat_len);
        }

        // ── Scroll area ───────────────────────────────────────────────────
        let row_height = 18.0;
        let available_height = ui.available_height();

        let playing_line: Option<usize> = play_pos.and_then(|(pat, line)| {
            if pat == self.current_pattern {
                Some(line)
            } else {
                None
            }
        });

        let mut scroll_area = egui::ScrollArea::vertical().auto_shrink([false, false]);
        // Follow playhead when playing; follow cursor after key entry.
        let scroll_target = playing_line.or_else(|| {
            if self.scroll_to_cursor {
                Some(self.cursor.row)
            } else {
                None
            }
        });
        if let Some(target) = scroll_target {
            let centred = (target as f32 * row_height) - (available_height / 2.0);
            scroll_area = scroll_area.vertical_scroll_offset(centred.max(0.0));
        }
        self.scroll_to_cursor = false;

        #[cfg(target_arch = "wasm32")]
        let mut activated_anchor_this_frame = false;

        // ── Grid ──────────────────────────────────────────────────────────
        let cursor_snap = self.cursor; // immutable snapshot for the closure
        scroll_area.show_rows(ui, row_height, pat_len, |ui, row_range| {
            egui::Grid::new("pattern_grid")
                .num_columns(1 + Field::COUNT * NUM_CH)
                .min_col_width(4.0)
                .striped(true)
                .show(ui, |ui| {
                    // Header
                    ui.label("Row");
                    for ch_label in ["Ch.A", "Ch.B", "Ch.C"] {
                        ui.label(ch_label);
                        for _ in 1..Field::COUNT {
                            ui.label("");
                        }
                    }
                    ui.end_row();

                    for row in row_range {
                        let is_cursor_row = row == cursor_snap.row;
                        let is_playing = playing_line == Some(row);
                        let row_data = &module.patterns[pat_idx].as_ref().unwrap().items[row];

                        // Background strip for the playing row.
                        if is_playing {
                            let row_rect = ui.cursor().expand(2.0);
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
                        let row_num_color = if is_playing {
                            egui::Color32::from_rgb(0, 255, 180)
                        } else if is_cursor_row {
                            egui::Color32::YELLOW
                        } else {
                            egui::Color32::GRAY
                        };
                        ui.label(
                            egui::RichText::new(format!("{:03X}", row))
                                .color(row_num_color)
                                .monospace(),
                        );

                        for ch in 0..NUM_CH {
                            let cell = &row_data.channel[ch];
                            let cursor_ch = cursor_snap.channel == ch && is_cursor_row;

                            macro_rules! cell_label {
                                ($text:expr, $base_color:expr, $field:expr) => {{
                                    let color = Self::field_color(
                                        $base_color,
                                        cursor_ch && cursor_snap.field == $field,
                                    );
                                    ui.add(
                                        egui::Label::new(
                                            egui::RichText::new($text).monospace().color(color),
                                        )
                                        .sense(egui::Sense::click()),
                                    )
                                }};
                            }

                            // Note
                            let note_str = note_to_str(cell.note);
                            let note_base = if is_playing {
                                match cell.note {
                                    n if n == NOTE_SOUND_OFF => {
                                        egui::Color32::from_rgb(255, 100, 100)
                                    }
                                    n if n == NOTE_NONE => egui::Color32::from_gray(120),
                                    _ => egui::Color32::WHITE,
                                }
                            } else {
                                match cell.note {
                                    n if n == NOTE_SOUND_OFF => egui::Color32::RED,
                                    n if n == NOTE_NONE => egui::Color32::DARK_GRAY,
                                    _ => egui::Color32::WHITE,
                                }
                            };
                            if cell_label!(note_str, note_base, Field::Note).clicked() {
                                self.cursor.row = row;
                                self.cursor.channel = ch;
                                self.cursor.field = Field::Note;
                                #[cfg(target_arch = "wasm32")]
                                {
                                    activated_anchor_this_frame = true;
                                    self.activate_keyboard_anchor(ui);
                                }
                            }

                            // Sample
                            let sam = if cell.sample == 0 {
                                "--".to_string()
                            } else {
                                format!("{:02X}", cell.sample)
                            };
                            if cell_label!(sam, egui::Color32::LIGHT_GREEN, Field::Sample).clicked()
                            {
                                self.cursor.row = row;
                                self.cursor.channel = ch;
                                self.cursor.field = Field::Sample;
                                #[cfg(target_arch = "wasm32")]
                                {
                                    activated_anchor_this_frame = true;
                                    self.activate_keyboard_anchor(ui);
                                }
                            }

                            // Ornament
                            let orn = format!("{:X}", cell.ornament);
                            if cell_label!(orn, egui::Color32::LIGHT_BLUE, Field::Ornament)
                                .clicked()
                            {
                                self.cursor.row = row;
                                self.cursor.channel = ch;
                                self.cursor.field = Field::Ornament;
                                #[cfg(target_arch = "wasm32")]
                                {
                                    activated_anchor_this_frame = true;
                                    self.activate_keyboard_anchor(ui);
                                }
                            }

                            // Volume
                            let vol = if cell.volume == 0 {
                                ".".to_string()
                            } else {
                                format!("{:X}", cell.volume)
                            };
                            if cell_label!(vol, egui::Color32::YELLOW, Field::Volume).clicked() {
                                self.cursor.row = row;
                                self.cursor.channel = ch;
                                self.cursor.field = Field::Volume;
                                #[cfg(target_arch = "wasm32")]
                                {
                                    activated_anchor_this_frame = true;
                                    self.activate_keyboard_anchor(ui);
                                }
                            }

                            // Envelope
                            let env = if cell.envelope == 0 {
                                ".".to_string()
                            } else {
                                format!("{:X}", cell.envelope)
                            };
                            if cell_label!(env, egui::Color32::LIGHT_RED, Field::Envelope).clicked()
                            {
                                self.cursor.row = row;
                                self.cursor.channel = ch;
                                self.cursor.field = Field::Envelope;
                                #[cfg(target_arch = "wasm32")]
                                {
                                    activated_anchor_this_frame = true;
                                    self.activate_keyboard_anchor(ui);
                                }
                            }

                            // Effect
                            let cmd = &cell.additional_command;
                            let fx = if cmd.number == 0 {
                                "......".to_string()
                            } else {
                                format!("{:X}{:02X}{:02X}", cmd.number, cmd.delay, cmd.parameter)
                            };
                            if cell_label!(fx, egui::Color32::from_gray(160), Field::Effect)
                                .clicked()
                            {
                                self.cursor.row = row;
                                self.cursor.channel = ch;
                                self.cursor.field = Field::Effect;
                                #[cfg(target_arch = "wasm32")]
                                {
                                    activated_anchor_this_frame = true;
                                    self.activate_keyboard_anchor(ui);
                                }
                            }
                        }
                        ui.end_row();
                    }
                });
        });

        // WASM: keep the keyboard anchor focused so egui's PlatformOutput always
        // has ime=Some(...), which causes eframe to call text_agent.focus() every
        // frame instead of text_agent.blur(), sustaining the virtual keyboard.
        // Skip if another text widget (e.g. a DragValue in keyboard-entry mode)
        // already holds focus — we must not steal it and prematurely end editing.
        #[cfg(target_arch = "wasm32")]
        {
            let kbd_id = Self::kbd_anchor_id();
            let pointer_pressed = ui.ctx().input(|i| i.pointer.any_pressed());
            let focused_is_anchor = ui.ctx().memory(|m| m.focused() == Some(kbd_id));
            if pointer_pressed && !focused_is_anchor && !activated_anchor_this_frame {
                self.keyboard_anchor_active = false;
                ui.ctx().memory_mut(|m| m.surrender_focus(kbd_id));
            }
            if self.keyboard_anchor_active
                && ui
                    .ctx()
                    .memory(|m| m.focused().map_or(true, |id| id == kbd_id))
            {
                ui.ctx().memory_mut(|m| m.request_focus(kbd_id));
            }
            // Drain any characters the TextEdit accumulated from Text events
            // this frame so the anchor always looks empty (hint: "⌨").
            self.keyboard_anchor.clear();
        }
    }

    // ─── Colour helpers ───────────────────────────────────────────────────

    /// Return `bright cyan` when the cell is at the cursor, `base` otherwise.
    fn field_color(base: egui::Color32, is_cursor: bool) -> egui::Color32 {
        if is_cursor {
            egui::Color32::from_rgb(0, 240, 240) // bright cyan = cursor position
        } else {
            base
        }
    }

    // ─── Header row ───────────────────────────────────────────────────────

    /// Render the horizontally-scrollable header row (Pattern, Octave, Step,
    /// and — on WASM — the mobile keyboard anchor).
    fn show_header(&mut self, ui: &mut egui::Ui) {
        // Wrap in a horizontal scroll area so all controls are reachable on
        // narrow screens by swiping left/right.  The row never wraps.
        // The scrollbar is hidden so it does not obscure the controls.
        egui::ScrollArea::horizontal()
            .id_source("pat_header_scroll")
            .scroll_bar_visibility(egui::scroll_area::ScrollBarVisibility::AlwaysHidden)
            .show(ui, |ui| {
                ui.horizontal(|ui| {
                    ui.label("Pattern:");
                    let mut p = self.current_pattern;
                    if ui
                        .add(egui::DragValue::new(&mut p).range(0..=vti_core::MAX_PAT_NUM as i32))
                        .changed()
                    {
                        self.current_pattern = p;
                        self.cursor.row = 0;
                    }

                    ui.separator();

                    ui.label("Octave:");
                    for oct in 1u8..=8 {
                        let btn = egui::Button::new(oct.to_string())
                            .selected(self.octave == oct)
                            .small();
                        if ui.add(btn).clicked() {
                            self.octave = oct;
                        }
                    }

                    ui.separator();

                    // Auto-advance step size — mirrors Pascal UDAutoStep.
                    ui.label("Step:");
                    ui.add(
                        egui::DragValue::new(&mut self.step_size)
                            .range(-64..=64)
                            .speed(1),
                    )
                    .on_hover_text(
                        "Rows to advance after each entry.\n\
                         0 = stay; negative = move up (Pascal UDAutoStep).",
                    );

                    // ── Mobile keyboard anchor (WASM only) ──────────────
                    // A zero-size, frameless TextEdit that exists solely to
                    // keep egui's PlatformOutput::ime = Some(…) every frame.
                    // That causes eframe to call text_agent.focus() instead
                    // of blur(), sustaining the virtual keyboard.
                    // It is intentionally invisible: no frame, no width.
                    #[cfg(target_arch = "wasm32")]
                    ui.scope(|ui| {
                        let mut style = (*ui.style()).clone();
                        style.visuals.text_cursor.stroke.color = egui::Color32::TRANSPARENT;
                        ui.set_style(style);
                        ui.add(
                            egui::TextEdit::singleline(&mut self.keyboard_anchor)
                                .id(Self::kbd_anchor_id())
                                .desired_width(0.0)
                                .frame(false),
                        );
                    });
                });
            });
    }

    // ─── Key input processing ─────────────────────────────────────────────

    fn process_keys(&mut self, ui: &mut egui::Ui, module: &mut Module, pat_len: usize) {
        use egui::Key;

        let action = ui.input(|i| {
            let alt = i.modifiers.alt && !i.modifiers.ctrl && !i.modifiers.shift;
            let shift = i.modifiers.shift && !i.modifiers.alt && !i.modifiers.ctrl;
            let ctrl = i.modifiers.ctrl && !i.modifiers.alt && !i.modifiers.shift;
            let none = !i.modifiers.any();

            // ── Ctrl shortcuts ───────────────────────────────────────────
            if ctrl {
                // Ctrl+I → insert row (SCA_PatternInsertLine)
                if i.key_pressed(Key::I) {
                    return Action::InsertRow;
                }
                // Ctrl+Backspace → delete row (SCA_PatternDeleteLine)
                if i.key_pressed(Key::Backspace) {
                    return Action::DeleteRow;
                }
                // Ctrl+Y → delete row (SCA_PatternDeleteLine2)
                if i.key_pressed(Key::Y) {
                    return Action::DeleteRow;
                }
                // Ctrl+Delete → clear row (SCA_PatternClearLine)
                if i.key_pressed(Key::Delete) {
                    return Action::ClearRow;
                }
                return Action::None; // leave other Ctrl combos for global shortcuts
            }

            // Alt+1..8 → set octave (mirrors Pascal OctaveActionExecute)
            if alt {
                const OCT: [Key; 8] = [
                    Key::Num1,
                    Key::Num2,
                    Key::Num3,
                    Key::Num4,
                    Key::Num5,
                    Key::Num6,
                    Key::Num7,
                    Key::Num8,
                ];
                for (idx, &key) in OCT.iter().enumerate() {
                    if i.key_pressed(key) {
                        return Action::SetOctave(idx as u8 + 1);
                    }
                }
                return Action::None;
            }

            // Cursor movement (no modifier)
            if none {
                if i.key_pressed(Key::ArrowDown) {
                    return Action::MoveRow(1);
                }
                if i.key_pressed(Key::ArrowUp) {
                    return Action::MoveRow(-1);
                }
                if i.key_pressed(Key::ArrowRight) {
                    return Action::MoveField(1);
                }
                if i.key_pressed(Key::ArrowLeft) {
                    return Action::MoveField(-1);
                }
                if i.key_pressed(Key::Tab) {
                    return Action::MoveChannel(1);
                }
                // Insert key (no modifier) → insert row (SCA_PatternTrackInsertLine)
                if i.key_pressed(Key::Insert) {
                    return Action::InsertRow;
                }
            }
            if shift && i.key_pressed(Key::Tab) {
                return Action::MoveChannel(-1);
            }

            // Entry (plain or shift — shift raises the note one octave)
            if none || shift {
                return Action::Entry {
                    octave_boost: if shift { 1 } else { 0 },
                };
            }

            Action::None
        });

        match action {
            Action::None => {}
            Action::SetOctave(o) => {
                self.octave = o;
            }
            Action::MoveRow(d) => {
                let r = self.cursor.row as i32 + d;
                if r >= 0 && r < pat_len as i32 {
                    self.cursor.row = r as usize;
                }
            }
            Action::MoveField(d) => {
                self.move_field(d);
            }
            Action::MoveChannel(d) => {
                self.move_channel(d);
            }
            Action::Entry { octave_boost } => {
                self.handle_entry(ui, module, pat_len, octave_boost);
            }
            Action::InsertRow => {
                self.insert_row(module);
            }
            Action::DeleteRow => {
                self.delete_row(module);
            }
            Action::ClearRow => {
                self.clear_row(module);
            }
        }
    }

    /// Dispatch a key press to the appropriate data mutation.
    fn handle_entry(
        &mut self,
        ui: &mut egui::Ui,
        module: &mut Module,
        pat_len: usize,
        octave_boost: u8,
    ) {
        use egui::Key;

        let field = self.cursor.field;
        let octave = (self.octave + octave_boost).min(8);

        let entry = ui.input(|i| -> EntryAction {
            match field {
                Field::Note => {
                    // Note-off: `1` key or `A` key (NK_RELEASE)
                    if i.key_pressed(Key::Num1) {
                        return EntryAction::NoteOff;
                    }
                    if i.key_pressed(Key::A) {
                        return EntryAction::NoteOff;
                    }
                    // Clear cell: K key (NK_EMPTY), Backspace, Delete
                    if i.key_pressed(Key::K) {
                        return EntryAction::ClearCell;
                    }
                    if i.key_pressed(Key::Backspace) {
                        return EntryAction::ClearCell;
                    }
                    if i.key_pressed(Key::Delete) {
                        return EntryAction::ClearCell;
                    }
                    // Piano note keys (physical + Event::Text fallback for mobile)
                    if let Some(offset) = Self::check_note_key(i) {
                        if let Some(note) = compute_note(offset, octave) {
                            return EntryAction::WriteNote(note);
                        }
                    }
                    // Mobile fallback for note-off / clear via Event::Text.
                    // '1', 'a', and 'k' are *not* piano keys
                    // (`piano_key_to_semitone_offset` returns None for them),
                    // so check_note_key above does not handle them.  They map
                    // to note-off (NK_RELEASE) and clear-cell (NK_EMPTY) in
                    // the Pascal source and must be caught here for mobile
                    // keyboards that deliver characters via Event::Text when
                    // keydown reports key="Unidentified".
                    for ev in &i.events {
                        if let egui::Event::Text(s) = ev {
                            if let Some(ch) = s.chars().next() {
                                let ch_l = ch.to_lowercase().next().unwrap_or(ch);
                                if ch_l == '1' || ch_l == 'a' {
                                    return EntryAction::NoteOff;
                                }
                                if ch_l == 'k' {
                                    return EntryAction::ClearCell;
                                }
                            }
                        }
                    }
                    EntryAction::None
                }
                _ => {
                    // Clear field
                    if i.key_pressed(Key::Backspace) {
                        return EntryAction::ClearField;
                    }
                    if i.key_pressed(Key::Delete) {
                        return EntryAction::ClearField;
                    }
                    // Hex digit (physical + Event::Text fallback for mobile)
                    if let Some(d) = Self::check_hex_key(i) {
                        return EntryAction::WriteHex(d);
                    }
                    EntryAction::None
                }
            }
        });

        match entry {
            EntryAction::None => {}
            EntryAction::NoteOff => {
                self.write_note(module, NOTE_SOUND_OFF);
                self.advance(pat_len);
            }
            EntryAction::ClearCell => {
                self.clear_cell(module);
                self.advance(pat_len);
            }
            EntryAction::ClearField => {
                self.clear_field(module);
                self.advance(pat_len);
            }
            EntryAction::WriteNote(n) => {
                self.write_note(module, n);
                self.advance(pat_len);
            }
            EntryAction::WriteHex(d) => {
                self.write_hex(module, d);
                self.advance(pat_len);
            }
        }
    }

    // ─── Note-key and hex-key detection ──────────────────────────────────

    /// Return the semitone offset for the first note key found in the input,
    /// or `None`.
    ///
    /// First checks physical key positions (egui `Key` enum) — this path is
    /// keyboard-locale–independent and works on desktop and hardware keyboards
    /// attached to mobile devices.
    ///
    /// Falls back to `Event::Text` so that mobile virtual keyboards, which
    /// sometimes emit `key = "Unidentified"` in `keydown` but still produce
    /// a proper character via the `input` event, are handled correctly.
    fn check_note_key(i: &egui::InputState) -> Option<i8> {
        use egui::Key::*;
        // Physical key → character mapping (hardware keyboard / desktop).
        let ch_from_key = if i.key_pressed(Z) {
            Some('z')
        } else if i.key_pressed(S) {
            Some('s')
        } else if i.key_pressed(X) {
            Some('x')
        } else if i.key_pressed(D) {
            Some('d')
        } else if i.key_pressed(C) {
            Some('c')
        } else if i.key_pressed(V) {
            Some('v')
        } else if i.key_pressed(G) {
            Some('g')
        } else if i.key_pressed(B) {
            Some('b')
        } else if i.key_pressed(H) {
            Some('h')
        } else if i.key_pressed(N) {
            Some('n')
        } else if i.key_pressed(J) {
            Some('j')
        } else if i.key_pressed(M) {
            Some('m')
        } else if i.key_pressed(Comma) {
            Some(',')
        } else if i.key_pressed(L) {
            Some('l')
        } else if i.key_pressed(Period) {
            Some('.')
        } else if i.key_pressed(Semicolon) {
            Some(';')
        } else if i.key_pressed(Slash) {
            Some('/')
        } else if i.key_pressed(Q) {
            Some('q')
        } else if i.key_pressed(Num2) {
            Some('2')
        } else if i.key_pressed(W) {
            Some('w')
        } else if i.key_pressed(Num3) {
            Some('3')
        } else if i.key_pressed(E) {
            Some('e')
        } else if i.key_pressed(R) {
            Some('r')
        } else if i.key_pressed(Num5) {
            Some('5')
        } else if i.key_pressed(T) {
            Some('t')
        } else if i.key_pressed(Num6) {
            Some('6')
        } else if i.key_pressed(Y) {
            Some('y')
        } else if i.key_pressed(Num7) {
            Some('7')
        } else if i.key_pressed(U) {
            Some('u')
        } else if i.key_pressed(I) {
            Some('i')
        } else if i.key_pressed(Num9) {
            Some('9')
        } else if i.key_pressed(O) {
            Some('o')
        } else if i.key_pressed(Num0) {
            Some('0')
        } else if i.key_pressed(P) {
            Some('p')
        } else if i.key_pressed(OpenBracket) {
            Some('[')
        } else if i.key_pressed(Equals) {
            Some('=')
        } else if i.key_pressed(CloseBracket) {
            Some(']')
        } else {
            None
        };

        if let Some(ch) = ch_from_key {
            return piano_key_to_semitone_offset(ch);
        }

        // Mobile fallback: check Event::Text for characters delivered by the
        // virtual keyboard when keydown carries key="Unidentified".
        // Events are ordered chronologically; the first matching character wins.
        for ev in &i.events {
            if let egui::Event::Text(s) = ev {
                if let Some(ch) = s.chars().next() {
                    // Normalise to lower-case so shifted keys are handled
                    // the same way as unshifted ones.
                    let ch_l = ch.to_lowercase().next().unwrap_or(ch);
                    if let Some(offset) = piano_key_to_semitone_offset(ch_l) {
                        return Some(offset);
                    }
                }
            }
        }
        None
    }

    /// Return the hex digit (0–15) if a hex key is pressed, or `None`.
    ///
    /// Checks physical `Key` events first, then falls back to `Event::Text`
    /// for mobile virtual keyboards.
    fn check_hex_key(i: &egui::InputState) -> Option<u8> {
        use egui::Key::*;
        // Physical key path.
        let from_key = if i.key_pressed(Num0) {
            Some(0)
        } else if i.key_pressed(Num1) {
            Some(1)
        } else if i.key_pressed(Num2) {
            Some(2)
        } else if i.key_pressed(Num3) {
            Some(3)
        } else if i.key_pressed(Num4) {
            Some(4)
        } else if i.key_pressed(Num5) {
            Some(5)
        } else if i.key_pressed(Num6) {
            Some(6)
        } else if i.key_pressed(Num7) {
            Some(7)
        } else if i.key_pressed(Num8) {
            Some(8)
        } else if i.key_pressed(Num9) {
            Some(9)
        } else if i.key_pressed(A) {
            Some(10)
        } else if i.key_pressed(B) {
            Some(11)
        } else if i.key_pressed(C) {
            Some(12)
        } else if i.key_pressed(D) {
            Some(13)
        } else if i.key_pressed(E) {
            Some(14)
        } else if i.key_pressed(F) {
            Some(15)
        } else {
            None
        };

        if from_key.is_some() {
            return from_key;
        }

        // Mobile fallback: derive hex digit from the first Text event character.
        // Events are ordered chronologically; the first matching character wins.
        for ev in &i.events {
            if let egui::Event::Text(s) = ev {
                if let Some(ch) = s.chars().next() {
                    let ch_l = ch.to_lowercase().next().unwrap_or(ch);
                    let d: Option<u8> = match ch_l {
                        '0'..='9' => Some(ch_l as u8 - b'0'),
                        'a'..='f' => Some(ch_l as u8 - b'a' + 10),
                        _ => None,
                    };
                    if let Some(digit) = d {
                        return Some(digit);
                    }
                }
            }
        }
        None
    }

    // ─── Cursor navigation ────────────────────────────────────────────────

    /// Cycle the field cursor by `delta` steps, wrapping across channels.
    ///
    /// Full order:  Ch0.Note → Ch0.Sample → … → Ch0.Effect →
    ///              Ch1.Note → … → Ch2.Effect → (wrap to Ch0.Note)
    fn move_field(&mut self, delta: i32) {
        let total = (NUM_CH * Field::COUNT) as i32;
        let current = (self.cursor.channel * Field::COUNT + self.cursor.field.index()) as i32;
        let next = ((current + delta).rem_euclid(total)) as usize;
        self.cursor.channel = next / Field::COUNT;
        self.cursor.field = Field::from_index(next % Field::COUNT);
    }

    /// Jump to the next / previous channel's Note column (Tab / Shift+Tab).
    fn move_channel(&mut self, delta: i32) {
        let next = ((self.cursor.channel as i32 + delta).rem_euclid(NUM_CH as i32)) as usize;
        self.cursor.channel = next;
        self.cursor.field = Field::Note;
    }

    // ─── Data mutation helpers ────────────────────────────────────────────

    fn cell_mut<'m>(&self, module: &'m mut Module) -> Option<&'m mut ChannelLine> {
        let pat = module.patterns[Module::pat_idx(self.current_pattern)].as_mut()?;
        if self.cursor.row >= pat.length {
            return None;
        }
        Some(&mut pat.items[self.cursor.row].channel[self.cursor.channel])
    }

    fn write_note(&mut self, module: &mut Module, note: i8) {
        if let Some(c) = self.cell_mut(module) {
            c.note = note;
        }
    }

    fn clear_cell(&mut self, module: &mut Module) {
        if let Some(c) = self.cell_mut(module) {
            *c = ChannelLine::default();
        }
    }

    fn clear_field(&mut self, module: &mut Module) {
        if let Some(c) = self.cell_mut(module) {
            match self.cursor.field {
                Field::Note => c.note = NOTE_NONE,
                Field::Sample => c.sample = 0,
                Field::Ornament => c.ornament = 0,
                Field::Volume => c.volume = 0,
                Field::Envelope => c.envelope = 0,
                Field::Effect => {
                    c.additional_command.number = 0;
                    c.additional_command.delay = 0;
                    c.additional_command.parameter = 0;
                }
            }
        }
    }

    fn write_hex(&mut self, module: &mut Module, digit: u8) {
        if let Some(c) = self.cell_mut(module) {
            match self.cursor.field {
                Field::Note => {} // dispatched separately
                Field::Sample => c.sample = hex_digit_entry(c.sample, digit, MAX_SAMPLE),
                Field::Ornament => c.ornament = hex_digit_entry(c.ornament, digit, MAX_NIBBLE),
                Field::Volume => c.volume = hex_digit_entry(c.volume, digit, MAX_NIBBLE),
                Field::Envelope => c.envelope = hex_digit_entry(c.envelope, digit, MAX_NIBBLE),
                Field::Effect => {
                    c.additional_command.number =
                        hex_digit_entry(c.additional_command.number, digit, MAX_NIBBLE);
                }
            }
        }
    }

    /// Advance the cursor row by `step_size`, clamped to the pattern length.
    fn advance(&mut self, pat_len: usize) {
        if self.step_size == 0 || pat_len == 0 {
            return;
        }
        let r = (self.cursor.row as i32 + self.step_size).clamp(0, pat_len as i32 - 1);
        self.cursor.row = r as usize;
        self.scroll_to_cursor = true;
    }

    // ─── Row insert / delete / clear ─────────────────────────────────────

    /// Shift all rows from `cursor.row` downward by one (discarding the last
    /// row in the backing array), then clear the cursor row.
    ///
    /// Mirrors Pascal `DoInsertLine` in `childwin.pas`.  Operates over the
    /// full `MAX_PAT_LEN` backing array so no row data is ever lost at the
    /// displayed length boundary — the last item in the 256-entry array is
    /// overwritten (the same behaviour as the Pascal source).
    fn insert_row(&mut self, module: &mut Module) {
        let pat = match module.patterns[Module::pat_idx(self.current_pattern)].as_mut() {
            Some(p) => p,
            None => return,
        };
        let row = self.cursor.row;
        if row >= pat.length {
            return;
        }

        // Shift rows [row..MAX_PAT_LEN-1] downward — last row is overwritten.
        for j in (row + 1..vti_core::MAX_PAT_LEN).rev() {
            pat.items[j] = pat.items[j - 1];
        }
        // Clear the vacated row.
        pat.items[row] = vti_core::PatternRow::default();
    }

    /// Shift all rows from `cursor.row + 1` upward by one (clearing the last
    /// row in the backing array), removing the cursor row.
    ///
    /// Mirrors Pascal `DoRemoveLine` in `childwin.pas`.
    fn delete_row(&mut self, module: &mut Module) {
        let pat = match module.patterns[Module::pat_idx(self.current_pattern)].as_mut() {
            Some(p) => p,
            None => return,
        };
        let row = self.cursor.row;
        if row >= pat.length {
            return;
        }

        // Shift rows [row+1..MAX_PAT_LEN-1] upward.
        for j in row..vti_core::MAX_PAT_LEN - 1 {
            pat.items[j] = pat.items[j + 1];
        }
        // Clear the now-duplicate last slot.
        pat.items[vti_core::MAX_PAT_LEN - 1] = vti_core::PatternRow::default();

        // Keep the cursor inside the pattern.
        if self.cursor.row >= pat.length && pat.length > 0 {
            self.cursor.row = pat.length - 1;
        }
    }

    /// Reset every channel cell on the cursor row to its default state.
    ///
    /// Mirrors Pascal `SCA_PatternClearLine`.
    fn clear_row(&mut self, module: &mut Module) {
        let pat = match module.patterns[Module::pat_idx(self.current_pattern)].as_mut() {
            Some(p) => p,
            None => return,
        };
        let row = self.cursor.row;
        if row >= pat.length {
            return;
        }
        let item = &mut pat.items[row];
        for ch in 0..NUM_CH {
            item.channel[ch] = ChannelLine::default();
        }
        item.noise = 0;
        item.envelope = 0;
    }
}
