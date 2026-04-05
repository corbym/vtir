//! Smoke tests for the FLS (Flying Ledger Sound) format parser.
//!
//! Each test verifies: (1) `Err` on empty/too-small input, (2) `Ok` and no
//! panic on a minimal zeroed blob.

use vti_core::formats::fls;

#[test]
fn fls_errors_on_empty() {
    assert!(fls::parse(&[]).is_err());
}

#[test]
fn fls_ok_on_minimal_header() {
    // All-zero 64-byte blob: pos_ptr=0 → delay at [0]=0, no positions (byte[1]=0).
    let data = [0u8; 64];
    let result = fls::parse(&data);
    assert!(result.is_ok(), "fls minimal: {:?}", result.err());
}
