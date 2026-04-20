# STORY-061: Release workflow (release.yml) — macOS / Windows / Linux artifacts

**Type:** chore

## Goal

Describe what this story should accomplish.

## Acceptance criteria

- [ ] `release.yml` triggered on `v*` tags
- [ ] macOS job: `cargo build --release`, create `.app` bundle, package as `.dmg` (using `create-dmg`)
- [ ] Windows job: `cargo build --release --target x86_64-pc-windows-msvc`, upload `.exe` as artifact
- [ ] Linux job: `cargo build --release`, upload binary as artifact
- [ ] Create GitHub Release with all three artifacts
