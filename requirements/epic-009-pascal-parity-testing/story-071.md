# STORY-071: Rust baseline tests (tests/pascal_baseline_tests.rs in each crate)

**Type:** chore

## Goal

Describe what this story should accomplish.

## Acceptance criteria

- [x] `vti-ay::noise_lfsr_matches_pascal_baseline` — passing
- [x] `vti-ay::envelope_shapes_match_pascal_baseline` — passing
- [x] `vti-ay::envelope_shape_from_register_matches_baseline` — passing
- [x] `vti-ay::level_tables_match_pascal_baseline` — passing
- [x] `vti-core::pt3_vol_matches_pascal_baseline` — passing
- [x] `vti-core::note_tables_match_pascal_baseline` — passing
- [x] `vti-core::pattern_play_basic_matches_pascal_baseline` — passing
- [x] `vti-core::pattern_play_envelope_matches_pascal_baseline` — passing
- [x] `vti-core::pattern_play_arpeggio_matches_pascal_baseline` — passing (covers ornament stepping and noise mixer path)
- [x] `vti-core::song_timing_matches_pascal_baseline` — passing (covers all four timing helpers)

## Notes

<!-- backlog-mcp: 2026-04-20T19:26:46Z -->
All 10 Pascal baseline Rust tests passing across vti-ay and vti-core crates.
