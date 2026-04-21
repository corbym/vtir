# STORY-043: Format auto-detection (formats/)

**Type:** chore

## Goal

Describe what this story should accomplish.

## Acceptance criteria

- [x] `load()` — detect file type from extension, dispatch to correct parser (vtm, pt3, pt2, pt1, stc, stp, sqt, asc, as0, gtr, fls)
- [ ] `LoadAndDetect()` — ZX Spectrum binary magic-number detection
- [ ] `PrepareZXModule()` — ZX Spectrum memory layout handling

## Notes

<!-- backlog-mcp: 2026-04-20T21:33:11Z -->
PR #49: feat: ZX Spectrum pointer rebasing, magic-byte format detection, load_and_detect
