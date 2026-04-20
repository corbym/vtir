# STORY-031: STC format parser (formats/stc.rs) — STC2VTM

**Type:** chore

## Goal

Describe what this story should accomplish.

## Acceptance criteria

- [x] Full parser (fixed-offset 99-byte sample table, ornament table, position list with transposition)
- [x] Integration test + `minimal_roundtrip.stc` fixture
- [x] STC → PT3 roundtrip test

## Notes

<!-- backlog-mcp: 2026-04-20T19:26:35Z -->
STC format parser fully ported with integration test and STC→PT3 roundtrip test.
