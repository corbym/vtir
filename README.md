# Vortex Tracker II — Rust Port

> **A music editor and player for the AY-3-8910 / YM2149F sound chips,**  
> originally used in the ZX Spectrum home computer.

🌐 **[Live web demo →](https://corbym.github.io/vtir/)**

---

## 🙏 Original Author

**Vortex Tracker II** was created by **Sergey V. Bulba** (c) 2000–2009.

> *Author: Sergey Bulba*  
> *E-mail: svbulba@gmail.com *  
> *Support page: http://bulba.untergrund.net/*

This Rust port exists only because of his extraordinary work. Sergey built
an entire chip emulator, 13 file-format parsers, a complete tracker editor
and the first cross-format ZX Spectrum music toolchain — all in 23,000 lines
of hand-written Delphi/Pascal. The original `readme.txt` and `readme.rus.txt`
are preserved in the `legacy/` directory of this repository. Sergey has a much more feature full player available on his site, namely [Ay_Emul](https://bulba.untergrund.net/emulator_e.htm). You should check it out.

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

These formats can be **opened and loaded** into the editor. They are all
one-way imports — the file is converted into the internal VTM representation
on load, but the original format cannot be written back out.

| # | Format | Extension | Implemented |
|---|--------|-----------|:-----------:|
| 1 | Pro Tracker 2.xx | `.pt2` | ☑ |
| 2 | Pro Tracker 1.xx | `.pt1` | ☑ |
| 3 | Flash Tracker | `.fls` | ☑ |
| 4 | Fast Tracker | `.ftc` | ☐ |
| 5 | Global Tracker 1.x | `.gtr` | ☑ |
| 6 | Pro Sound Creator 1.xx | `.psc` | ☐ |
| 7 | Pro Sound Maker (compiled) | `.psm` | ☐ |
| 8 | ASC Sound Master (compiled) | `.asc`, `.as0` | ☑ |
| 9 | Sound Tracker / Super Sonic (compiled) | `.stc` | ☑ |
| 10 | Sound Tracker Pro (compiled) | `.stp` | ☑ |
| 11 | SQ-Tracker (compiled) | `.sqt` | ☑ |
| 12 | Amadeus / Fuxoft AY Language | `.fxm`, `.ay` | ☑ `.ay` / ☐ `.fxm` |

## Supported Export Formats

These are the only formats that can be **saved back to disk**. This matches
the design of the original Delphi/Pascal application, which only ever wrote
VTM and PT3 — all other formats were strictly read-only imports.

| Format | Extension | Implemented | Notes |
|--------|-----------|:-----------:|-------|
| Pro Tracker 3.xx | `.pt3` | ☑ | ZX Spectrum binary — playable on real hardware and emulators |
| Vortex Tracker Module (text) | `.vtm` | ☑ | Native format — full round-trip, no data loss |

> **Why only PT3 and VTM?**  
> The original Pascal source (`legacy/trfuncs.pas`) defines conversion
> functions only in the direction `X → VTM` (`PT22VTM`, `STC2VTM`, etc.) and
> `VTM → PT3` / `VTM → TextFile`.  There are no `VTM2PT2`, `VTM2STC`, or
> similar writers in the original code, and adding them is out of scope for
> this faithful port.

---

## Documentation

| Page | Description |
|------|-------------|
| [AY State Machine](docs/ay-state-machine.md) | How the AY-3-8910 / YM2149F chip emulator works — registers, tone generators, noise LFSR, envelope shapes, synthesizer, audio pipeline |
| [File Formats](docs/file-formats.md) | Binary layout and parsing notes for every supported tracker format |
| [Tracker Songs & Fixtures](docs/tracker-songs.md) | Catalogue of real-world tunes and test fixtures included in the repo |
| [Using the TAP export](docs/using-tap-export.md) | Step-by-step guide: how to load and play an exported `.tap` file in an emulator or on real ZX Spectrum hardware |

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
- ✅ Song timing helpers: `get_module_time`, `get_position_time`, `get_position_time_ex`, `get_time_params` (Pascal-baseline verified)
- ✅ Cross-platform audio output via `cpal`
- ✅ egui-based GUI skeleton (pattern view, sample view, ornament view, toolbar) with status bar showing current position + elapsed / total time
- ✅ Terminal CLI tracker diagnostics tool (`vti-cli`) — keyboard navigation + headless tick harness; header shows elapsed / total time
- ✅ Playback cursor follow — pattern editor highlights and scrolls to the playing row in real time
- ✅ File open (import): PT3, PT2, PT1, STC, STP, VTM text, AY (ZXAY ST11; EMUL partial — the original Pascal application had full EMUL playback via a built-in Z80 emulator; this Rust port has no Z80 emulator yet, so only EMUL files whose payload contains an embedded PT3/STP module with a recognisable header can be loaded — all other EMUL files will fail to import)
- ✅ File save (export): PT3 binary, VTM text — these are the only writable formats
- ✅ PT3 round-trip writer (parse → write → parse verified)
- ✅ ZX Spectrum export (`.tap`, `.scl`, `.ay`, Hobeta `.$ ` header)
- ✅ 181 tests across vti-core and vti-ay, 0 failing

### Still in progress
- Remaining 8 format parsers: ASC, SQT, GTR, FTC, FLS, PSC, PSM, FXM
- Full keyboard note-entry in the pattern editor
- Editable sample / ornament fields
- Position list editor
- Options dialog (sample rate, chip type, panning, buffer settings)
- Channel panning selector (Mono / ABC / ACB / …)
- Seek-to-time UI (scrub bar) — timing helpers are now ready to drive this
- GitHub Actions release pipeline (Mac `.dmg`, Windows `.exe`, Linux binary)

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

# Build CLI binary
cargo build --bin vti-cli

# Run CLI directly from build output (debug)
target/debug/vti-cli crates/vti-core/tests/fixtures/tunes/ADDAMS2.ay

# Run CLI via helper script (uses release/debug binary if present, else cargo run)
./scripts/vti-cli crates/vti-core/tests/fixtures/tunes/ADDAMS2.ay

# Start interactive mode with playback enabled immediately
./scripts/vti-cli crates/vti-core/tests/fixtures/tunes/ADDAMS2.ay --play=true

# Headless diagnostics (no real audio device needed)
./scripts/vti-cli crates/vti-core/tests/fixtures/tunes/ADDAMS2.ay --ticks 512
```

`vti-cli` starts with playback off by default. Use `--play`, `--play=true`, or `--play=false` to control startup playback. Keyboard controls: arrows move row/channel, `PageUp`/`PageDown` move positions, `Space` play/pause, `s` step one tick, `f` toggle follow-playhead, `Home`/`End` jump top/bottom, `q` quit.

### Running the tests

```sh
# Library and integration tests (no audio device required)
cargo test -p vti-core -p vti-ay -p vti-audio

# Device-dependent audio tests (requires a real output device)
cargo test -p vti-audio -- --ignored

# Focused device diagnostics around cpal start/callback/fill path
cargo test -p vti-audio audio_player_diagnostics_show_callback_activity -- --ignored

# Pascal parity / approval baseline tests
cargo test -p vti-core -p vti-ay --test pascal_baseline_tests
```

### Pascal parity baselines

The correctness of the playback engine is verified against the original Pascal
source by committed JSON fixtures in `crates/*/tests/fixtures/pascal-baselines/`.

The fixtures were generated by compiling and running
`pascal-tests/vt_harness.pas` (FPC) against the exact Pascal algorithms in
`trfuncs.pas` and `AY.pas`. They represent the ground truth for:

| Fixture | What it captures |
|---------|-----------------|
| `noise_lfsr.json` | 200-step LFSR sequence (taps: bit13⊕16, `noise_val = bit16 of seed`) |
| `envelope_shapes.json` | All 8 AY envelope shapes, 64 amplitude steps each |
| `pt3_vol.json` | Complete 16×16 PT3 volume table |
| `note_tables.json` | All 5 note tables (PT, ST, ASM, REAL, NATURAL) |
| `pattern_play_basic.json` | AY register values across 20 ticks of a 4-row tone pattern |
| `pattern_play_envelope.json` | Same with AY envelope type 8 active |

**To regenerate the baselines** (run infrequently — after a deliberate Pascal change):

```sh
# Requires fpc: sudo apt-get install fp-compiler   (Linux)
#          or:  brew install fpc                    (macOS)
bash pascal-tests/run_harness.sh
```

Or trigger the `Regenerate Pascal Baselines` workflow manually in GitHub Actions.
A diff in a fixture that was not caused by an intentional Pascal source change
is a regression — investigate before merging.

### Running in the browser (WASM)

A live build is automatically deployed to **[https://corbym.github.io/vtir/](https://corbym.github.io/vtir/)** on every push to `main`.

To build and serve the web version locally, install [trunk](https://trunkrs.dev/) and the WASM target:

```sh
rustup target add wasm32-unknown-unknown
cargo install trunk

# Serve with hot-reload at http://localhost:8080
trunk serve

# Or produce a release build in dist/
trunk build --release
```

> **Note:** Audio uses the browser's Web Audio API via `cpal`'s webaudio backend.
> A short test tone is pre-loaded on row 0 of pattern 0 — click **▶ Play** to verify
> audio is working. You can then add your own notes in the pattern editor and play them back.

---

## Crate Layout

```
Cargo.toml                 ← workspace root + binary crate
src/
  main.rs                  ← eframe entry-point
  bin/vti-cli.rs           ← terminal CLI tracker + diagnostics harness
  app.rs                   ← top-level application state
scripts/
  vti-cli                  ← helper launcher for CLI from build output or cargo run
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
