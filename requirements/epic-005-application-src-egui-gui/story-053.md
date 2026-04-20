# STORY-053: Pattern Editor (ui/pattern_editor.rs)

**Type:** feature

## Goal

Describe what this story should accomplish.

## Acceptance criteria

- [x] Grid display — row numbers, 3 channels, note / sample / ornament / volume / env / effect columns
- [x] Cursor (row + channel + field)
- [x] Arrow-key navigation
- [x] Pattern selector (drag value)
- [x] Colour-coded cells (note off = red, empty = dark grey)
- [x] Playback cursor follow — highlighted playing row (cyan-green), auto-scrolls to keep it centred, auto-switches to the playing pattern (`RedrawPlWindow` equivalent)
- [x] Octave buttons 1–8 (highlighted active), Alt+1..8 keyboard shortcuts — mirrors Pascal `OctaveActionExecute` / `SCA_Octave1..8`
- [x] Full keyboard note entry — two-row piano layout (z=C, s=C#, x=D … mirroring `NoteKeysSetDefault`); `A`/`1` = note-off; `K`/Backspace/Delete = clear cell; Shift+key = octave+1
- [x] Hex digit entry — shift-insert on Sample (0–31) / Ornament / Volume / Envelope / Effect (0–15) fields; `vti_core::editor::hex_digit_entry`
- [x] Left/Right arrow field navigation — cycles Note→Sample→Ornament→Volume→Envelope→Effect across all three channels; Tab/Shift+Tab jump channel
- [x] All cells clickable — click sets cursor to the exact (row, channel, field)
- [x] Cursor cell highlighted — bright cyan on the active (row, channel, field)
- [x] Configurable auto-advance step size — DragValue `Step:` (−64..+64, default 1, 0=disabled) mirrors Pascal `UDAutoStep`; cursor scrolls to follow after each entry
- [x] Pure editor logic in `crates/vti-core/src/editor.rs` — `piano_key_to_semitone_offset`, `compute_note`, `note_key_result`, `hex_digit_entry`; 21 unit tests + CLI smoke tests
- [x] Pattern length editor — DragValue `Len:` (1–256) in header row mirrors Pascal `EdPatLen` / `UDPatLen`
- [x] Insert row — `Ctrl+I` or `Insert`: shifts rows down from cursor, clears cursor row (mirrors Pascal `DoInsertLine` / `SCA_PatternInsertLine`)
- [x] Delete row — `Ctrl+Backspace` or `Ctrl+Y`: shifts rows up from cursor, clears last row (mirrors Pascal `DoRemoveLine` / `SCA_PatternDeleteLine`)
- [x] Clear row — `Ctrl+Delete`: resets every channel cell on the cursor row (mirrors Pascal `SCA_PatternClearLine`)
- [ ] Copy / paste row or block
- [ ] Transpose selection (semitone / octave)
- [ ] Loop-back indicator on position-list loop row
