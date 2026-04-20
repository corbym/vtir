# STORY-023: Cargo workspace and crate layout

**Type:** chore

## Goal

Describe what this story should accomplish.

## Acceptance criteria

- [x] Create Cargo workspace (`Cargo.toml`)
- [x] Define workspace-level shared dependencies (serde, anyhow, log, egui, cpal…)
- [x] `crates/vti-core` — data types + playback engine
- [x] `crates/vti-ay` — AY/YM chip emulator
- [x] `crates/vti-audio` — cross-platform audio (cpal)
- [x] Root binary crate — egui application
- [x] Compile cleanly with `cargo check`

## Notes

<!-- backlog-mcp: 2026-04-20T19:26:33Z -->
Cargo workspace created with all four crates (vti-core, vti-ay, vti-audio, root binary) and verified compiling cleanly.
