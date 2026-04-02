//! Utility helper functions.
//!
//! Ported from `trfuncs.pas` (c) 2000-2009 S.V.Bulba.

/// Format an integer as a two-digit zero-padded decimal string.
#[inline]
pub fn int2_to_str(i: i32) -> String {
    format!("{:02}", i)
}

/// Format a signed integer as one digit with decimal point (e.g. "3.2").
#[inline]
pub fn int1d_to_str(i: i32) -> String {
    format!("{}.{}", i / 10, i.abs() % 10)
}

/// Format a sample index as two hex digits.
#[inline]
pub fn samp_to_str(i: i32) -> String {
    format!("{:02X}", i)
}

/// Format a four-digit hex integer.
#[inline]
pub fn int4d_to_str(i: i32) -> String {
    format!("{:04X}", i)
}

/// Format a two-digit hex integer.
#[inline]
pub fn int2d_to_str(i: i32) -> String {
    format!("{:02X}", i)
}

/// Convert a tick count to a time string "MM:SS".
#[inline]
pub fn ints_to_time(ticks: i32) -> String {
    let secs = ticks / 50; // 50 Hz default
    format!("{:02}:{:02}", secs / 60, secs % 60)
}

/// Note names, C through B (one octave).
pub const NOTE_NAMES: [&str; 12] = [
    "C-", "C#", "D-", "D#", "E-", "F-", "F#", "G-", "G#", "A-", "A#", "B-",
];

/// Convert a note index (0..95) to a display string like "C-4".
#[inline]
pub fn note_to_str(note: i8) -> String {
    if note == -2 {
        return "R--".to_string();
    }
    if note < 0 {
        return "---".to_string();
    }
    let n = note as usize;
    let octave = n / 12 + 1;
    let name = NOTE_NAMES[n % 12];
    format!("{}{}", name, octave)
}
