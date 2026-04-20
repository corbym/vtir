# STORY-069: Pascal harness (pascal-tests/)

**Type:** chore

## Goal

Describe what this story should accomplish.

## Acceptance criteria

- [x] `vt_harness.pas` — FPC-compilable standalone program; no GUI/audio/Windows dependencies
- [x] `NoiseGenerator` in pure Pascal (bit13⊕16 taps, `noise_val = bit16 of seed`)
- [x] All 8 AY envelope shapes (`Case_EnvType_*`)
- [x] `Pattern_PlayOnlyCurrentLine` (full `GetRegisters` inner procedure)
- [x] `Pattern_PlayCurrentLine` (full `PatternInterpreter`, correct `exit` on pattern end)
- [x] Note tables and `PT3_Vol` constant outputs
- [x] `run_harness.sh` — compile + generate all fixtures; validate JSON with python3

## Notes

<!-- backlog-mcp: 2026-04-20T19:26:45Z -->
Pascal harness vt_harness.pas fully implemented covering all key functions; run_harness.sh compiles and validates fixtures.
