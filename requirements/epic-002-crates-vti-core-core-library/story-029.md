# STORY-029: PT2 format parser (formats/pt2.rs) — PT22VTM

**Type:** chore

## Goal

Describe what this story should accomplish.

## Acceptance criteria

- [x] Header decode (delay, loop pos, sample/ornament/pattern pointers, title)
- [x] Sample decode (3-byte tick: noise/ton flags, amplitude, add_to_ton with sign)
- [x] Ornament decode
- [x] Pattern decode (full opcode set: notes, sample, ornament, envelope, skip, effects)
- [x] Integration test + `minimal_roundtrip.pt2` fixture
- [x] PT2 → PT3 roundtrip test

## Notes

<!-- backlog-mcp: 2026-04-20T19:26:34Z -->
PT2 format parser fully ported with integration test, minimal_roundtrip.pt2 fixture, and PT2→PT3 roundtrip test.
