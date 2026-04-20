# STORY-028: PT3 format parser + writer (formats/pt3.rs) — PT32VTM / VTM2PT3

**Type:** chore

## Goal

Describe what this story should accomplish.

## Acceptance criteria

- [x] `parse()` — header, sample pointers, ornament pointers, position list
- [x] `parse_sample()` — 4-byte tick encoding, all fields
- [x] `parse_ornament()`
- [x] `decode_channel()` — full PT3 channel bytecode decoder (PatternInterpreter: all opcodes $10-$FF, skip/repeat, envelope period, all 9 effect commands)
- [x] `write()` — encode Module back to PT3 binary (VTM2PT3 full port)

## Notes

<!-- backlog-mcp: 2026-04-20T19:26:33Z -->
PT3 parser and writer fully ported with full channel bytecode decoder and round-trip tested.
