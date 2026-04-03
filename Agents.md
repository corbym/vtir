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

## Workflow Checklist

Before starting any new task:

1. [ ] Read `PLAN.md` to understand what is already done and what is next.
2. [ ] Identify the single smallest vertical stripe you can deliver.
3. [ ] Write a failing test that describes the expected behaviour.
4. [ ] Implement the minimum code to make the test pass.
5. [ ] Run `cargo test -p vti-core -p vti-ay -p vti-audio` — all tests must be green.
6. [ ] Run `cargo build` — must compile cleanly.
7. [ ] Commit only green, passing code.
8. [ ] Update `PLAN.md` to reflect what is now done.
