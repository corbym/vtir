# PT3 Sample/Ornament Deduplication — Compactness Improvement

## Background

ZX Spectrum RAM is only **65,536 bytes** in total. Every byte in a `.pt3` module
competes with the player code and the ZX Spectrum OS for that same space. The
original Vortex Tracker II (Pascal/Delphi) writes one copy of a sample or ornament
block **for every index that uses it**, even when two indices contain identical
content. In a typical tracker session a composer often copies an instrument across
multiple slots — eight identical hihat samples are common. Under the Pascal scheme
that wastes 70 bytes for samples alone.

The Rust port (`crates/vti-core/src/formats/pt3.rs`) deduplicates sample and
ornament data at write time. If two indices carry identical byte content, only one
copy is written and both pointer-table slots point to it.

---

## Original Pascal code (`legacy/trfuncs.pas`, function `VTM2PT3`)

```pascal
// lines 2734–2779 (abbreviated)
for i := 1 to 31 do
  if IsSample[i] then
  begin
    // Always assigns a NEW file offset — no check for identical content.
    PT3.PT3_SamplePointers[i] := PatNum;

    PT3.Index[PatNum] := VTM.Samples[i].Loop;    Inc(PatNum);
    PT3.Index[PatNum] := VTM.Samples[i].Length;  Inc(PatNum);
    for j := 0 to VTM.Samples[i].Length - 1 do
    begin
      // encode 4 bytes per tick …
      Inc(PatNum, 4)
    end
  end;

for i := 1 to 15 do
  if IsOrnament[i] then
  begin
    // Again, always a NEW offset.
    PT3.PT3_OrnamentPointers[i] := PatNum;
    PT3.Index[PatNum] := VTM.Ornaments[i].Loop;    Inc(PatNum);
    PT3.Index[PatNum] := VTM.Ornaments[i].Length;  Inc(PatNum);
    for j := 0 to VTM.Ornaments[i].Length - 1 do
    begin
      PT3.Index[PatNum] := VTM.Ornaments[i].Items[j];
      Inc(PatNum)
    end
  end;
```

**No comparison is made** between sample blocks before assigning `PT3_SamplePointers[i]`.
Each live index unconditionally receives its own copy.

---

## Rust implementation (`crates/vti-core/src/formats/pt3.rs`)

```rust
// Build the binary content for every used sample …
let mut sample_bytes: Vec<Option<Vec<u8>>> = vec![None; 32];
for i in 1..32 {
    if !is_sample[i] { continue; }
    sample_bytes[i] = Some(encode_sample(&module.samples[i]));
}

// Write samples, deduplicating identical content.
let mut sample_written_at: [Option<u16>; 32] = [None; 32];
for i in 1..32 {
    let Some(ref content) = sample_bytes[i] else { continue };
    // Check whether any earlier sample was identical.
    let reuse = (1..i).find(|&j| {
        sample_bytes[j].as_deref() == Some(content.as_slice())
    });
    if let Some(j) = reuse {
        // Point this index at the SAME file offset as the earlier copy.
        write_word(&mut out, OFF_SAM_PTRS + i * 2, sample_written_at[j].unwrap());
    } else {
        // First occurrence — write once and record the offset.
        let pos = write_pos as u16;
        out[write_pos..write_pos + content.len()].copy_from_slice(content);
        write_pos += content.len();
        write_word(&mut out, OFF_SAM_PTRS + i * 2, pos);
        sample_written_at[i] = Some(pos);
    }
}
```

The same deduplication loop is applied to ornaments immediately afterwards.

---

## Byte-count comparison — worst case for the Pascal original

**Fixture:** 8 identical samples (2-tick, 10 bytes each) and 6 identical ornaments
(2-step, 4 bytes each).

| Block | Pascal output | Rust output | Saving |
|-------|:---:|:---:|:---:|
| 8 samples × 10 B | **80 B** | 10 B (1 copy) | **70 B** |
| 6 ornaments × 4 B | **24 B** | 4 B (1 copy) | **20 B** |
| **Total** | **104 B** | **14 B** | **90 B** |

### Per-item layout

A sample with 2 ticks:

```
Byte 0  : loop_pos           (1 byte)
Byte 1  : length             (1 byte)
Bytes 2–5 : tick 0           (4 bytes: b0, b1, add_to_ton lo, add_to_ton hi)
Bytes 6–9 : tick 1           (4 bytes)
──────────────────────────────────────────
             total            10 bytes
```

An ornament with 2 steps:

```
Byte 0  : loop_pos           (1 byte)
Byte 1  : length             (1 byte)
Bytes 2–3 : steps 0 and 1   (1 byte each)
──────────────────────────────────────────
             total            4 bytes
```

---

## Integration test

The saving is verified in `crates/vti-core/tests/integration_tests.rs`:

```rust
#[test]
fn pt3_dedup_reduces_size_for_duplicate_heavy_module() {
    let m = make_duplicate_heavy_module(); // samples 1-8 all identical, ornaments 1-6 all identical
    let dedup_bytes = save_pt3(&m).expect("must write");

    // Same module but with 8 *different* samples (unique amplitudes per index).
    let unique_bytes = save_pt3(&make_unique_sample_module()).expect("unique must write");

    // Dedup output must be strictly smaller …
    assert!(dedup_bytes.len() < unique_bytes.len());

    // … and save at least 70 bytes (7 × 10 B from samples alone).
    let saving = unique_bytes.len() - dedup_bytes.len();
    assert!(saving >= 70, "expected ≥70 bytes saved, got {}", saving);

    // Round-trip: all 8 sample indices still carry the correct content.
    let reloaded = pt3::parse(&dedup_bytes).expect("must re-parse");
    for i in 1..=8 {
        let s = reloaded.samples[i].as_deref().unwrap();
        assert_eq!(s.items[0].amplitude, 12);
        assert_eq!(s.items[1].amplitude, 8);
    }
}
```

Run with:

```sh
cargo test -p vti-core pt3_dedup
```
