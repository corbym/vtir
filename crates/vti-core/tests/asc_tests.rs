//! Smoke tests for the ASC Sound Master (v1 / v0) format parser.
//!
//! Each test verifies: (1) `Err` on empty/too-small input, (2) `Ok` and no
//! panic on a minimal zeroed header.

use vti_core::formats::asc;

#[test]
fn asc_errors_on_empty() {
    assert!(asc::parse(&[]).is_err());
}

#[test]
fn asc0_errors_on_empty() {
    assert!(asc::parse_asc0(&[]).is_err());
}

#[test]
fn asc_ok_on_minimal_header() {
    // 10-byte zeroed blob: delay=0, loop=0, pat_ptrs=0, sam_ptrs=0, orn_ptrs=0, num_pos=0.
    let data = [0u8; 10];
    let result = asc::parse(&data);
    assert!(result.is_ok(), "asc minimal: {:?}", result.err());
    assert_eq!(result.unwrap().positions.length, 0);
}
