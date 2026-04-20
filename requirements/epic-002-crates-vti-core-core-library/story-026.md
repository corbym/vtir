# STORY-026: Playback Engine (playback.rs) — ported from trfuncs.pas

**Type:** chore

## Goal

Describe what this story should accomplish.

## Acceptance criteria

- [x] `ChanParams` struct (all slide/position fields)
- [x] `PlayVars` struct (position, pattern, line, delay, env state)
- [x] `PlayResult` enum (Updated / PatternEnd / ModuleLoop)
- [x] `init_tracker_parameters()`
- [x] `Engine::pattern_play_only_current_line()` — render registers without advancing
- [x] `Engine::pattern_play_current_line()` — interpret row, advance line
- [x] `Engine::module_play_current_line()` — advance position list
- [x] `Engine::pattern_interpreter()` — note/sample/ornament/effect decode
- [x] `Engine::get_channel_registers()` — sample/ornament/tone/amp computation
- [x] All effect commands (1–11): glide up, glide down, tone-slide, sample pos, orn pos, on/off, env slide up/down, delay
- [x] `GetModuleTime()` — total song duration in ticks
- [x] `GetPositionTime()` / `GetPositionTimeEx()` — per-position timing
- [x] `GetTimeParams()` — seek to time position

## Notes

<!-- backlog-mcp: 2026-04-20T19:26:33Z -->
Full playback engine ported including all 11 effect commands, module/pattern/position advancement, and all timing helpers.
