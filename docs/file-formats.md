# File Formats

> VTIR can read 13 different tracker formats used on ZX Spectrum and related
> platforms.  This page documents the binary layout of each format, the key
> differences between them, and how the Rust parser handles them.
>
> All parsers live in `crates/vti-core/src/formats/`.  The reference Pascal
> parsers are in `legacy/trfuncs.pas`.

---

## Format overview

| # | Format | Extension | Parser | Writer | Pascal name |
|---|--------|-----------|--------|--------|-------------|
| 1 | Pro Tracker 3 | `.pt3` | `pt3.rs` | ✅ `pt3.rs` | `PT32VTM` |
| 2 | Pro Tracker 2 | `.pt2` | `pt2.rs` | — | `PT22VTM` |
| 3 | Pro Tracker 1 | `.pt1` | `pt1.rs` | — | `PT12VTM` |
| 4 | Sound Tracker Compiled | `.stc` | `stc.rs` | — | `STC2VTM` |
| 5 | Sound Tracker Pro | `.stp` | `stp.rs` | — | `STP2VTM` |
| 6 | ZXAY Container | `.ay` | `ay.rs` | — | `ST12STC` + dispatch |
| 7 | VTM Text | `.vtm` | `vtm.rs` | ✅ `vtm.rs` | internal |
| 8 | ZX Spectrum Export | — | — | `zx_export.rs` | — |

Formats 4–7 in the original README (Flash Tracker, Fast Tracker, Global
Tracker, Pro Sound Creator, Pro Sound Maker, ASC Sound Master, Sound Tracker
Pro, SQ-Tracker, Amadeus/FXM) are handled through conversion shims that
normalise each binary into the VTM internal representation before further
processing.

---

## Common concepts

Before reading the individual format sections it is useful to understand a
few shared concepts.

### Module ↔ VTM normalisation

All formats are parsed into the same `Module` struct (defined in
`crates/vti-core/src/types.rs`), so the playback engine only needs to
understand one data model.  The conversion functions are named `<fmt>2VTM`
in the original Pascal and follow the same pattern in Rust.

### Positions, patterns, samples, ornaments

Every tracker format stores:
- A **position list** — an ordered sequence of pattern references that forms
  the song.  A *loop position* marks where playback wraps back.
- **Patterns** — grids of rows, each row containing note/sample/ornament
  data for all three channels.
- **Samples** — instrument "envelopes": per-tick tone delta, amplitude,
  mixer flags and noise modulation.
- **Ornaments** — per-tick semitone offsets applied to the base note
  (arpeggios, vibrato).

### Sample tick encoding

Different formats use different byte widths per sample tick, but all convey
the same information:

| Field | Range | Purpose |
|-------|-------|---------|
| `add_to_ton` | i16 | Tone frequency delta each tick |
| `ton_accumulation` | bool | Accumulate delta instead of reset |
| `amplitude` | 0–15 | Fixed volume |
| `amplitude_sliding` | bool | Ramp amplitude over time |
| `envelope_enabled` | bool | Use hardware envelope on this tick |
| `mixer_ton` | bool | Enable tone output |
| `mixer_noise` | bool | Enable noise output |

---

## 1 · Pro Tracker 3 (`.pt3`)

**Parser / writer:** `pt3.rs`  
**Features level variants:** PT3.5, Vortex Tracker II 1.0, PT3.7

PT3 is the *native* VTIR format and the most feature-rich of the group.  The
header identifies itself as either `"ProTracker 3.x"` or
`"Vortex Tracker II"`.

### Binary layout

```
Offset  Size  Field
──────────────────────────────────────────────────────
0x00    13    Header string "ProTracker 3." (or "Vortex Tracker II 1.")
0x0D     1    Version character ('4', '5', '6', '7', …)
0x0E    16    Reserved (spaces)
0x1E    32    Title (ASCII, space-padded)
0x3E    32    Author (ASCII, space-padded)
0x5E     1    Tone table index (0–4)
0x5F     1    Initial delay (speed, ticks per row)
0x60     1    Number of positions (informational)
0x61     1    Loop position index
0x62     2    Patterns table offset (LE u16, relative to file start)
0x64    64    Sample pointers [0–31]: 32 × LE u16
0xA4    32    Ornament pointers [0–15]: 16 × LE u16
0xC4     ?    Position list (bytes; 0xFF terminates)
  ...         Patterns, samples, ornaments at offsets above
```

### Position list encoding

Each byte = `pattern_index × 3`.  Divide by 3 to get the pattern index.
The list is terminated by `0xFF`.

### Pattern pointer table

For each of up to 85 patterns the table stores three LE u16 **absolute file
offsets** (not relative) — one per channel (A, B, C).

### Pattern bytecode

Patterns are compressed with a variable-length bytecode:

| Byte range | Meaning |
|------------|---------|
| `0x00` | End of channel |
| `0x01–0x0F` | Skip N rows (rest) |
| `0x10–0x1F` | Note on (with embedded octave) |
| `0x20–0x2F` | Repeat previous row N times |
| `0x30–0x3F` | Set envelope period low byte |
| `0x40–0x4F` | Set envelope type |
| `0x50–0x5F` | Set noise period |
| `0x60–0x6F` | Set ornament + volume |
| `0x70–0x7F` | Set sample |
| … | Additional command encoding |
| `0xF0–0xFF` | Sound off / rest |

Full decoder: `decode_one_pattern()` in `pt3.rs`.

### Sample encoding (4 bytes per tick)

```
Byte 0  b0
  bit 0 = NOT(envelope_enabled)
  bits 6:1 = add_to_envelope_or_noise (5-bit signed)
  bit 7 = amplitude_sliding flag

Byte 1  b1
  bits 3:0 = amplitude (0–15)
  bit 4 = NOT(mixer_ton)
  bit 5 = envelope_or_noise_accumulation
  bit 6 = ton_accumulation
  bit 7 = NOT(mixer_noise)

Bytes 2–3  add_to_ton (i16 LE)
```

### Ornament encoding

```
Byte 0  loop position
Byte 1  length
Bytes 2..N  semitone offsets (i8 each)
```

---

## 2 · Pro Tracker 2 (`.pt2`)

**Parser:** `pt2.rs`

PT2 is a compact predecessor to PT3.  The format lacks a text header and
uses a slightly different binary layout.

### Binary layout

```
Offset  Size  Field
──────────────────────────────────────────────────────
0x00     1    Delay (speed)
0x01     1    Number of positions (informational)
0x02     1    Loop position
0x03    64    Sample pointers [0–31]: 32 × LE u16
0x43    30    Ornament pointers [1–15]: 15 × LE u16
0x61     2    Patterns pointer (LE u16)
0x63    30    Title (ASCII, NUL-terminated)
0x81     ?    Position list (terminates when byte ≥ 128)
  ...         Patterns, samples, ornaments
```

Key differences from PT3:
- Position list terminates when a byte ≥ 128 is read (high bit = stop).
- Position bytes map directly to pattern indices (no ÷3 trick).
- **Sample ticks are 3 bytes** (not 4):
  - Byte 0: `bits 3:0` = amplitude; `bit 7` = mixer_ton
  - Bytes 1–2: `add_to_ton` (i16 LE)
- No envelope or noise delta fields in samples.
- Only 15 ornament slots (index 0 unused).

---

## 3 · Pro Tracker 1 (`.pt1`)

**Parser:** `pt1.rs`

PT1 is the most compact of the Pro Tracker family.

### Binary layout

```
Offset  Size  Field
──────────────────────────────────────────────────────
0x00     1    Delay
0x01     1    Number of positions
0x02     1    Loop position
0x03    32    Sample pointers [0–15]: 16 × LE u16
0x23    32    Ornament pointers [0–15]: 16 × LE u16
0x43     2    Patterns pointer (LE u16)
0x45    30    Title
0x63     ?    Position list (N bytes)
  ...         Patterns, samples, ornaments
```

Key differences:
- Only 16 samples and 16 ornaments (vs. 32 / 16 in PT3).
- Ornaments are **paired with samples** via an internal cross-reference
  table (`orn2sam[i]`), so the sample loop/length is borrowed from the
  associated sample when parsing an ornament reference.
- Pattern decoding uses a state machine that tracks current
  sample/ornament assignments across rows because PT1 rows do not
  always restate unchanged values.

---

## 4 · Sound Tracker Compiled (`.stc`)

**Parser:** `stc.rs`

STC is the compiled output of *Sound Tracker* — a very early ZX Spectrum
tracker.  Samples are stored in a **fixed 99-byte-per-slot table** at a
known offset rather than being pointer-addressed.

### Binary layout

```
Offset  Size  Field
──────────────────────────────────────────────────────
0x00     1    Delay
0x01     2    Positions pointer (LE u16)
0x03     2    Ornaments pointer (LE u16)
0x05     2    Patterns pointer (LE u16)
0x07    18    Title (ASCII; a default filler text is recognised)
0x19     2    File size (used for title detection)
0x1B  99×16   Fixed sample table (16 entries × 99 bytes)
  ...         Ornaments, patterns, positions at pointers above
```

### Sample table (99 bytes per entry)

Each slot holds:
- Byte 0: STC sample index (maps to internal index + 1)
- Bytes 1–96: 32 sample ticks × 3 bytes each
- Byte 97: loop count
- Byte 98: extra byte for length calculation

Loop/length rules:
- `loop_count == 0` → length = 33, loop = 32
- Otherwise → length = `loop_count + extra`, loop = `loop_count − 1`

### Position list

Each position byte encodes both the **pattern index** (`byte / 6`) and a
**transposition offset** (`byte % 6`) applied to every note in the pattern.

### Title detection

If the first 18 bytes match the generic placeholder `"SONG BY ST COMPILE"`,
the title field is replaced with an empty string to keep the module clean.

---

## 5 · Sound Tracker Pro (`.stp`)

**Parser:** `stp.rs`

STP is the compiled output of *Sound Tracker Pro*.  It supports a
**KSA Software Compiler** watermark that embeds a title.

### Binary layout

```
Offset  Size  Field
──────────────────────────────────────────────────────
0x00     1    Delay
0x01     2    Positions pointer
0x03     2    Patterns pointer
0x05     2    Ornaments pointer
0x07     2    Samples pointer
0x09     1    Reserved
0x0A    28    Optional: "KSA SOFTWARE COMPILER V2.0  "
0x26    25    Title (only present when KSA marker detected)
  ...         Positions, patterns, ornaments, samples at pointers
```

### KSA detection

If bytes 10–37 equal the literal string `"KSA SOFTWARE COMPILER V2.0  "`,
the module has a title at bytes 38–62; otherwise the title is left empty.

### Position structure

The position block starts with:
- Byte 0: number of positions
- Byte 1: loop position
- Remaining pairs: `[pattern_number, transposition_offset]`

---

## 6 · ZXAY Container (`.ay`)

**Parser:** `ay.rs`

`.ay` is a multi-song container format used to distribute ZX Spectrum music.
The container holds a **TypeID** that indicates what kind of data is inside.

### Container header (big-endian)

```
Offset  Size  Field
──────────────────────────────────────────────────────
0x00     4    Magic: "ZXAY"
0x04     4    TypeID: "ST11" | "AMAD" | "EMUL"
0x08     1    FileVersion
0x09     1    PlayerVersion
0x0A     2    PSpecialPlayer (i16 BE, relative to this offset)
0x0C     2    PAuthor        (i16 BE, relative to this offset)
0x0E     2    PMisc          (i16 BE, relative to this offset)
0x10     1    NumOfSongs
0x11     1    FirstSong (0-based preferred start index)
0x12     2    PSongsStructure (i16 BE, relative to 0x12)
  ...         Sub-song data
```

### TypeID dispatch

| TypeID | Meaning | Handling |
|--------|---------|---------|
| `ST11` | Sound Tracker 1 binary | Convert to STC via `st1_to_stc()`, then parse with `stc::parse()` |
| `AMAD` | Z80 machine code + AY player | Extract metadata only; full playback requires a Z80 emulator (out of scope) |
| `EMUL` | Embedded tracker binary (best-effort) | Attempt to extract a known tracker module from the payload; used by `ADDAMS2.ay` fixture |

### ST1 conversion

ST1 uses a different note encoding (`1–7` mapped to natural note names with
an octave multiplier) that the `st1_to_stc()` function converts to STC
binary format so the standard STC parser can take over.

### EMUL path

The EMUL extraction is a **best-effort compatibility bridge** — it is not
full Z80 emulation.  It scans the embedded payload for known tracker headers
(PT1/PT2/PT3/STC) and parses the first match.  Real EMUL containers may
contain arbitrary Z80 player code that cannot be decoded this way.

---

## 7 · VTM Text Format (`.vtm`)

**Parser / writer:** `vtm.rs`

VTM is VTIR's own text-based interchange format.  It is version-controlled
friendly and human-readable, making it ideal for fixture files and debugging.

### Structure

```ini
[Module]
VortexTrackerII=1
Version=3.6
Title=Song Title
Author=Author Name
NoteTable=0
ChipFreq=1750000
Speed=6
PlayOrder=L0,1,2

[Ornament0]
Length=3,LoopPos=0
L0,-1,-2

[Sample1]
Length=3,LoopPos=0
Tne +000_ +00_ C_
Tne +001_ +00_ A_
Tne +000_ +00_ 9_ L

[Pattern0]
C-4 1 . 1F . .... ....|--- . . . ....
--- . . . . .... ....|--- . . . ....
```

### Note encoding

| Text | Meaning |
|------|---------|
| `C-1`–`B-8` | 96 chromatic notes across 8 octaves |
| `R--` | Sound off (silence) |
| `---` | No note / keep previous |

### Sample tick encoding (text)

Each line in a `[SampleN]` section represents one tick:

```
Tne +000_ +00_ C_ L
^   ^     ^    ^  ^
│   │     │    │  └── Loop marker (optional)
│   │     │    └───── Amplitude (hex: 0–F)
│   │     └────────── Envelope/noise delta (hex) + accumulation flag ('_' or '-')
│   └──────────────── Tone delta (hex, signed) + accumulation flag
└──────────────────── Mixer flags: T=tone, N=noise, e=envelope (lower=disabled)
```

### PlayOrder field

Positions are comma-separated pattern indices.  A leading `L` on any index
marks it as the loop point: `L0,1,2` means positions 0, 1, 2 with loop back
to position 0.

### Advantages over binary formats

- Full human readability — diffs are meaningful
- No pointer arithmetic or byte-packing required
- Easy to create test fixtures by hand

---

## 8 · ZX Spectrum Export

**Writer only:** `zx_export.rs`

This module writes a `Module` to a binary blob suitable for playback on real
ZX Spectrum hardware.  It packs the pattern, sample, and ornament tables
together with a small Z80 player stub that the Spectrum's firmware can
invoke via the standard AY driver interface.

The output is not a parsed input format — there is no corresponding reader.

---

## Adding a new format

1. Create `crates/vti-core/src/formats/<name>.rs`.
2. Implement `pub fn parse(data: &[u8]) -> Result<Module, ParseError>`.
3. Register the parser in `crates/vti-core/src/formats/mod.rs`.
4. Add a fixture file to `crates/vti-core/tests/fixtures/tunes/` and a
   round-trip integration test in
   `crates/vti-core/tests/integration_tests.rs`.
5. If a Pascal reference implementation exists in `legacy/trfuncs.pas`,
   add a Pascal baseline fixture to verify byte-exact equivalence.
