# Agent Guidelines for Vortex Tracker II (Rust Port)

## Read This First

**Always read [`PLAN.md`](PLAN.md) before implementing anything.**  
It is the authoritative task list for this project. Understand what is already done, what is in progress, and what is next before writing a single line of code.

---

## Architecture

This is a Cargo workspace. Each concern lives in its own crate:

| Crate | Purpose |
|-------|---------|
| `crates/vti-core` | Data types, playback engine, format parsers |
| `crates/vti-ay` | AY-3-8910 / YM2149F chip emulator |
| `crates/vti-audio` | Cross-platform audio output (cpal) |
| Root binary (`src/`) | egui GUI application |

Keep this separation of concerns. New behaviour belongs in the most appropriate crate, not in `main.rs` or the GUI layer unless it is genuinely UI logic.

---

## Faithful Conversion from the Original Pascal/Delphi Source

This project is a **port**, not a rewrite. The goal is to replicate the behaviour of the original Delphi/Pascal code as closely as possible, not to redesign it.

- **Timing is critical.** The original tracker advances state on a per-frame basis tied to the AY chip's interrupt rate (typically 50 Hz on ZX Spectrum hardware). Any logic that counts frames, advances delay counters, or sequences sample/ornament ticks must replicate the original cadence exactly. Off-by-one errors in timing will cause audibly wrong playback.
- **Refer to the original source.** The Pascal files (`trfuncs.pas`, `AY.pas`, etc.) are preserved in the `legacy/` directory at the project root. When porting a routine, read the original implementation first and translate it statement-by-statement before refactoring. Do not guess at intended behaviour.
- **Preserve numeric precision.** The original code uses specific integer widths and wrapping arithmetic. Match these precisely — do not silently widen types or change arithmetic order unless you have verified equivalence with tests.
- **Do not "improve" algorithms during porting.** Port faithfully first; optimise or clean up only after tests confirm the output is bit-identical to the original.
- **Use the original as the specification.** If the Rust behaviour diverges from the Pascal behaviour in any observable way (register values, timing, envelope shape, noise pattern), treat the Pascal as correct.

### AY EMUL container note

- `.ay` files with TypeID `EMUL` can now be loaded with a **best-effort embedded-module extraction** path in `crates/vti-core/src/formats/ay.rs`.
- This is a compatibility bridge for real fixtures such as `ADDAMS2.ay`; it is **not** a full Z80 player emulation.
- If you touch this code, prefer deterministic parser checks first and keep a fixture-backed integration test for any newly-supported `.ay` sample.
 
---

## Development Approach

### Work in Small Vertical Stripes

- Tackle one small, complete slice of functionality at a time — from data model through logic to test.
- Do **not** implement several features in parallel or leave large amounts of incomplete code in the tree.
- Each stripe should leave the codebase in a better, releasable state than before.
- Prefer landing a minimal but correct implementation over a large half-finished one.

### Keep the Build Green

- `cargo build` and `cargo test` must pass on every commit.
- Never push (or leave staged) code that breaks compilation or causes test failures.
- If a change requires touching multiple crates, keep them all compiling throughout the edit.
- CI runs on all branches and pull requests — a red build blocks everything.

---

## Testing

### Test-Driven Development (TDD)

- Write the test first, see it fail, then write the minimum code to make it pass, then refactor.
- Every new behaviour should be driven by a failing test.

### Outside-In Testing

- Start from the highest useful test level (integration or end-to-end) that exercises real behaviour.
- Drive out lower-level unit tests only when they add clarity or catch edge cases the integration test cannot cover efficiently.
- Avoid testing implementation details; test observable outcomes.

### Test Levels

| Level | When to use |
|-------|-------------|
| **Unit** | Pure functions, data transformations, algorithmic edge cases (e.g. note-table lookups, register calculations). |
| **Integration** | Interactions between crates (e.g. `Engine` + `AyEmulator`, parser → `Module`). Most new tests should live here. |
| **Smoke / end-to-end** | Where possible, add a smoke test that exercises the main path through the system — load a `.pt3` file and verify it plays without panicking. |

### Appropriate Coverage

- Test the behaviour that matters: correct output registers, correct playback state transitions, correct file parsing.
- Do **not** write tests that only verify that a function calls another function.
- Device-dependent audio tests (`cpal` output) must be marked `#[ignore]` so they are excluded from CI (see `cargo test -- --ignored` in the README).

---

## Smoke Testing

Where it is feasible, add a smoke test that runs the full path through the code:

```rust
#[test]
fn smoke_load_and_play_pt3() {
    let bytes = include_bytes!("../tests/fixtures/example.pt3");
    let module = parse_pt3(bytes).expect("parse should succeed");
    let mut engine = Engine::new(module);
    engine.module_play_current_line(); // must not panic
}
```

Smoke tests catch regressions that unit tests miss. Add fixtures to `tests/fixtures/` and keep them small.

---

## Pascal Approval Tests

**When porting or modifying any Pascal function that produces computed output, you must add a Pascal baseline fixture for it.**

The Pascal source is the ground truth. The only way to confirm a Rust port is correct is to run the original Pascal code and compare its output byte-for-byte. This project maintains committed JSON fixtures generated by `pascal-tests/vt_harness.pas` (FPC).

### When a baseline is required

Add a Pascal baseline fixture whenever you:

- Port a **new** function from `legacy/trfuncs.pas` or `legacy/AY.pas` to Rust, **or**
- Change an **existing** Rust function whose behaviour is derived from Pascal, **or**
- Fix a bug in a ported function and need to verify the fix matches Pascal exactly.

### Which functions need coverage

The following categories of Pascal code require baselines (highest priority first):

| Category | Pascal source | Why |
|----------|--------------|-----|
| **Playback engine** | `legacy/trfuncs.pas` → `Pattern_PlayCurrentLine`, `Pattern_PlayOnlyCurrentLine` | AY register values per tick; any off-by-one is audible |
| **Chip clock / synthesiser logic** | `legacy/AY.pas` → `TSoundChip.Synthesizer_Logic_Q`, `Synthesizer_Logic_P` | Tone/noise/envelope counter progression drives PCM output |
| **Level table calculation** | `legacy/AY.pas` → `Calculate_Level_Tables` | Two-step rounding (scale then volume) produces different integers if collapsed; wrong tables → wrong PCM amplitude |
| **Song timing** | `legacy/trfuncs.pas` → `GetModuleTime`, `GetPositionTime`, `GetPositionTimeEx`, `GetTimeParams` | Used for seek/scrub; off-by-one causes wrong seek target |
| **Reverse note lookup** | `legacy/trfuncs.pas` → `GetNoteByEnvelope2`, `GetNoteByEnvelope` | Floating-point rounding; used in envelope editor |
| **Format parsers** (when ported) | `legacy/trfuncs.pas` → `PT32VTM`, `STC2VTM`, `SQT2VTM`, … | Binary → Module round-trip; wrong field decode is silent |

> Functions already covered: `NoiseGenerator`, all 8 envelope shapes, `PT3_Vol` table, all 5 note tables, `Pattern_PlayCurrentLine` (basic, envelope, and 3-channel arpeggio + noise drum variants). See `PLAN.md §9` for the full status table.

### How to add a new baseline

1. **Add the scenario to `pascal-tests/vt_harness.pas`** — implement the function in pure Pascal (no GUI/audio deps), call it with representative inputs, and emit a JSON object. Follow the existing pattern: `"generator": "vt_pascal_harness"`, `"test": "<name>"`.

2. **Register the new test in `pascal-tests/run_harness.sh`** — add a line:
   ```sh
   ./vt_harness <test_name> > "$CORE_FIXTURES/<test_name>.json"   # or AY_FIXTURES
   ```

3. **Run the harness locally** to generate the committed fixture:
   ```sh
   # Requires: fpc (sudo apt-get install fp-compiler)
   bash pascal-tests/run_harness.sh
   ```

4. **Add a Rust `#[test]`** in the appropriate `tests/pascal_baseline_tests.rs` that loads the fixture and asserts bit-identical output from the Rust implementation.

5. **Commit both the fixture file and the Rust test together.** The fixture is the specification; the test is the enforcer.

### Rules for fixtures

- Fixtures are **committed** — they are reviewed like any other source file.
- Regeneration is a **deliberate act** (`bash pascal-tests/run_harness.sh` or the manual GitHub Actions workflow). It is never automatic.
- A fixture diff that was not caused by an intentional Pascal source change is a **regression** — investigate before merging.
- Keep fixture scenarios **minimal** — the smallest input set that exercises the interesting boundary conditions.

---

## GUI Platform Coverage

The GUI layer (`src/`) uses **egui / eframe**, which is a single cross-platform framework. A change to any file in `src/ui/` automatically applies to:

- **Native desktop**: Linux, macOS, Windows (compiled via `cargo build`)
- **Web (WASM)**: deployed to GitHub Pages (see `pages.yml` workflow)

There are **no separate platform-specific UI files**. Any feature or bug fix committed to `src/ui/*.rs` is live on all platforms simultaneously — no per-platform follow-up is needed.

### WASM file I/O

On the WASM target, the browser's native file dialogs (`rfd`) are not available. Instead:

- `src/wasm_file.rs` — wraps the browser File System Access API (`showOpenFilePicker` / `showSaveFilePicker`) via `wasm-bindgen`.
- `src/pending_file.rs` — a one-shot channel that bridges the async JS promise result back into the egui update loop.

These two modules are compiled in only for `cfg(target_arch = "wasm32")`.  Native code continues to use `rfd` directly.

### Error dialog

`VortexTrackerApp` has an `error_dialog: Option<String>` field. When set to `Some(message)`, the `update()` loop renders a modal `egui::Window` with that message. Use this for all load/parse failures — it matches the Delphi `MessageBox(MB_ICONEXCLAMATION)` pattern from the original.

---

## Playback Cursor — Key Architecture Decision

### `current_line` is one ahead of the rendered row

`PlayVars::current_line` always points to the **next** row to be processed, not the row whose audio is currently being rendered.  `pattern_play_current_line` interprets a row, then increments the pointer before returning:

```rust
// Inside pattern_play_current_line (playback.rs):
for ch in 0..3 { self.pattern_interpreter(ch, ay_regs); }
self.vars.current_line += 1;   // pointer now points to NEXT row
self.pattern_play_only_current_line(ay_regs);  // renders using the state just set
```

This matches the original Pascal `Pattern_PlayCurrentLine`, which is why `umredrawtracks` in `main.pas` applies `- 1` when unpacking the line from the posted Windows message.

### Rule: always subtract 1 for display

Anywhere the UI reads `current_line` to show "which row is playing", it must use:

```rust
let display_line = play_vars.current_line.saturating_sub(1);
```

Violation of this rule causes the highlight to be one row ahead of the sound being produced.  The integration tests in `crates/vti-core/tests/integration_tests.rs` (section "playback cursor tracking") document and enforce this contract.

---

## CLI Diagnostics Tool

- A native terminal diagnostics binary now exists at `src/bin/vti-cli.rs` (`cargo run --bin vti-cli -- <module>`).
- Use this when debugging parser/playback paths without the GUI. It renders tracker rows and AY register snapshots.
- Keyboard contract: arrows move row/channel, `PageUp/PageDown` move positions, `Space` toggles play, `s` single-steps one tick, `f` toggles follow-playhead, `Home/End` jump row bounds, `q` quits.
- For deterministic CI/dev checks, run headless harness mode: `cargo run --bin vti-cli -- <module> --ticks <N>`. This prints PCM activity counters (`pcm_nonzero_total`) without opening an audio device.

### **MUST: Keep CLI UX in parity with GUI UX**

Whenever a new UX feature, interaction, or piece of functionality is added to the GUI (`src/ui/`), **you must update the CLI tool (`src/bin/vti-cli.rs`) to reflect the same capability** — either by exposing it via a new key binding, flag, or printed output as appropriate for a terminal context.

- This is **not** optional. A GUI feature that has no CLI equivalent is considered incomplete.
- The CLI is the primary tool for headless debugging and automated diagnostics; keeping it in sync ensures agents and developers can exercise new functionality without the GUI.
- When adding or changing a GUI interaction, include a matching CLI update in the **same commit or PR**.
- Document any new CLI key bindings or flags in the keyboard contract list above.

---

## Workflow Checklist

Before starting any new task:

1. [ ] Read `PLAN.md` to understand what is already done and what is next.
2. [ ] Identify the single smallest vertical stripe you can deliver.
3. [ ] Write a failing test that describes the expected behaviour.
4. [ ] If porting a Pascal function that produces computed output, **add a Pascal baseline fixture** first (see §Pascal Approval Tests above).
5. [ ] Implement the minimum code to make the test pass.
6. [ ] Run `cargo test -p vti-core -p vti-ay -p vti-audio` — all tests must be green.
7. [ ] Run `cargo build` — must compile cleanly.
8. [ ] Commit only green, passing code.
9. [ ] Update `PLAN.md` to tick off completed items and add any new ones discovered.
10. [ ] Update `README.md` "What works today" / "Still in progress" sections to match `PLAN.md`.
11. [ ] **If you added or changed GUI (`src/ui/`) UX or functionality: update `src/bin/vti-cli.rs` to match.** This is mandatory — see §CLI Diagnostics Tool above.
12. [ ] Update `Agents.md` with any new architecture decisions, conventions, or key contracts that future agents need to know.
