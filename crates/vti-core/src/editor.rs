//! Pure editor logic — note key mapping and hex digit entry.
//!
//! These functions are free of any UI dependency so they can be tested
//! in the CLI harness and reused by WASM/mobile frontends.
//!
//! The keyboard layout mirrors the default `NoteKeysSetDefault` in
//! `legacy/keys.pas` (c) 2000-2024 S.V.Bulba.

/// Result of pressing a key in the note-entry field.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum NoteKeyResult {
    /// A specific absolute note value (0..=95).
    Note(i8),
    /// Note-off / sound-off sentinel ("R--").
    SoundOff,
    /// Clear the entire channel cell.
    ClearCell,
}

/// Map a (lowercase) key character to a semitone offset within the
/// two-row tracker piano layout, identical to the default VT2 mapping
/// from `legacy/keys.pas::NoteKeysSetDefault`.
///
/// Returns `Some(offset)` where `offset` is 0..=31 (spanning C up through
/// G two octaves above), or `None` if the key is not a note key.
///
/// Callers add `(octave − 1) × 12` to the offset to obtain the absolute
/// note value; see [`compute_note`].
pub fn piano_key_to_semitone_offset(ch: char) -> Option<i8> {
    match ch {
        // ── Bottom row — current octave (C .. B) ──────────────────────
        'z' => Some(0),   // C    (NK_DO)
        's' => Some(1),   // C#   (NK_DODiesis)
        'x' => Some(2),   // D    (NK_RE)
        'd' => Some(3),   // D#   (NK_REDiesis)
        'c' => Some(4),   // E    (NK_MI)
        'v' => Some(5),   // F    (NK_FA)
        'g' => Some(6),   // F#   (NK_FADiesis)
        'b' => Some(7),   // G    (NK_SOL)
        'h' => Some(8),   // G#   (NK_SOLDiesis)
        'n' => Some(9),   // A    (NK_LA)
        'j' => Some(10),  // A#   (NK_LADiesis)
        'm' => Some(11),  // B    (NK_SI)
        // ── Bottom row extended — octave+1 (lower position) ───────────
        ',' => Some(12),  // C+1  (NK_DO2,       VK_OEM_COMMA)
        'l' => Some(13),  // C#+1 (NK_DODiesis2, VK_L)
        '.' => Some(14),  // D+1  (NK_RE2,        VK_OEM_PERIOD)
        ';' => Some(15),  // D#+1 (NK_REDiesis2,  VK_OEM_1)
        '/' => Some(16),  // E+1  (NK_MI2,         VK_OEM_2)
        // ── Top row — octave+1 (duplicates + extension) ───────────────
        'q' => Some(12),  // C+1  (NK_DO2)
        '2' => Some(13),  // C#+1 (NK_DODiesis2)
        'w' => Some(14),  // D+1  (NK_RE2)
        '3' => Some(15),  // D#+1 (NK_REDiesis2)
        'e' => Some(16),  // E+1  (NK_MI2)
        'r' => Some(17),  // F+1  (NK_FA2)
        '5' => Some(18),  // F#+1 (NK_FADiesis2)
        't' => Some(19),  // G+1  (NK_SOL2)
        '6' => Some(20),  // G#+1 (NK_SOLDiesis2)
        'y' => Some(21),  // A+1  (NK_LA2)
        '7' => Some(22),  // A#+1 (NK_LADiesis2)
        'u' => Some(23),  // B+1  (NK_SI2)
        // ── Top row extended — octave+2 ───────────────────────────────
        'i' => Some(24),  // C+2  (NK_DO3)
        '9' => Some(25),  // C#+2 (NK_DODiesis3)
        'o' => Some(26),  // D+2  (NK_RE3)
        '0' => Some(27),  // D#+2 (NK_REDiesis3)
        'p' => Some(28),  // E+2  (NK_MI3)
        '[' => Some(29),  // F+2  (NK_FA3,        VK_OEM_4)
        '=' => Some(30),  // F#+2 (NK_FADiesis3,  VK_OEM_PLUS)
        ']' => Some(31),  // G+2  (NK_SOL3,        VK_OEM_6)
        _ => None,
    }
}

/// Compute the absolute note value (0..=95) from a semitone offset and octave.
///
/// Returns `None` if the resulting note is outside the valid range.
pub fn compute_note(semitone_offset: i8, octave: u8) -> Option<i8> {
    let note = semitone_offset as i32 + (octave as i32 - 1) * 12;
    if (0..=95).contains(&note) {
        Some(note as i8)
    } else {
        None
    }
}

/// Resolve a (lowercase) key character and octave into a [`NoteKeyResult`].
///
/// Mapping:
/// - `'a'` → [`NoteKeyResult::SoundOff`]   (NK_RELEASE, "R--")
/// - `'k'` → [`NoteKeyResult::ClearCell`]   (NK_EMPTY,   "---")
/// - note key + octave → [`NoteKeyResult::Note`]
/// - anything else → `None`
pub fn note_key_result(ch: char, octave: u8) -> Option<NoteKeyResult> {
    if ch == 'a' {
        return Some(NoteKeyResult::SoundOff);
    }
    if ch == 'k' {
        return Some(NoteKeyResult::ClearCell);
    }
    let offset = piano_key_to_semitone_offset(ch)?;
    compute_note(offset, octave).map(NoteKeyResult::Note)
}

/// Perform a hex digit entry into a tracker field using the shift-insert
/// convention used by Vortex Tracker II.
///
/// - **Single-digit fields** (`max ≤ 0x0F`, e.g. ornament, volume, envelope):
///   returns `digit.min(max)` — each press overwrites the field entirely.
/// - **Two-digit fields** (`max > 0x0F`, e.g. sample 0..31, effect delay/param):
///   shifts the old value's lower nibble into the upper nibble and inserts the
///   new digit, then clamps to `max`.  This gives the classic left-shift entry:
///   typing `1` then `5` results in `0x15 = 21`.
///
/// `digit` must be in the range `0..=15`.
pub fn hex_digit_entry(old: u8, digit: u8, max: u8) -> u8 {
    debug_assert!(digit <= 0x0F, "digit must be in 0..=15");
    if max <= 0x0F {
        digit.min(max)
    } else {
        let new_val = ((old & 0x0F) << 4) | (digit & 0x0F);
        new_val.min(max)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    // ── piano_key_to_semitone_offset ─────────────────────────────────────────

    #[test]
    fn bottom_row_white_keys() {
        assert_eq!(piano_key_to_semitone_offset('z'), Some(0));   // C
        assert_eq!(piano_key_to_semitone_offset('x'), Some(2));   // D
        assert_eq!(piano_key_to_semitone_offset('c'), Some(4));   // E
        assert_eq!(piano_key_to_semitone_offset('v'), Some(5));   // F
        assert_eq!(piano_key_to_semitone_offset('b'), Some(7));   // G
        assert_eq!(piano_key_to_semitone_offset('n'), Some(9));   // A
        assert_eq!(piano_key_to_semitone_offset('m'), Some(11));  // B
    }

    #[test]
    fn bottom_row_black_keys() {
        assert_eq!(piano_key_to_semitone_offset('s'), Some(1));   // C#
        assert_eq!(piano_key_to_semitone_offset('d'), Some(3));   // D#
        assert_eq!(piano_key_to_semitone_offset('g'), Some(6));   // F#
        assert_eq!(piano_key_to_semitone_offset('h'), Some(8));   // G#
        assert_eq!(piano_key_to_semitone_offset('j'), Some(10));  // A#
    }

    #[test]
    fn top_row_octave_plus1() {
        assert_eq!(piano_key_to_semitone_offset('q'), Some(12));  // C+1
        assert_eq!(piano_key_to_semitone_offset('2'), Some(13));  // C#+1
        assert_eq!(piano_key_to_semitone_offset('w'), Some(14));  // D+1
        assert_eq!(piano_key_to_semitone_offset('3'), Some(15));  // D#+1
        assert_eq!(piano_key_to_semitone_offset('e'), Some(16));  // E+1
        assert_eq!(piano_key_to_semitone_offset('r'), Some(17));  // F+1
        assert_eq!(piano_key_to_semitone_offset('5'), Some(18));  // F#+1
        assert_eq!(piano_key_to_semitone_offset('t'), Some(19));  // G+1
        assert_eq!(piano_key_to_semitone_offset('6'), Some(20));  // G#+1
        assert_eq!(piano_key_to_semitone_offset('y'), Some(21));  // A+1
        assert_eq!(piano_key_to_semitone_offset('7'), Some(22));  // A#+1
        assert_eq!(piano_key_to_semitone_offset('u'), Some(23));  // B+1
    }

    #[test]
    fn top_row_octave_plus2() {
        assert_eq!(piano_key_to_semitone_offset('i'), Some(24));  // C+2
        assert_eq!(piano_key_to_semitone_offset('9'), Some(25));  // C#+2
        assert_eq!(piano_key_to_semitone_offset('o'), Some(26));  // D+2
        assert_eq!(piano_key_to_semitone_offset('0'), Some(27));  // D#+2
        assert_eq!(piano_key_to_semitone_offset('p'), Some(28));  // E+2
        assert_eq!(piano_key_to_semitone_offset('['), Some(29));  // F+2
        assert_eq!(piano_key_to_semitone_offset('='), Some(30));  // F#+2
        assert_eq!(piano_key_to_semitone_offset(']'), Some(31));  // G+2
    }

    #[test]
    fn bottom_row_extension_lower_position() {
        // These keyboard positions map to C+1..E+1 (same as q/2/w/3/e)
        assert_eq!(piano_key_to_semitone_offset(','), Some(12));
        assert_eq!(piano_key_to_semitone_offset('l'), Some(13));
        assert_eq!(piano_key_to_semitone_offset('.'), Some(14));
        assert_eq!(piano_key_to_semitone_offset(';'), Some(15));
        assert_eq!(piano_key_to_semitone_offset('/'), Some(16));
    }

    #[test]
    fn non_note_keys_return_none() {
        // a = note-off, not a note key
        assert_eq!(piano_key_to_semitone_offset('a'), None);
        // k = clear cell, not a note key
        assert_eq!(piano_key_to_semitone_offset('k'), None);
        // f, 1, 4, 8 are unused in the default VT2 layout
        assert_eq!(piano_key_to_semitone_offset('f'), None);
        assert_eq!(piano_key_to_semitone_offset('1'), None);
        assert_eq!(piano_key_to_semitone_offset('4'), None);
        assert_eq!(piano_key_to_semitone_offset('8'), None);
    }

    // ── compute_note ─────────────────────────────────────────────────────────

    #[test]
    fn c4_is_36() {
        // C-4 = semitone offset 0 + (4-1)*12 = 36
        assert_eq!(compute_note(0, 4), Some(36));
    }

    #[test]
    fn b4_is_47() {
        assert_eq!(compute_note(11, 4), Some(47));
    }

    #[test]
    fn c1_is_0() {
        assert_eq!(compute_note(0, 1), Some(0));
    }

    #[test]
    fn b8_is_95() {
        // B-8 = 11 + (8-1)*12 = 11 + 84 = 95
        assert_eq!(compute_note(11, 8), Some(95));
    }

    #[test]
    fn out_of_range_returns_none() {
        // offset 31 (G+2) at octave 8 → 31 + 84 = 115 > 95
        assert_eq!(compute_note(31, 8), None);
        // negative octave adjustment (octave=1, offset=0 → 0 OK)
        assert_eq!(compute_note(0, 1), Some(0));
    }

    // ── note_key_result ───────────────────────────────────────────────────────

    #[test]
    fn a_gives_sound_off() {
        assert_eq!(note_key_result('a', 4), Some(NoteKeyResult::SoundOff));
    }

    #[test]
    fn k_gives_clear_cell() {
        assert_eq!(note_key_result('k', 4), Some(NoteKeyResult::ClearCell));
    }

    #[test]
    fn z_at_octave4_gives_c4() {
        assert_eq!(note_key_result('z', 4), Some(NoteKeyResult::Note(36)));
    }

    #[test]
    fn u_at_octave4_gives_b5() {
        // 'u' → offset 23 (B+1), octave 4 → 23 + 36 = 59 = B-5
        assert_eq!(note_key_result('u', 4), Some(NoteKeyResult::Note(59)));
    }

    #[test]
    fn out_of_range_note_gives_none() {
        // ']' → offset 31, octave 8 → 31+84 = 115 > 95 → None
        assert_eq!(note_key_result(']', 8), None);
    }

    #[test]
    fn unknown_key_gives_none() {
        assert_eq!(note_key_result('f', 4), None);
        assert_eq!(note_key_result('1', 4), None);
    }

    // ── hex_digit_entry ───────────────────────────────────────────────────────

    #[test]
    fn single_digit_field_overwrites() {
        // Volume/ornament/envelope: max = 15
        assert_eq!(hex_digit_entry(0, 7, 15), 7);
        assert_eq!(hex_digit_entry(7, 15, 15), 15);
        assert_eq!(hex_digit_entry(7, 3, 15), 3);   // overwrites, not shifts
    }

    #[test]
    fn single_digit_clamped_to_max() {
        assert_eq!(hex_digit_entry(0, 15, 15), 15);
    }

    #[test]
    fn two_digit_sample_field() {
        // Sample: max = 31 (0x1F)
        assert_eq!(hex_digit_entry(0, 1, 31), 0x01);  // type '1' → 1
        assert_eq!(hex_digit_entry(1, 5, 31), 0x15);  // type '5' → 21
        assert_eq!(hex_digit_entry(1, 15, 31), 0x1F); // type 'F' → 31 (max)
        assert_eq!(hex_digit_entry(2, 0, 31), 31);    // (0x20=32) clamped to 31
    }

    #[test]
    fn two_digit_effect_param() {
        // Effect delay/parameter: max = 255 (0xFF)
        assert_eq!(hex_digit_entry(0, 3, 255), 0x03);
        assert_eq!(hex_digit_entry(3, 7, 255), 0x37);
        // Lower nibble of 0xFF shifted: ((0xFF & 0x0F) << 4) | 5 = 0xF5
        assert_eq!(hex_digit_entry(0xFF, 5, 255), 0xF5);
    }
}
