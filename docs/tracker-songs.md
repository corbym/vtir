# Tracker Songs & Fixtures

This page catalogues all the tracker song files in the repository — both
the real-world tunes used as integration test fixtures and the minimal
hand-crafted files used for round-trip and format-compatibility tests.

All files live under:

```
crates/vti-core/tests/fixtures/tunes/
```

---

## Real-world tunes

These are genuine ZX Spectrum chiptunes included to exercise the format
parsers against production-quality files.

### ADDAMS2.ay

| Field | Value |
|-------|-------|
| **File** | `ADDAMS2.ay` |
| **Format** | ZXAY container — TypeID `EMUL` |
| **Size** | 5 460 bytes |
| **Notes** | Multi-song container.  The embedded module is extracted via the best-effort EMUL path in `ay.rs`.  Used in the CLI smoke test: `./scripts/vti-cli … ADDAMS2.ay`. |

The EMUL type means the container wraps a compiled Z80 binary; VTIR scans
the payload for a recognisable tracker header and extracts it.  This fixture
is the primary stress-test for the `.ay` parser.

---

### Space Crusade Loader.pt3

| Field | Value |
|-------|-------|
| **File** | `Space Crusade Loader.pt3` |
| **Format** | Pro Tracker 3 |
| **Size** | 3 736 bytes |
| **Title** | GO! GO! GO! |
| **Author** | by 3VC '98 |
| **Notes** | A full-length PT3 song from a real ZX Spectrum release, used to verify the pattern decoder handles all opcodes encountered in real music. |

---

### amigoz1.pt2

| Field | Value |
|-------|-------|
| **File** | `amigoz1.pt2` |
| **Format** | Pro Tracker 2 |
| **Size** | 3 853 bytes |
| **Title** | \*\*\* REMEMBER \*\*\* (C) 3VS 1997 |
| **Notes** | Real PT2 tune; validates the 3-byte-per-tick sample decoder and the PT2-specific position list termination (byte ≥ 128). |

---

### madness_descent.pt3 / .vtm

| Field | Value |
|-------|-------|
| **Files** | `madness_descent.pt3`, `madness_descent.vtm` |
| **Format** | PT3 (binary) + VTM (text mirror) |
| **Size** | 583 bytes (PT3), ~5 KB (VTM) |
| **Title** | Descent Into Madness |
| **Author** | VTIR Test Fixture |
| **Notes** | Created specifically for this project to exercise three-channel playback with ornaments and envelope modulation.  The `.vtm` file is the human-readable source; the `.pt3` is the compiled binary.  Both are kept in sync and compared by the round-trip test. |

The VTM source uses:
- 3 samples (tone + noise + envelope instruments)
- 2 ornaments (chromatic descent and chord arpeggio)
- 2 patterns × 32 rows each, played in sequence `0 1 0 1 0 1 0 1 0 1`
- Speed 6 (6 tracker frames per row)

---

### minimal.ay

| Field | Value |
|-------|-------|
| **File** | `minimal.ay` |
| **Format** | ZXAY container — TypeID `ST11` (Sound Tracker 1) |
| **Size** | 3 635 bytes |
| **Notes** | Minimal ST11 container.  Exercises the `st1_to_stc()` conversion path: the ST1 binary inside is converted to STC format in memory and then parsed normally. |

---

## Round-trip fixtures

These are minimal synthetic files — the smallest valid file for each format
— used to verify that the parser and writer produce bit-identical output.

### minimal_roundtrip.pt3

| Field | Value |
|-------|-------|
| **File** | `minimal_roundtrip.pt3` |
| **Format** | Pro Tracker 3 |
| **Size** | 305 bytes |
| **Title** | Round Trip Test |
| **Author** | by Fixture Generator |
| **Notes** | Contains one 4-row pattern, one sample, one ornament, one position.  Parse → write → parse cycle must produce an identical `Module`. |

---

### minimal_roundtrip.pt2

| Field | Value |
|-------|-------|
| **File** | `minimal_roundtrip.pt2` |
| **Format** | Pro Tracker 2 |
| **Size** | 151 bytes |
| **Title** | PT2 minimal fixture |
| **Notes** | Smallest valid PT2 file.  Exercises the high-bit position list termination and 3-byte sample tick decoder. |

---

### minimal_roundtrip.pt1

| Field | Value |
|-------|-------|
| **File** | `minimal_roundtrip.pt1` |
| **Format** | Pro Tracker 1 |
| **Size** | 120 bytes |
| **Notes** | Minimal PT1 file.  Tests the ornament↔sample cross-reference mapping that is specific to PT1. |

---

### minimal_roundtrip.stc

| Field | Value |
|-------|-------|
| **File** | `minimal_roundtrip.stc` |
| **Format** | Sound Tracker Compiled |
| **Size** | 1 691 bytes |
| **Notes** | Valid STC file.  The fixed-size sample table means STC files have a minimum size even with trivial content.  Tests the per-position transposition offset decoding. |

---

### minimal_roundtrip.stp

| Field | Value |
|-------|-------|
| **File** | `minimal_roundtrip.stp` |
| **Format** | Sound Tracker Pro |
| **Size** | 128 bytes |
| **Notes** | Minimal STP file without the KSA compiler watermark.  Tests the pointer-based sample/ornament/pattern layout. |

---

## Loading a file in the CLI

```sh
# Interactive mode (arrows + space to play/pause):
./scripts/vti-cli crates/vti-core/tests/fixtures/tunes/ADDAMS2.ay

# Start with playback enabled:
./scripts/vti-cli crates/vti-core/tests/fixtures/tunes/madness_descent.pt3 --play=true

# Headless diagnostics (512 ticks, no audio device needed):
./scripts/vti-cli crates/vti-core/tests/fixtures/tunes/madness_descent.pt3 --ticks 512
```

Keyboard controls in interactive mode:

| Key | Action |
|-----|--------|
| `↑` / `↓` | Move row cursor |
| `←` / `→` | Move channel cursor |
| `PgUp` / `PgDn` | Previous / next position |
| `Home` / `End` | Jump to first / last row |
| `Space` | Play / pause |
| `s` | Step one tick |
| `f` | Toggle follow-playhead |
| `q` | Quit |

---

## Loading a file in the GUI

Launch the GUI binary (`cargo run --release`) and use **File → Open** to
select any of the supported formats.  The pattern editor will populate
immediately and the **▶ Play** toolbar button starts playback.

For the WASM web build at <https://corbym.github.io/vtir/> the process is
the same, but the file is loaded from the browser's local filesystem via the
HTML file-picker.

---

## Adding a new fixture

1. Place the file in `crates/vti-core/tests/fixtures/tunes/`.
2. Add an integration test in `crates/vti-core/tests/integration_tests.rs`
   that at minimum calls `parse_*` and asserts `is_ok()`.
3. For a real tune you do not own: confirm the licence allows redistribution.
   If uncertain, use only the filename / metadata in the test and load the
   file from disk rather than `include_bytes!`.
4. Update this page with a new entry in the appropriate section above.
