//! Smoke tests for the SQT (Square Tracker) format parser.
//!
//! Each test verifies: (1) `Err` on empty/too-small input, (2) `Ok` and no
//! panic on a minimal zeroed header.

use vti_core::formats::sqt;

#[test]
fn sqt_errors_on_empty() {
    assert!(sqt::parse(&[]).is_err());
}

#[test]
fn sqt_errors_on_too_small() {
    assert!(sqt::parse(&[0u8; 5]).is_err());
}

#[test]
fn sqt_ok_on_minimal_header() {
    // 12-byte all-zero header: SQT_PositionsPointer=0 → first position byte=0 → terminates.
    let data = [0u8; 12];
    let result = sqt::parse(&data);
    assert!(result.is_ok(), "sqt minimal: {:?}", result.err());
    assert_eq!(result.unwrap().positions.length, 0);
}
