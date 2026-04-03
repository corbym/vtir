# Vortex Tracker II — Rust Conversion Plan & TODO

## Legend
- [x] Done and tested
- [~] Started / partial
- [ ] Not yet started

---

## 1. Project Setup

- [x] Create Cargo workspace (`Cargo.toml`)
- [x] Define workspace-level shared dependencies (serde, anyhow, log, egui, cpal…)
- [x] Create crate layout:
  - [x] `crates/vti-core` — data types + playback engine
  - [x] `crates/vti-ay` — AY/YM chip emulator
  - [x] `crates/vti-audio` — cross-platform audio (cpal)
  - [x] Root binary crate — egui application
- [x] Compile cleanly with `cargo check`

---

## 2. `crates/vti-core` — Core Library

### 2.1 Data Types (`types.rs`) — ported from `trfuncs.pas`
- [x] `SampleTick` struct (all 10 fields)
- [x] `Sample` struct (length, loop, items[64])
- [x] `Ornament` struct (length, loop, items[255])
- [x] `ChannelLine` struct (note, sample, ornament, volume, envelope, command)
- [x] `AdditionalCommand` struct
- [x] `PatternRow` struct (noise, envelope, 3× channel)
- [x] `Pattern` struct (length, items[256])
- [x] `PositionList` struct
- [x] `ChannelState` struct (IsChans)
- [x] `Module` struct (title, author, ton_table, delay, positions, samples, ornaments, patterns)
- [x] `Module::default()` initialises `global_ton/noise/envelope = true` (matches Pascal `VTMP` init, trfuncs.pas:8555–8557)
- [x] `AyRegisters` snapshot struct
- [x] `serde` derive on all types (`serde-big-array` for large fixed arrays)
- [x] `NOTE_NONE` / `NOTE_SOUND_OFF` sentinels
- [x] `FeaturesLevel` enum

### 2.2 Note Tables (`note_tables.rs`) — ported from `trfuncs.pas`
- [x] `PT3NoteTable_PT` (96 entries)
- [x] `PT3NoteTable_ST`
- [x] `PT3NoteTable_ASM`
- [x] `PT3NoteTable_REAL`
- [x] `PT3NoteTable_NATURAL`
- [x] `PT3_VOL` volume table [16][16]
- [x] `get_note_freq(table, note)` lookup
- [x] `get_note_by_envelope(table, env_period)` reverse lookup

### 2.3 Playback Engine (`playback.rs`) — ported from `trfuncs.pas`
- [x] `ChanParams` struct (all slide/position fields)
- [x] `PlayVars` struct (position, pattern, line, delay, env state)
- [x] `PlayResult` enum (Updated / PatternEnd / ModuleLoop)
- [x] `init_tracker_parameters()`
- [x] `Engine::pattern_play_only_current_line()` — render registers without advancing
- [x] `Engine::pattern_play_current_line()` — interpret row, advance line
- [x] `Engine::module_play_current_line()` — advance position list
- [x] `Engine::pattern_interpreter()` — note/sample/ornament/effect decode
- [x] `Engine::get_channel_registers()` — sample/ornament/tone/amp computation
- [x] All effect commands (1–11): glide up, glide down, tone-slide, sample pos, orn pos, on/off, env slide up/down, delay
- [ ] `GetModuleTime()` — total song duration in ticks
- [ ] `GetPositionTime()` / `GetPositionTimeEx()` — per-position timing
- [ ] `GetTimeParams()` — seek to time position

### 2.4 Utility Functions (`util.rs`)
- [x] `note_to_str()` — note index → "C-4" display string (inline)
- [x] `samp_to_str()` — sample index → "1F" (inline)
- [x] `int2_to_str()`, `int1d_to_str()`, `int4d_to_str()`, `int2d_to_str()` (inline)
- [x] `ints_to_time()` — ticks → "MM:SS" (inline)
- [ ] `get_pattern_line_string()` — format a full pattern row as text
- [ ] `get_sample_string()` — format one sample tick as text

### 2.5 Format Parsers & Writers (`formats/`)

#### 2.5.1 PT3 (`formats/pt3.rs`) — `PT32VTM` / `VTM2PT3`
- [~] `parse()` — header, sample pointers, ornament pointers, position list ✓
- [~] `parse_sample()` — 3-byte tick encoding ✓ (needs real bit-field verification)
- [~] `parse_ornament()` ✓
- [ ] `decode_channel()` — **full PT3 channel bytecode decoder** (length prefixes,
      note encoding, envelope/noise inline values, repeat counts)
- [ ] `write()` — encode Module back to PT3 binary

#### 2.5.2 PT2 (`formats/pt2.rs`) — `PT22VTM`
- [ ] Header decode
- [ ] Sample / ornament decode
- [ ] Pattern decode

#### 2.5.3 PT1 (`formats/pt1.rs`) — `PT12VTM`
- [ ] Full parser

#### 2.5.4 STC (`formats/stc.rs`) — `STC2VTM`
- [ ] Full parser

#### 2.5.5 ASC / ASC0 (`formats/asc.rs`) — `ASC2VTM`
- [ ] Full parser

#### 2.5.6 STP (`formats/stp.rs`) — `STP2VTM`
- [ ] Full parser

#### 2.5.7 SQT (`formats/sqt.rs`) — `SQT2VTM`
- [ ] Full parser

#### 2.5.8 GTR (`formats/gtr.rs`) — `GTR2VTM`
- [ ] Full parser

#### 2.5.9 FTC (`formats/ftc.rs`) — `FTC2VTM`
- [ ] Full parser

#### 2.5.10 FLS (`formats/fls.rs`) — `FLS2VTM`
- [ ] Full parser

#### 2.5.11 PSC (`formats/psc.rs`) — `PSC2VTM`
- [ ] Full parser

#### 2.5.12 PSM (`formats/psm.rs`) — `PSM2VTM`
- [ ] Full parser

#### 2.5.13 FXM (`formats/fxm.rs`) — `FXM2VTM`
- [ ] Full parser

#### 2.5.14 VTM text format
- [ ] `VTM2TextFile()` — save as text
- [ ] `LoadModuleFromText()` — parse text format

#### 2.5.15 Format auto-detection
- [ ] `LoadAndDetect()` — detect file type and dispatch to correct parser
- [ ] `PrepareZXModule()` — ZX Spectrum memory layout handling

### 2.6 Tests (`tests/integration_tests.rs`)
- [x] Note table size and value checks
- [x] `get_note_freq` clamping and fallback
- [x] All `util` formatting functions
- [x] `Module` / `Sample` / `Ornament` / `Pattern` / `ChannelLine` default values
- [x] `init_tracker_parameters` reset behaviour
- [x] `pattern_play_current_line` → `Updated` on first tick
- [x] Line advancement after delay cycles
- [x] Pattern-end detection
- [x] Module loop detection
- [x] Sound-off note disables channel
- [x] Arpeggio ornament produces 3 distinct tone periods per row
- [x] Noise drum sample produces non-zero amplitude on channel C with noise enabled in mixer
- [x] Noise drum decays to silence after 8 ticks (loop on silent tick)
- [x] Arpeggio module loops after full 16-row pattern
- [x] Channels A and B both active (non-zero amplitude, tone enabled) after first row
- [ ] Glide-up / glide-down effect commands
- [ ] Tone-slide (command 3) target arrival
- [ ] On/off toggle (command 6)
- [ ] Envelope-slide (commands 9 and 10)
- [ ] Sample position jump (command 4)
- [ ] Ornament position jump (command 5)
- [ ] PT3 binary round-trip (parse → write → parse)

---

## 3. `crates/vti-ay` — AY/YM Chip Emulator

### 3.1 Chip state (`chip.rs`) — ported from `AY.pas`
- [x] `ChipType` enum (None / AY / YM)
- [x] `EnvShape` enum (8 shapes)
- [x] `EnvShape::from_register()` mapping
- [x] `SoundChip` struct (all counter / flag fields)
- [x] `SoundChip::reset()`
- [x] `set_mixer_register()` — derive `ton_en_*` / `noise_en_*` flags
- [x] `set_envelope_register()` — set shape + initial amplitude
- [x] `set_ampl_a/b/c()` — set amplitude + envelope-mode flag
- [x] `step_envelope()` — all 8 envelope shape handlers
- [x] `noise_generator()` — 17-bit LFSR
- [x] `synthesizer_logic_q()` — tone/noise/envelope counters (quality mode)
- [x] `synthesizer_mixer_q()` — stereo level accumulation
- [ ] `synthesizer_logic_p()` — fractional-tick "performance" mode
- [ ] `synthesizer_mixer_q_mono()` — mono mixing path
- [ ] `apply_filter()` integration for "performance" path

### 3.2 Configuration (`config.rs`)
- [x] `AyConfig` struct with all timing constants
- [x] `ay_tiks_in_interrupt()`, `sample_tiks_in_interrupt()`, `delay_in_tiks()`, `buffer_length()`
- [x] Default constructor matching original `SetDefault` values

### 3.3 Synthesizer (`synth.rs`) — ported from `AY.pas`
- [x] `LevelTables` struct
- [x] `calculate_level_tables()` — AY and YM amplitude → PCM level tables
- [x] `Synthesizer` struct (chips array, ring buffer, FIR state)
- [x] `Synthesizer::new()` — initialise with chip type
- [x] `Synthesizer::apply_registers()` — push AY register snapshot to chip
- [x] `Synthesizer::render_frame()` — produce N stereo-16 PCM samples
- [x] `Synthesizer::drain()` — pull samples from output buffer
- [x] FIR low-pass filter (windowed-sinc, Hanning window)
- [x] `calculate_level_tables()` global-volume scaling (`k = exp(vol*ln2/max) - 1`)
- [ ] `SetStdChannelsAllocation()` — channel panning presets (Mono/ABC/ACB/BAC…)
- [ ] `ToggleChanMode()` — cycle panning preset
- [ ] `SetIntFreq()` / `SetSampleRate()` — dynamic rate change
- [ ] Turbo Sound (2-chip) render path

### 3.4 Tests (`tests/integration_tests.rs`)
- [x] `noise_generator` — LFSR changes, 17-bit constraint, diversity
- [x] `EnvShape::from_register` mapping
- [x] All 8 `step_envelope` shapes (Hold0, Hold31, Saw8, Triangle10, DecayHold, Saw12, AttackHold, Triangle14)
- [x] `set_mixer_register` bit mapping
- [x] `set_ampl_a` envelope flag
- [x] `chip.reset()` clears state
- [x] `synthesizer_logic_q` tone A toggles with period=1
- [x] Level tables for None/AY/YM chip types
- [x] Level table monotonicity for AY
- [x] Synthesizer renders correct sample count
- [x] Synthesizer drain respects max
- [x] Silent chip produces zero output
- [x] Active tone produces non-zero output
- [x] Two chips produce ≥ signal of one chip
- [ ] Envelope shapes produce correct waveforms end-to-end
- [ ] `SetStdChannelsAllocation` panning preset values

---

## 4. `crates/vti-audio` — Cross-Platform Audio

### 4.1 Player (`player.rs`) — replaces `WaveOutAPI.pas`
- [x] `PlayerCommand` enum (Play / Pause / Stop)
- [x] `RingBuf` — lock-based ring buffer (push / pop)
- [x] `AudioPlayer::start()` — open cpal stereo-i16 output stream
- [x] `AudioPlayer::push_samples()` — feed rendered samples into ring
- [x] `AudioPlayer::fill_level()` — approximate fill ratio
- [ ] Render thread — background thread calling `Synthesizer::render_frame` each interrupt period and pushing into the ring buffer
- [ ] `PlayerCommand` channel integration — Play/Pause/Stop from UI thread
- [ ] `IsPlaying` / `Real_End` signalling back to UI
- [ ] Export to WAV file (replacing the existing export path)

### 4.2 Tests (`tests/integration_tests.rs`)
- [x] `PlayerCommand` variant distinctness and Copy
- [x] `StereoSample` default silence and Copy
- [x] `AudioPlayer::start` + push (device-dependent, `#[ignore]`)
- [x] Fill level decreases over time (device-dependent, `#[ignore]`)

---

## 5. Application (`src/`) — egui GUI

### 5.1 Application state (`app.rs`)
- [x] `VortexTrackerApp` struct (modules, active_module, panels, play state)
- [x] `PlayMode` enum (Module / Pattern / Line)
- [x] `BottomPanel` enum (Sample / Ornament)
- [x] `eframe::App::update` skeleton with menu bar / toolbar / status / panels
- [x] `make_demo_module()` — 3-channel arpeggio (I–V–vi–IV) + noise drum, loops forever
- [x] `File → Open` — rfd file dialog (native) / File System Access API (WASM) → format detection → Module load
- [x] `File → Save` — rfd save dialog (native) / File System Access API (WASM) → VTM text output
- [ ] `File → Open` / `File → Save` — show load/save errors and parse failures in an egui modal error dialog (currently only reported in the status bar)
- [ ] `File → Export ZX` — PT3 to .tap/.tzx (ported from `ExportZX.pas`)
- [ ] Turbo Sound second-chip slot management
- [ ] Module properties dialog (title, author, delay, tone table)
- [ ] About dialog (credits to S.V.Bulba)

### 5.2 Toolbar (`ui/toolbar.rs`)
- [x] Play / Pause / Stop buttons
- [x] Play-mode selector
- [ ] Channel panning selector (Mono / ABC / ACB / …)
- [ ] Loop toggle
- [ ] BPM / interrupt frequency display

### 5.3 Pattern Editor (`ui/pattern_editor.rs`)
- [x] Grid display — row numbers, 3 channels, note / sample / ornament / volume / env / effect columns
- [x] Cursor (row + channel + field)
- [x] Arrow-key navigation
- [x] Pattern selector (drag value)
- [x] Colour-coded cells (note off = red, empty = dark grey)
- [x] Playback cursor follow — highlighted playing row (cyan-green), auto-scrolls to keep it centred, auto-switches to the playing pattern (`RedrawPlWindow` equivalent)
- [ ] Full keyboard note entry (piano key mapping, with octave)
- [ ] Hex digit entry for sample/ornament/volume/effect fields
- [ ] Insert / delete row
- [ ] Copy / paste row or block
- [ ] Transpose selection (semitone / octave)
- [ ] Pattern length editor
- [ ] Loop-back indicator on position-list loop row

### 5.4 Sample Editor (`ui/sample_editor.rs`)
- [x] Read-only grid display of all tick fields
- [ ] Editable tick fields (DragValue per column)
- [ ] Sample length / loop editor
- [ ] Waveform preview (tone pitch visualisation)
- [ ] Copy / paste ticks

### 5.5 Ornament Editor (`ui/ornament_editor.rs`)
- [x] Read-only horizontal display of step offsets
- [ ] Editable steps
- [ ] Length / loop editor
- [ ] Visual keyboard indicator showing semitone offsets

### 5.6 Position List Editor (TODO — new file `ui/position_list.rs`)
- [ ] Drag-and-drop reorder
- [ ] Insert / delete position
- [ ] Loop marker

### 5.7 Options Dialog (TODO — new file `ui/options.rs` — ported from `options.pas`)
- [ ] Sample rate selector
- [ ] Bit depth (8/16)
- [ ] Stereo / mono
- [ ] AY frequency
- [ ] Interrupt frequency
- [ ] Buffer count / size
- [ ] Channel panning (custom indices)
- [ ] Chip type (AY / YM)
- [ ] FIR filter on/off

---

## 6. Build Pipeline (`.github/workflows/`)

- [x] `build.yml` — tests + WASM check on all branches/PRs
- [x] `pages.yml` — web deploy to GitHub Pages on push to master or manually
- [x] `pascal-baselines.yml` — **manual-only** (`workflow_dispatch`): install `fpc`,
      run `pascal-tests/run_harness.sh`, open a PR with updated fixture files if changed.
      Run this when adding new Pascal test cases or investigating parity regressions.
- [ ] `release.yml` — triggered on `v*` tags:
  - [ ] macOS job: `cargo build --release`, create `.app` bundle, package as `.dmg` (using `create-dmg`)
  - [ ] Windows job: `cargo build --release --target x86_64-pc-windows-msvc`, upload `.exe` as artifact
  - [ ] Linux job: `cargo build --release`, upload binary as artifact
  - [ ] Create GitHub Release with all three artifacts

---

## 7. Documentation

- [ ] Update `README.md`:
  - [ ] Project description (AY/YM music tracker for ZX Spectrum)
  - [ ] Original author attribution and thanks (S.V.Bulba)
  - [ ] Supported file formats
  - [ ] Build instructions (Rust, ALSA headers on Linux)
  - [ ] Running the tests
  - [ ] Screenshots / demo

---

## 8. Web & Android Targets — Feasibility and Plan

### 8.0 Feasibility Summary

| Target | Feasibility | Complexity | Notes |
|--------|-------------|------------|-------|
| Web (eframe/WASM) | ✅ High | Low–Medium | eframe has first-class WASM support via `trunk`; almost free |
| Web (KMP/Compose for Web) | 🟡 Medium | High | Kotlin/Wasm is still maturing; Rust→WASM→Kotlin interop is indirect |
| Android (Rust + KMP/Compose) | ✅ High | Medium–High | Well-proven path (Firefox, 1Password, Signal); `uniffi` automates JNI |
| iOS (Rust + KMP/Swift) | 🟡 Medium | High | `uniffi` generates Swift bindings; KMP iOS support exists but is beta |

**Short answer:** The core Rust libraries (`vti-core`, `vti-ay`) have **zero OS or native dependencies** — they will compile to WASM and Android targets unchanged. `vti-audio` uses `cpal`, which has experimental WASM and production-quality Android backends already. The main work is the FFI glue layer and the KMP UI code.

---

### 8.1 Dependency Portability Audit

| Crate | WASM | Android | Blocker? |
|-------|------|---------|---------|
| `vti-core` | ✅ | ✅ | None — pure Rust, `serde`/`anyhow`/`log` all WASM-safe |
| `vti-ay` | ✅ | ✅ | None — pure computation |
| `vti-audio` | ⚠️ | ✅ | `cpal` WASM backend is experimental (uses Web Audio API via `web-sys`); threading model needs care |
| `eframe`/`egui` | ✅ | ❌ | `eframe` supports WASM but not Android; a KMP UI replaces it on mobile |

---

### 8.2 New Crate: `crates/vti-ffi`

A thin FFI / binding layer that wraps the core playback API and is the only crate that needs to know about the host environment.

- [ ] Add `crates/vti-ffi` to the workspace
- [ ] Add `uniffi` as a build dependency (generates Kotlin & Swift bindings from a `.udl` interface file)
- [ ] Define a `vti.udl` interface covering:
  - `load_module(bytes: sequence<u8>) -> Module` — parse a PT3/VTM file
  - `Engine::new(module: Module) -> Engine`
  - `Engine::tick() -> AyRegisters` — advance one frame, return register snapshot
  - `Engine::reset()`
  - `module_title(module: Module) -> string`
  - `module_author(module: Module) -> string`
  - `module_position_count(module: Module) -> u32`
- [ ] Add `wasm-bindgen` feature flag for WASM target (exports the same API as JS-callable functions instead of JNI)
- [ ] Unit-test the FFI surface with the existing PT3 fixtures

---

### 8.3 Web Target

#### 8.3.1 Option A — eframe WASM (recommended first step, no KMP)

eframe already compiles to WASM via [`trunk`](https://trunkrs.dev/). This gives a working web UI with near-zero extra code.

- [x] Add `trunk` to the build toolchain (config in `Trunk.toml`)
- [x] Add `index.html` template (canvas mount point)
- [x] Gate `rfd` (file dialog) behind `not(target_arch = "wasm32")` and provide a browser File System Access API fallback (`showOpenFilePicker` / `showSaveFilePicker`) via `wasm-bindgen` in `src/wasm_file.rs`; pending-result channel extracted to `src/pending_file.rs` with 10 native unit tests
- [x] Enable `cpal`'s `wasm-bindgen` feature so the WebAudio backend is compiled in for WASM targets; lazy-init `AudioPlayer` on first Play press to satisfy browser autoplay policy (AudioContext must be created inside a user-gesture handler)
- [x] Add `wasm32-unknown-unknown` target to CI build matrix
- [x] Publish the WASM build to GitHub Pages on every release tag

#### 8.3.2 Option B — KMP / Compose for Web (longer term)

For a shared Kotlin UI across Android and web:

- [ ] Compile `vti-core` + `vti-ay` to WASM via `wasm-bindgen` in `vti-ffi`
- [ ] Write a Kotlin/Wasm wrapper (`vti-ffi-wasm`) that imports the WASM module via `@JsModule` and exposes a `VtiEngine` Kotlin class
- [ ] Write a Compose Multiplatform (Wasm target) UI in `apps/web-kmp/`
- [ ] Wire audio output through Kotlin's `kotlinx.coroutines` + a JS `AudioContext` interop helper
- [ ] Note: Kotlin/Wasm is production-ready as of Kotlin 2.0; Compose for Web (Wasm) is stable for simple UIs but lacks some layout widgets

---

### 8.4 Android Target

#### 8.4.1 Rust shared libraries

- [ ] Add Android NDK targets to the workspace:
  ```
  aarch64-linux-android
  armv7-linux-androideabi
  x86_64-linux-android
  i686-linux-android
  ```
- [ ] Install `cargo-ndk` (builds all targets and copies `.so` files into the correct `jniLibs/` tree)
- [ ] Enable `cpal`'s `asio` feature flag off, ensure AAudio backend compiles (cpal ≥ 0.15 supports AAudio on Android API 26+)
- [ ] Verify `vti-ffi` builds as a `cdylib` for Android targets

#### 8.4.2 UniFFI bindings

- [ ] Run `uniffi-bindgen generate vti.udl --language kotlin` to produce `VtiCore.kt` and a JNI loader
- [ ] Add the generated Kotlin sources to the Android module's source set
- [ ] Keep the generated files out of version control; regenerate in the Gradle build via a `generateUniFFIBindings` task

#### 8.4.3 KMP / Compose Multiplatform UI (`apps/android-kmp/`)

- [ ] Scaffold a new Compose Multiplatform project targeting Android (and optionally Desktop to share with the existing egui app during transition)
- [ ] Implement screens mirroring the egui panels:
  - [ ] `PatternEditorScreen` — pattern grid, note/sample/ornament/volume columns
  - [ ] `SampleEditorScreen`
  - [ ] `OrnamentEditorScreen`
  - [ ] `PositionListScreen`
  - [ ] `OptionsScreen`
- [ ] Implement a `VtiViewModel` (using `ViewModel` + `StateFlow`) that calls `vti-ffi` and drives the synthesizer render loop on a `Dispatchers.Default` coroutine
- [ ] Wire audio output: use Android's `AudioTrack` (or `cpal` on the Rust side) streaming 16-bit stereo PCM from the render loop
- [ ] File open: Android `Intent.ACTION_OPEN_DOCUMENT` → pass bytes to `vti_ffi::load_module()`

#### 8.4.4 Build & packaging

- [ ] `release.yml` Android job: `cargo ndk -t arm64-v8a -t armeabi-v7a build --release` → `./gradlew assembleRelease`
- [ ] Upload unsigned `.apk` as a release artifact
- [ ] (Optional) Sign with a release keystore stored as a GitHub Actions secret

---

### 8.5 Shared Architecture Diagram

```
┌──────────────────────────────────────────────────────────────┐
│                       UI Layer                               │
│  ┌─────────────┐  ┌──────────────────┐  ┌────────────────┐  │
│  │ egui/eframe │  │ Compose Android  │  │ eframe WASM /  │  │
│  │  (desktop)  │  │      (KMP)       │  │ Compose Web    │  │
│  └──────┬──────┘  └────────┬─────────┘  └───────┬────────┘  │
│         │                  │  JNI/UniFFI          │ wasm-bind │
│  ───────┴──────────────────┴──────────────────────┴───────── │
│                     vti-ffi  (cdylib / wasm)                 │
│  ───────────────────────────────────────────────────────────  │
│           vti-core    │    vti-ay    │    vti-audio           │
│        (pure Rust)    │ (pure Rust)  │  (cpal — OS audio)     │
└──────────────────────────────────────────────────────────────┘
```

---

### 8.6 Key Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| `cpal` WASM audio is experimental | Option A web: drive audio from a JS `AudioWorkletNode`; call `Engine::tick()` from the worklet each frame |
| Rust WASM single-thread limits | Audio processing is lightweight per-frame; avoid spawning threads in WASM; use `wasm-bindgen-futures` for async |
| KMP Kotlin/Wasm interop with Rust WASM is immature | Prototype with `wasm-bindgen` + plain TypeScript first; wrap in KMP expect/actual later |
| Android binary size (4 `.so` files × 4 ABIs) | Use `strip` in release profile; consider shipping only `arm64-v8a` for initial release |
| UniFFI UDL maintenance overhead | Keep the UDL surface minimal (load / tick / reset); complex types stay on the Rust side |

---

## 9. Pascal Parity Testing

The only ground truth for correct behaviour is the original Delphi/Pascal source
(`trfuncs.pas`, `AY.pas`). The parity testing infrastructure captures that ground
truth as committed JSON fixtures and asserts that the Rust code matches them.

### 9.1 Harness (`pascal-tests/`)

- [x] `vt_harness.pas` — FPC-compilable standalone program; no GUI/audio/Windows
  dependencies. Implements:
  - [x] `NoiseGenerator` in pure Pascal (bit13⊕16 taps, `noise_val = bit16 of seed`)
  - [x] All 8 AY envelope shapes (`Case_EnvType_*`)
  - [x] `Pattern_PlayOnlyCurrentLine` (full `GetRegisters` inner procedure)
  - [x] `Pattern_PlayCurrentLine` (full `PatternInterpreter`, correct `exit` on pattern end)
  - [x] Note tables and `PT3_Vol` constant outputs
- [x] `run_harness.sh` — compile + generate all fixtures; validate JSON with python3

### 9.2 Fixture files (committed, never auto-generated in CI)

| File | Crate | What it verifies |
|------|-------|-----------------|
| `crates/vti-ay/tests/fixtures/pascal-baselines/noise_lfsr.json` | `vti-ay` | 200-step LFSR sequence, seed + noise_val |
| `crates/vti-ay/tests/fixtures/pascal-baselines/envelope_shapes.json` | `vti-ay` | All 8 envelope shapes, 64 steps each |
| `crates/vti-core/tests/fixtures/pascal-baselines/pt3_vol.json` | `vti-core` | 16×16 PT3_Vol table |
| `crates/vti-core/tests/fixtures/pascal-baselines/note_tables.json` | `vti-core` | All 5 note tables, 96 entries each |
| `crates/vti-core/tests/fixtures/pascal-baselines/pattern_play_basic.json` | `vti-core` | 20 ticks of pure-tone 4-row pattern |
| `crates/vti-core/tests/fixtures/pascal-baselines/pattern_play_envelope.json` | `vti-core` | Same pattern + AY envelope type 8 |
| `crates/vti-core/tests/fixtures/pascal-baselines/pattern_play_arpeggio.json` | `vti-core` | 54 ticks: 3-ch arpeggio + noise drum (ornament stepping, noise mixer path) |

### 9.3 Rust tests (`tests/pascal_baseline_tests.rs` in each crate)

- [x] `vti-ay::noise_lfsr_matches_pascal_baseline` — **currently FAILING** (exposes wrong LFSR taps: Rust bit16⊕19 vs Pascal bit13⊕16, and wrong `noise_val` extraction)
- [x] `vti-ay::envelope_shapes_match_pascal_baseline` — passing
- [x] `vti-ay::envelope_shape_from_register_matches_baseline` — passing
- [x] `vti-core::pt3_vol_matches_pascal_baseline` — passing
- [x] `vti-core::note_tables_match_pascal_baseline` — passing
- [x] `vti-core::pattern_play_basic_matches_pascal_baseline` — passing
- [x] `vti-core::pattern_play_envelope_matches_pascal_baseline` — **currently FAILING** (exposes missing `env_base` write from pattern row: Rust gives `envelope=0`, Pascal gives `2048`)
- [x] `vti-core::pattern_play_arpeggio_matches_pascal_baseline` — passing (covers ornament stepping and noise mixer path)

### 9.4 Known bugs exposed by baselines

| Bug | Test that fails | Rust behaviour | Pascal (correct) behaviour |
|-----|----------------|----------------|---------------------------|
| Wrong LFSR taps | `noise_lfsr_matches_pascal_baseline` | Uses bit16⊕19 | Uses bit13⊕16 |
| Wrong `noise_val` extraction | `noise_lfsr_matches_pascal_baseline` | `seed & 1` (bit0) | `(seed >> 16) & 1` (bit16, union layout) |
| `env_base` not written from pattern row | `pattern_play_envelope_matches_pascal_baseline` | `envelope = 0` | `envelope = pattern_row.envelope` |
| `PatternEnd` renders extra frame | (observable with non-stable registers) | Calls `PlayOnly` before return | Exits without calling `PlayOnly` |

### 9.5 Workflow for updating baselines (`pascal-baselines.yml`)

Run manually (`workflow_dispatch`) when:
- Adding new test scenarios to `vt_harness.pas`
- Confirming a Pascal behaviour after investigating a bug

The workflow installs `fpc`, runs `run_harness.sh`, and opens a PR if fixtures
changed. Fixture changes that are NOT caused by a deliberate Pascal source change
should be treated as regressions and investigated before merging.


---

## Summary

| Area | Done | Remaining |
|------|------|-----------|
| Project setup | ✅ complete | — |
| `vti-core` data types | ✅ complete | — |
| `vti-core` note tables | ✅ complete | — |
| `vti-core` playback engine | ~80% | timing helpers, some effect edge cases |
| `vti-core` util | ~70% | `get_pattern_line_string`, `get_sample_string` |
| **PT3 format parser** | ~40% | full channel bytecode decoder, writer |
| All other format parsers (12×) | 0% | ~3000 lines of Pascal to port |
| `vti-ay` chip emulator | ~85% | perf-mode paths, channel presets |
| `vti-ay` synthesizer | ~75% | channel allocation presets, Turbo Sound |
| `vti-audio` player | ~60% | render thread, command channel, WAV export |
| `vti-app` GUI skeleton | ~30% | all editing interaction, dialogs |
| Build pipeline | ~50% | GitHub Actions release workflow |
| README | 0% | full write-up |
| **Integration tests** | ✅ 59 passing | effect-command edge cases, PT3 round-trip |
| **Pascal parity baselines** | ✅ infrastructure done | Fix 4 known bugs (see §9.4) |
| **Web target (eframe WASM)** | ✅ ~95% | file-dialog fallback done via File System Access API |
| **Web target (KMP/Compose)** | 0% | `vti-ffi` WASM bindings, Kotlin/Wasm UI (long-term) |
| **Android target (KMP/Compose)** | 0% | `vti-ffi` cdylib, UniFFI bindings, Compose UI, `cargo-ndk` pipeline |
