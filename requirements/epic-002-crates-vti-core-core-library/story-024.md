# STORY-024: Data Types (types.rs) — ported from trfuncs.pas

**Type:** chore

## Goal

Describe what this story should accomplish.

## Acceptance criteria

- [x] `SampleTick` struct (all 10 fields)
- [x] `Sample` struct (length, loop, items[64])
- [x] `Ornament` struct (length, loop, items[255])
- [x] `ChannelLine` struct (note, sample, ornament, volume, envelope, command)
- [x] `AdditionalCommand` struct
- [x] `PatternRow` struct (noise, envelope, 3× channel)
- [x] `Pattern` struct (length, items[256])
- [x] `PositionList` struct
- [x] `ChannelState` struct (IsChans)
- [x] `Module` struct (title, author, ton_table, delay, positions, samples, ornaments, patterns)
- [x] `Module::default()` initialises `global_ton/noise/envelope = true` (matches Pascal `VTMP` init, trfuncs.pas:8555–8557)
- [x] `AyRegisters` snapshot struct
- [x] `serde` derive on all types (`serde-big-array` for large fixed arrays)
- [x] `NOTE_NONE` / `NOTE_SOUND_OFF` sentinels
- [x] `FeaturesLevel` enum

## Notes

<!-- backlog-mcp: 2026-04-20T19:26:33Z -->
All data types ported from trfuncs.pas with full serde derivation and correct default values matching Pascal VTMP init.
