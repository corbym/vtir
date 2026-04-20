//! Unit tests for format detection and the `load_and_detect` / `load_and_detect` API.

use vti_core::formats::{detect_format_from_bytes, load_and_detect};

// ─── detect_format_from_bytes ────────────────────────────────────────────────

#[test]
fn detect_ay_by_magic() {
    // AY container starts with "ZXAYEMUL"
    let mut data = b"ZXAYEMUL".to_vec();
    data.extend_from_slice(&[0u8; 16]);
    assert_eq!(detect_format_from_bytes(&data), Some("ay"));
}

#[test]
fn detect_vtm_by_magic() {
    let data = b"[Module]\nTitle=test\n";
    assert_eq!(detect_format_from_bytes(data), Some("vtm"));
}

#[test]
fn detect_pt3_by_header_text() {
    // PT3 text header contains "ProTracker 3" within the first 100 bytes.
    let mut data = vec![0u8; 200];
    let marker = b"ProTracker 3.60";
    data[30..30 + marker.len()].copy_from_slice(marker);
    assert_eq!(detect_format_from_bytes(&data), Some("pt3"));
}

#[test]
fn detect_returns_none_for_unknown_bytes() {
    let data = [0u8; 32];
    assert_eq!(detect_format_from_bytes(&data), None);
}

#[test]
fn detect_returns_none_for_empty() {
    assert_eq!(detect_format_from_bytes(&[]), None);
}

// ─── load_and_detect ─────────────────────────────────────────────────────────

#[test]
fn load_and_detect_errors_on_unknown_format() {
    let data = [0u8; 32];
    assert!(load_and_detect(&data).is_err());
}

#[test]
fn load_and_detect_parses_vtm() {
    // A minimal but valid VTM module text.
    let vtm = "[Module]\nTitle=\nAuthor=\nNoteTable=1\nSpeed=3\nPlayOrder=L0\n\
               [Position0]\nPattern=0\n[Pattern0]\n[End]\n";
    let module = load_and_detect(vtm.as_bytes()).expect("should parse VTM");
    assert_eq!(module.title, "");
}
