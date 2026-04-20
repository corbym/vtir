# STORY-070: Fixture files — committed Pascal baseline JSON fixtures

**Type:** chore

## Goal

Describe what this story should accomplish.

## Acceptance criteria

- [x] `crates/vti-ay/tests/fixtures/pascal-baselines/noise_lfsr.json` — 200-step LFSR sequence, seed + noise_val
- [x] `crates/vti-ay/tests/fixtures/pascal-baselines/envelope_shapes.json` — All 8 envelope shapes, 64 steps each
- [x] `crates/vti-ay/tests/fixtures/pascal-baselines/level_tables.json` — AY + YM stereo level tables, default panning
- [x] `crates/vti-core/tests/fixtures/pascal-baselines/pt3_vol.json` — 16×16 PT3_Vol table
- [x] `crates/vti-core/tests/fixtures/pascal-baselines/note_tables.json` — All 5 note tables, 96 entries each
- [x] `crates/vti-core/tests/fixtures/pascal-baselines/pattern_play_basic.json` — 20 ticks of pure-tone 4-row pattern
- [x] `crates/vti-core/tests/fixtures/pascal-baselines/pattern_play_envelope.json` — Same pattern + AY envelope type 8
- [x] `crates/vti-core/tests/fixtures/pascal-baselines/pattern_play_arpeggio.json` — 54 ticks: 3-ch arpeggio + noise drum (ornament stepping, noise mixer path)
- [x] `crates/vti-core/tests/fixtures/pascal-baselines/song_timing.json` — `GetModuleTime`, `GetPositionTime`, `GetPositionTimeEx`, `GetTimeParams` on a 2-position module with a mid-pattern delay change

## Notes

<!-- backlog-mcp: 2026-04-20T19:26:46Z -->
All 9 Pascal baseline JSON fixtures committed covering LFSR, envelope shapes, level tables, note tables, PT3_VOL, pattern play variants, and song timing.
