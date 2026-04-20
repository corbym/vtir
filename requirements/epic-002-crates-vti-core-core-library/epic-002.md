# EPIC-002: crates/vti-core — Core Library

## Goal

Data types, note tables, playback engine, utility functions, format parsers/writers, and integration tests ported from trfuncs.pas.

## Stories

- [x] [STORY-024](story-024.md) — Data Types (types.rs) — ported from trfuncs.pas
- [x] [STORY-025](story-025.md) — Note Tables (note_tables.rs) — ported from trfuncs.pas
- [x] [STORY-026](story-026.md) — Playback Engine (playback.rs) — ported from trfuncs.pas
- [ ] [STORY-027](story-027.md) — Utility Functions (util.rs)
- [x] [STORY-028](story-028.md) — PT3 format parser + writer (formats/pt3.rs) — PT32VTM / VTM2PT3
- [x] [STORY-029](story-029.md) — PT2 format parser (formats/pt2.rs) — PT22VTM
- [x] [STORY-030](story-030.md) — PT1 format parser (formats/pt1.rs) — PT12VTM
- [x] [STORY-031](story-031.md) — STC format parser (formats/stc.rs) — STC2VTM
- [x] [STORY-032](story-032.md) — ASC / ASC0 format parser (formats/asc.rs) — ASC2VTM / ASC02VTM
- [x] [STORY-033](story-033.md) — STP format parser (formats/stp.rs) — STP2VTM
- [x] [STORY-034](story-034.md) — SQT format parser (formats/sqt.rs) — SQT2VTM
- [x] [STORY-035](story-035.md) — GTR format parser (formats/gtr.rs) — GTR2VTM
- [ ] [STORY-036](story-036.md) — FTC format parser (formats/ftc.rs) — FTC2VTM
- [x] [STORY-037](story-037.md) — FLS format parser (formats/fls.rs) — FLS2VTM
- [ ] [STORY-038](story-038.md) — PSC format parser (formats/psc.rs) — PSC2VTM
- [ ] [STORY-039](story-039.md) — PSM format parser (formats/psm.rs) — PSM2VTM
- [ ] [STORY-040](story-040.md) — FXM format parser (formats/fxm.rs) — FXM2VTM
- [ ] [STORY-041](story-041.md) — AY (ZXAY container) parser (formats/ay.rs) — ST11 / AMAD / EMUL variants
- [ ] [STORY-042](story-042.md) — VTM text format — VTM2TextFile / LoadModuleFromText
- [ ] [STORY-043](story-043.md) — Format auto-detection (formats/)
- [ ] [STORY-044](story-044.md) — vti-core Integration Tests (tests/integration_tests.rs)
