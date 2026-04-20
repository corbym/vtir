# Plan — Vortex Tracker II Rust Port

Status: active

## Overview

Port Vortex Tracker II (VT2) — a ZX Spectrum chiptune tracker originally written in Delphi/Pascal by Sergey Bulba (2000–2009) — to Rust. The result is a cross-platform desktop and web application that is **behaviourally identical** to the original, with no intentional feature changes or algorithmic redesigns.

This is a **faithful conversion**, not a rewrite. Every observable behaviour — AY register values, envelope shapes, timing cadences, playback cursor position — must match the Pascal original exactly. The Pascal source files in `legacy/` are the authoritative specification.

## Goals

- Produce a fully working Rust port of VT2 that can load, edit, and play back PT3 and all other supported tracker formats.
- Achieve bit-identical AY register output to the original Pascal implementation, verified via committed Pascal baseline fixtures.
- Ship native desktop binaries (Linux, macOS, Windows) and a web build (eframe WASM / GitHub Pages).
- Lay the groundwork for future Android and KMP/Compose targets via a clean FFI crate (`vti-ffi`).
- Maintain a comprehensive test suite (unit + integration + Pascal parity baselines) so regressions are caught automatically.

## Principles

**Port faithfully, then refactor.** Translate Pascal statement-by-statement. Do not "improve" an algorithm during porting — confirm bit-identical output first, then clean up.

**Timing is critical.** The original tracker advances state per frame at the AY chip's interrupt rate (typically 50 Hz on ZX Spectrum hardware). Off-by-one errors in frame counters, delay counters, or sample/ornament ticks are audibly wrong.

**Pascal is ground truth.** If Rust behaviour diverges from Pascal behaviour in any observable way (register values, timing, envelope shape, noise pattern), treat Pascal as correct.

**Work in small vertical stripes.** Tackle one complete slice of functionality at a time — from data model through logic to test. Land minimal but correct implementations; avoid large half-finished batches.

**Keep the build green.** `cargo build` and `cargo test` must pass on every commit. CI runs on all branches; a red build blocks everything.

**Test-driven.** Write the failing test first. Integration tests from the highest useful level; unit tests only when they add clarity the integration test cannot provide.

**Pascal parity baselines are mandatory** for any function that produces computed output. The harness (`pascal-tests/vt_harness.pas`) generates committed JSON fixtures; the Rust tests assert bit-identical output.

## Architecture

The project is a Cargo workspace. Each concern lives in its own crate:

| Crate | Role |
|-------|------|
| `crates/vti-core` | Data types, playback engine, format parsers |
| `crates/vti-ay` | AY-3-8910 / YM2149F chip emulator (ported from `AY.pas`) |
| `crates/vti-audio` | Cross-platform audio output via `cpal` |
| Root binary (`src/`) | egui GUI application + CLI diagnostics tool (`src/bin/vti-cli.rs`) |

New behaviour belongs in the most appropriate crate. The GUI layer is last. `main.rs` and the UI files contain only genuine UI logic.

## Scope

### In scope
- All format parsers in the original VT2 (PT3, PT2, PT1, STC, STP, SQT, ASC/ASC0, GTR, FLS, FTC, PSC, PSM, FXM, AY/ZXAY, VTM text)
- Full PT3 read/write round-trip
- Complete AY/YM chip emulator with all envelope shapes, noise LFSR, mixer
- Stereo-16 PCM synthesizer with FIR low-pass filter
- Tracker playback engine with all 11 effect commands, ornaments, and song timing helpers
- egui GUI: pattern editor, sample editor, ornament editor, position list, toolbar, options dialog
- Web build via eframe WASM (deployed to GitHub Pages); file I/O via File System Access API
- CLI diagnostics binary (`vti-cli`) kept in parity with the GUI at all times
- TurboSound (dual-chip) support
- WAV export

### Out of scope (long-term / separate epics)
- Android target (KMP/Compose + UniFFI — feasibility done, implementation deferred)
- Web target Option B (KMP/Compose for Web — deferred)
- Full Z80 player emulation for EMUL-type AY containers (planned via `rustzx-z80`, deferred)

## Current State (as of April 2026)

| Area | Status |
|------|--------|
| Project setup | ✅ complete |
| `vti-core` data types + note tables | ✅ complete |
| Playback engine | ~90% — effect edge-case tests, seek integration remain |
| Utility functions | ~70% — `get_pattern_line_string`, `get_sample_string` remain |
| PT3 parser + writer | ✅ complete (round-trip tested) |
| PT2, PT1, STC, STP, SQT, ASC, GTR, FLS parsers | ✅ complete |
| AY (ZXAY) parser | ✅ complete — ST11 + EMUL embedded-module extraction |
| FTC, PSC, PSM, FXM parsers | 0% — ~2500 lines of Pascal to port |
| `vti-ay` chip emulator | ~85% — performance-mode paths, channel panning presets remain |
| `vti-ay` synthesizer | ~75% — channel allocation presets, Turbo Sound remain |
| `vti-audio` player | ~90% — WAV export remains |
| GUI application | ~40% — editing interaction, dialogs remain |
| Build pipeline | ~50% — release workflow (macOS/Windows/Linux artifacts) remains |
| Integration tests | ✅ 181 passing |
| Pascal parity baselines | ✅ all passing |
| Web target (eframe WASM) | ✅ ~95% — deployed to GitHub Pages |
| Web target (KMP/Compose) | 0% — long-term |
| Android target | 0% — long-term |
