//! Unit tests for `detect_format_from_bytes`, `load_and_detect`, and related
//! format-detection / loading helpers.

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
fn load_and_detect_errors_on_real_junk() {
    // A file full of random-looking non-zero bytes that match no known magic.
    let junk: Vec<u8> = (0u8..=127).chain(128u8..=255).collect();
    assert!(
        load_and_detect(&junk).is_err(),
        "junk bytes should not match any format"
    );
}

#[test]
fn load_and_detect_parses_vtm() {
    // A minimal but valid VTM module text.
    let vtm = "[Module]\nTitle=\nAuthor=\nNoteTable=1\nSpeed=3\nPlayOrder=L0\n\
               [Position0]\nPattern=0\n[Pattern0]\n[End]\n";
    let module = load_and_detect(vtm.as_bytes()).expect("should parse VTM");
    assert_eq!(module.title, "");
}

#[test]
fn load_and_detect_loads_real_vtm_file_without_extension() {
    // madness_descent_no_ext is a copy of madness_descent.vtm with the
    // extension removed.  load_and_detect must detect it as VTM from content.
    let bytes = include_bytes!(
        "fixtures/tunes/madness_descent_no_ext"
    );
    let module = load_and_detect(bytes).expect("should detect and parse VTM");
    assert_eq!(module.title, "Descent Into Madness");
    assert_eq!(module.author, "VTIR Test Fixture");
}
