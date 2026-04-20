# STORY-051: Application state (app.rs)

**Type:** feature

## Goal

Describe what this story should accomplish.

## Acceptance criteria

- [x] `VortexTrackerApp` struct (modules, active_module, panels, play state)
- [x] `PlayMode` enum (Module / Pattern / Line)
- [x] `BottomPanel` enum (Sample / Ornament)
- [x] `eframe::App::update` skeleton with menu bar / toolbar / status / panels
- [x] `make_demo_module()` — 3-channel arpeggio (I–V–vi–IV) + noise drum, loops forever
- [x] `File → Open` — rfd file dialog (native) / File System Access API (WASM) → format detection → Module load
- [x] `File → Save as VTM…` — rfd save dialog (native) / File System Access API (WASM) → VTM text output
- [x] `File → Save as PT3…` — rfd save dialog (native) / File System Access API (WASM) → PT3 binary output
- [x] `File → Export ZX` — PT3 to .tap / .ay / .scl / Hobeta (`zx_export.rs`, ported from `ExportZX.pas`); all five output formats; ZX player binaries embedded from assets
- [x] Turbo Sound second-chip slot management — GUI `Turbo Sound` menu can load/replace chip 2, disable chip 2, and switch the active editor between chip 1 / chip 2; WASM picker path carries the target slot through `pending_file::OpenTarget`; CLI parity via `1` / `2` and `--active-chip 1|2`
- [ ] `File → Open` / `File → Save` — show load/save errors and parse failures in an egui modal error dialog (currently only reported in the status bar)
- [ ] Module properties dialog (title, author, delay, tone table)
- [ ] About dialog (credits to S.V.Bulba)
