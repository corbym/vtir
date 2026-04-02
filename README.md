# Vortex Tracker II — Rust Port

> **A music editor and player for the AY-3-8910 / YM2149F sound chips,**  
> originally used in the ZX Spectrum home computer.

---

## 🙏 Original Author

**Vortex Tracker II** was created by **Sergey V. Bulba** (c) 2000–2009.

> *Author: Sergey Bulba*  
> *E-mail: vorobey@mail.khstu.ru*  
> *Support page: http://bulba.untergrund.net/*

This Rust port exists only because of his extraordinary work. Sergey built
an entire chip emulator, 13 file-format parsers, a complete tracker editor
and the first cross-format ZX Spectrum music toolchain — all in 23,000 lines
of hand-written Delphi/Pascal. The original `readme.txt` and `readme.rus.txt`
are preserved in this repository.

---

## What is it?

Vortex Tracker II is a **music tracker** — a step-sequencer style editor —
for the **AY-3-8910**, **AY-3-8912** and **YM2149F** Programmable Sound
Generators (PSGs). These chips produced the characteristic "chip-tune" sound
on the ZX Spectrum, Amstrad CPC, MSX, and many other platforms of the 1980s
and 90s.

A *tracker* works by arranging notes, instruments (samples) and effects into
a **pattern grid**. Patterns are ordered into a **position list** to form a
complete song. The AY/YM chip has three independent square-wave tone channels
(A, B, C) plus a shared noise generator and hardware envelope.

**Vortex Tracker II saves and exports to the Pro Tracker 3 (`.pt3`) format**,
playable on real ZX Spectrum hardware and by many emulators.

---

## Supported Import Formats

| # | Format | Extension |
|---|--------|-----------|
| 1 | Pro Tracker 3.xx | `.pt3` |
| 2 | Pro Tracker 2.xx | `.pt2` |
| 3 | Pro Tracker 1.xx | `.pt1` |
| 4 | Flash Tracker | `.fls` |
| 5 | Fast Tracker | `.ftc` |
| 6 | Global Tracker 1.x | `.gtr` |
| 7 | Pro Sound Creator 1.xx | `.psc` |
| 8 | Pro Sound Maker (compiled) | `.psm` |
| 9 | ASC Sound Master (compiled) | `.asc` |
| 10 | Sound Tracker / Super Sonic (compiled) | `.stc` |
| 11 | Sound Tracker Pro (compiled) | `.stp` |
| 12 | SQ-Tracker (compiled) | `.sqt` |
| 13 | Amadeus / Fuxoft AY Language | `.fxm`, `.ay` |

---

## Project Status

This is an **active work-in-progress** conversion from the original Delphi/Pascal
source. See [`PLAN.md`](PLAN.md) for a detailed, checked-off task list.

### What works today
- ✅ All core data structures (Module, Pattern, Sample, Ornament, …)
- ✅ All five PT3 tone-frequency tables
- ✅ Full AY/YM chip emulator (all 8 envelope shapes, noise LFSR, mixer)
- ✅ Stereo-16 PCM synthesizer with FIR low-pass filter
- ✅ Tracker playback engine (note entry, all 11 effect commands, ornaments)
- ✅ Cross-platform audio output via `cpal`
- ✅ egui-based GUI skeleton (pattern view, sample view, ornament view, toolbar)
- ✅ 59 integration tests, 0 failing

### Still in progress
- PT3 binary channel decoder / writer
- All other 12 format parsers
- Full keyboard note-entry in the pattern editor
- Editable sample / ornament fields
- Position list editor
- Options dialog
- GitHub Actions release pipeline (Mac `.dmg`, Windows `.exe`)

---

## Building

### Prerequisites

| Platform | Required |
|----------|----------|
| All | [Rust toolchain ≥ 1.75](https://rustup.rs/) |
| Linux | `libasound2-dev` (ALSA headers), `pkg-config` |
| macOS | Xcode Command Line Tools |
| Windows | No extra dependencies |

```sh
# Linux
sudo apt install libasound2-dev pkg-config

# All platforms
cargo build --release
cargo run --release
```

### Running the tests

```sh
# Library and integration tests (no audio device required)
cargo test -p vti-core -p vti-ay -p vti-audio

# Device-dependent audio tests (requires a real output device)
cargo test -p vti-audio -- --ignored
```

---

## Crate Layout

```
Cargo.toml                 ← workspace root + binary crate
src/
  main.rs                  ← eframe entry-point
  app.rs                   ← top-level application state
  ui/                      ← egui panels
    pattern_editor.rs
    sample_editor.rs
    ornament_editor.rs
    toolbar.rs
crates/
  vti-core/                ← data types, playback engine, format parsers
  vti-ay/                  ← AY-3-8910 / YM2149F emulator
  vti-audio/               ← cross-platform audio (cpal)
```

---

## Acknowledgements

- **Sergey V. Bulba** — original Vortex Tracker II author; without his work
  none of this would exist.
- **Roman Scherbakov** — co-founder of the original Vortex Tracker project.
- **Hacker KAY** — AY/YM amplitude measurement tables used in the emulator.
- **Alone Coder (Dima Bystrov)** — author of Pro Tracker 3.6x/3.7x,
  the reference format this tool targets.
- The [cpal](https://github.com/RustAudio/cpal) and
  [egui](https://github.com/emilk/egui) communities for excellent
  cross-platform audio and GUI crates.
