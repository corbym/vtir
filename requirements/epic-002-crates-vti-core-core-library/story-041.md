# STORY-041: AY (ZXAY container) parser (formats/ay.rs) — ST11 / AMAD / EMUL variants

**Type:** chore

## Goal

Describe what this story should accomplish.

## Acceptance criteria

- [x] Parse ZXAY header — magic, TypeID, author, song list
- [x] `list_songs()` — enumerate sub-songs with name and supported flag
- [x] ST1→STC conversion (`st1_to_stc`) — translate raw Sound Tracker 1 binary to STC data
- [x] `parse()` — load first sub-song as a `Module` via ST1→STC path
- [x] Multi-song support (NumSongs field)
- [x] AMAD: Detected and reported as unsupported with a clear error
- [x] EMUL PT3 / STP magic-byte search — if an embedded PT3 or STP module is found inside the EMUL payload it is extracted and returned
- [x] EMUL Return clear "requires Z80 emulation" error when no magic-byte module is found; never return a false-positive junk module decoded from Z80 opcode bytes
- [ ] EMUL Z80 playback (rustzx-z80) — post-port future feature
