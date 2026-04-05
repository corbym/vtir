//! Smoke tests for the GTR (Global Tracker) format parser.
//!
//! Each test verifies: (1) `Err` on empty/too-small input, (2) `Ok` and no
//! panic on a minimal zeroed header.

use vti_core::formats::gtr;

#[test]
fn gtr_errors_on_empty() {
    assert!(gtr::parse(&[]).is_err());
}

#[test]
fn gtr_ok_on_minimal_header() {
    // 296-byte zeroed header: GTR_NumberOfPositions=0 → empty module, no panic.
    let data = [0u8; 296];
    let result = gtr::parse(&data);
    assert!(result.is_ok(), "gtr minimal: {:?}", result.err());
    assert_eq!(result.unwrap().positions.length, 0);
}
