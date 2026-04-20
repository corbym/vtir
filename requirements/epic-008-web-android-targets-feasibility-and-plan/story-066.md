# STORY-066: Web Target — Option A: eframe WASM

**Type:** feature

## Goal

Describe what this story should accomplish.

## Acceptance criteria

- [x] Add `trunk` to the build toolchain (config in `Trunk.toml`)
- [x] Add `index.html` template (canvas mount point)
- [x] Gate `rfd` (file dialog) behind `not(target_arch = "wasm32")` and provide a browser File System Access API fallback (`showOpenFilePicker` / `showSaveFilePicker`) via `wasm-bindgen` in `src/wasm_file.rs`; pending-result channel extracted to `src/pending_file.rs` with 10 native unit tests
- [x] Enable `cpal`'s `wasm-bindgen` feature so the WebAudio backend is compiled in for WASM targets; lazy-init `AudioPlayer` on first Play press to satisfy browser autoplay policy (AudioContext must be created inside a user-gesture handler)
- [x] Add `wasm32-unknown-unknown` target to CI build matrix
- [x] Publish the WASM build to GitHub Pages on every release tag

## Notes

<!-- backlog-mcp: 2026-04-20T19:26:44Z -->
eframe WASM target fully implemented with trunk, File System Access API fallback, lazy AudioPlayer init, CI integration, and GitHub Pages deploy.
