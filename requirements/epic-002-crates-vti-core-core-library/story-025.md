# STORY-025: Note Tables (note_tables.rs) — ported from trfuncs.pas

**Type:** chore

## Goal

Describe what this story should accomplish.

## Acceptance criteria

- [x] `PT3NoteTable_PT` (96 entries)
- [x] `PT3NoteTable_ST`
- [x] `PT3NoteTable_ASM`
- [x] `PT3NoteTable_REAL`
- [x] `PT3NoteTable_NATURAL`
- [x] `PT3_VOL` volume table [16][16]
- [x] `get_note_freq(table, note)` lookup
- [x] `get_note_by_envelope(table, env_period)` reverse lookup

## Notes

<!-- backlog-mcp: 2026-04-20T19:26:33Z -->
All five note tables, PT3_VOL volume table, and both lookup functions ported from trfuncs.pas.
