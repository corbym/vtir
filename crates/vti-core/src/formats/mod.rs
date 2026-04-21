//! File format parsers and writers.
//!
//! Each submodule handles one tracker file format.
//!
//! # Implemented parsers
//! - `vtm`  — VTM text format (full round-trip: parse + write)
//! - `pt3`  — Pro Tracker 3 binary (full round-trip: parse + write)
//! - `pt2`  — Pro Tracker 2 binary (parse only)
//! - `pt1`  — Pro Tracker 1 binary (parse only)
//! - `stc`  — Sound Tracker Compiled binary (parse only)
//! - `stp`  — Sound Tracker Pro binary (parse only)
//! - `ay`   — ZXAY container (ST11 sub-format + EMUL embedded-module extraction)
//! - `sqt`  — Square Tracker binary (parse only)
//! - `asc` / `as0` — ASC Sound Master binary v1/v0 (parse only)
//! - `gtr`  — Global Tracker binary (parse only)
//! - `fls`  — Flying Ledger Sound binary (parse only)
//!
//! # Not yet implemented (deferred — complex formats)
//! - `ftc` (STORY-036), `psc` (STORY-038), `psm` (STORY-039), `fxm` (STORY-040)

pub mod asc;
pub mod ay;
pub mod fls;
pub mod gtr;
pub mod pt1;
pub mod pt2;
pub mod pt3;
pub mod sqt;
pub mod stc;
pub mod stp;
pub mod vtm;
pub mod zx_export;

use crate::types::Module;
use anyhow::{bail, ensure, Result};
use std::borrow::Cow;

const TS_TRAILER_SIZE: usize = 16;

#[derive(Debug, Clone, Copy)]
struct TsTrailer {
    type1: [u8; 4],
    size1: usize,
    type2: [u8; 4],
    size2: usize,
}

fn parse_ts_trailer(data: &[u8]) -> Option<TsTrailer> {
    if data.len() <= TS_TRAILER_SIZE {
        return None;
    }
    let t = &data[data.len() - TS_TRAILER_SIZE..];
    if &t[12..16] != b"02TS" {
        return None;
    }
    Some(TsTrailer {
        type1: [t[0], t[1], t[2], t[3]],
        size1: u16::from_le_bytes([t[4], t[5]]) as usize,
        type2: [t[6], t[7], t[8], t[9]],
        size2: u16::from_le_bytes([t[10], t[11]]) as usize,
    })
}

fn ext_from_ts_type(ts_type: [u8; 4]) -> Option<&'static str> {
    match &ts_type {
        b"STC!" => Some("stc"),
        b"ASC!" => Some("asc"),
        b"STP!" => Some("stp"),
        b"FLS!" => Some("fls"),
        b"PT1!" => Some("pt1"),
        b"PT2!" => Some("pt2"),
        b"PT3!" => Some("pt3"),
        b"SQT!" => Some("sqt"),
        b"GTR!" => Some("gtr"),
        _ => None,
    }
}

/// Read a little-endian u16 from `data` at byte `offset`.
/// Returns 0 if the slice is too short.
#[inline]
fn read_u16(data: &[u8], offset: usize) -> u16 {
    if offset + 1 < data.len() {
        u16::from_le_bytes([data[offset], data[offset + 1]])
    } else {
        0
    }
}

/// Write a little-endian u16 into `buf` at byte `offset`.
#[inline]
fn write_u16(buf: &mut [u8], offset: usize, value: u16) {
    buf[offset]     = value as u8;
    buf[offset + 1] = (value >> 8) as u8;
}

/// Rebase a SQT binary that was loaded from a ZX Spectrum address space.
///
/// Faithful port of the `SQTFile` branch in `PrepareZXModule` from
/// `legacy/trfuncs.pas`.
///
/// If `SQT_SamplesPointer` (offset 2) is already ≤ the file length the data
/// is treated as PC-format (already file-relative) and returned unchanged.
/// Otherwise the load base `i = SamplesPointer − 10` is subtracted from every
/// pointer word in the rebase range.
pub fn prepare_zx_module_sqt(data: &[u8]) -> Cow<'_, [u8]> {
    if data.len() < 12 {
        return Cow::Borrowed(data);
    }

    let sam_ptr = read_u16(data, 2) as usize;
    let pos_ptr = read_u16(data, 8) as usize;
    let pat_ptr = read_u16(data, 6) as usize;

    // If SamplesPointer fits within the file the data is already file-relative.
    if sam_ptr <= data.len() {
        return Cow::Borrowed(data);
    }

    // i = SQT_SamplesPointer - 10  (Pascal: i := ZXP^.SQT_SamplesPointer - 10)
    let load_base = sam_ptr.wrapping_sub(10);
    if load_base == 0 {
        return Cow::Borrowed(data);
    }

    // Walk the positions table to find j = max PatChanNumber across all entries.
    // (Pascal: k := ZXP^.SQT_PositionsPointer - i; while ZXP^.Index[k] <> 0 …)
    let mut j: usize = 0;
    let mut k = pos_ptr.wrapping_sub(load_base);
    while k < data.len() && data[k] != 0 {
        j = j.max((data[k] & 0x7f) as usize);
        k = k.wrapping_add(2);
        if k >= data.len() { break; }
        j = j.max((data[k] & 0x7f) as usize);
        k = k.wrapping_add(2);
        if k >= data.len() { break; }
        j = j.max((data[k] & 0x7f) as usize);
        k = k.wrapping_add(3);
    }

    // count = (SQT_PatternsPointer − i + j*2) / 2
    // (Pascal: for k := 1 to (ZXP^.SQT_PatternsPointer - i + j shl 1) div 2)
    let count = (pat_ptr.wrapping_sub(load_base).wrapping_add(j * 2)) / 2;

    // Rebase: decrement `count` consecutive words starting at byte offset 2.
    // (Pascal: pwrd := @ZXP^.SQT_SamplesPointer; Dec(pwrd^, i); Inc(pwrd); …)
    let mut out = data.to_vec();
    for n in 0..count {
        let off = 2 + n * 2;
        if off + 1 >= out.len() { break; }
        let v = read_u16(&out, off).wrapping_sub(load_base as u16);
        write_u16(&mut out, off, v);
    }
    Cow::Owned(out)
}

/// Rebase an FLS binary that was loaded from a ZX Spectrum address space.
///
/// Faithful port of the `FLSFile` branch in `PrepareZXModule` from
/// `legacy/trfuncs.pas`, including the structural-validation loop that
/// determines the load base `i`.
///
/// Returns `Some(Cow::Borrowed)` when no rebasing is needed, `Some(Cow::Owned)`
/// with the rebased data when the file is ZX-format, and `None` when the
/// structure cannot be validated (the Pascal code sets `FType := Unknown`).
pub fn prepare_zx_module_fls(data: &[u8]) -> Option<Cow<'_, [u8]>> {
    if data.len() < 12 {
        return Some(Cow::Borrowed(data));
    }

    let orn_ptr = read_u16(data, 2) as usize; // FLS_OrnamentsPointer
    let sam_ptr = read_u16(data, 4) as usize; // FLS_SamplesPointer
    let pos_ptr = read_u16(data, 0) as usize; // FLS_PositionsPointer
    // PatternA / PatternB of first pattern entry are at offsets 6 and 8.
    let pat_a   = read_u16(data, 6) as usize;
    let pat_b   = read_u16(data, 8) as usize;

    let length = data.len();

    // Pascal: i := ZXP^.FLS_OrnamentsPointer - 16; if i >= 0 then repeat … until i < 0
    let start_i = (orn_ptr as isize) - 16;
    if start_i < 0 {
        return None;
    }
    let mut i = start_i as usize;

    let load_base: Option<usize> = loop {
        // i2 := ZXP^.FLS_SamplesPointer + 2 - i
        let i2 = match sam_ptr.checked_add(2).and_then(|v| v.checked_sub(i)) {
            Some(v) if v >= 8 && v < length => v,
            _ => { if i == 0 { break None; } i -= 1; continue; }
        };

        // i1 := word@i2 - i
        let raw_i1 = read_u16(data, i2) as usize;
        let i1 = match raw_i1.checked_sub(i) {
            Some(v) if v >= 8 && v < length => v,
            _ => { if i == 0 { break None; } i -= 1; continue; }
        };

        // i2 := word@(i2-4) - i
        let i2b = match i2.checked_sub(4) {
            Some(off) => {
                let raw = read_u16(data, off) as usize;
                match raw.checked_sub(i) {
                    Some(v) if v >= 6 && v < length => v,
                    _ => { if i == 0 { break None; } i -= 1; continue; }
                }
            }
            None => { if i == 0 { break None; } i -= 1; continue; }
        };

        // if i1 - i2 = $20
        if i1.wrapping_sub(i2b) != 0x20 {
            if i == 0 { break None; }
            i -= 1;
            continue;
        }

        // i2 := PatternB - i;  i1 := PatternA - i
        let i2_pat = match pat_b.checked_sub(i) {
            Some(v) if v > 21 && v < length => v,
            _ => { if i == 0 { break None; } i -= 1; continue; }
        };
        let i1_pat = match pat_a.checked_sub(i) {
            Some(v) if v > 20 && v < length => v,
            _ => { if i == 0 { break None; } i -= 1; continue; }
        };

        // if ZXP^.Index[i1 - 1] = 0
        if i1_pat == 0 || data[i1_pat - 1] != 0 {
            if i == 0 { break None; }
            i -= 1;
            continue;
        }

        // Pattern walk matching Pascal inner repeat/outer while
        let mut walk = i1_pat;
        while walk < length && data[walk] != 0xff {
            // inner repeat
            // Pascal: case ZXP^.Index[i1] of 0..$5f, $80, $81: (Inc+break); $82..$8e: (Inc); else (Inc+break)
            loop {
                if walk >= length { break; }
                match data[walk] {
                    0x00..=0x5f | 0x80 | 0x81 => { walk += 1; break; }
                    0x82..=0x8e              => { walk += 1; }
                    _                        => { walk += 1; break; }  // else branch
                }
            }
        }

        if walk + 1 == i2_pat {
            break Some(i);
        }

        if i == 0 { break None; }
        i -= 1;
    };

    let load_base = load_base?;  // None → FType := Unknown

    if load_base == 0 {
        return Some(Cow::Borrowed(data));
    }

    // Rebase — faithful port of the two loops after the validation.
    // p1 = FLS_SamplesPointer - load_base  (first byte after the header pointer words)
    // p2 = FLS_PositionsPointer - load_base + 2
    let p1 = sam_ptr.wrapping_sub(load_base);
    let p2 = pos_ptr.wrapping_sub(load_base).wrapping_add(2);

    let mut out = data.to_vec();

    // First loop: decrement consecutive words from offset 0 to p1 (exclusive).
    let mut off = 0usize;
    while off < p1 {
        if off + 1 >= out.len() { break; }
        let v = read_u16(&out, off).wrapping_sub(load_base as u16);
        write_u16(&mut out, off, v);
        off += 2;
    }

    // Inc(pwrd) — skip one word (the sample loop/extra non-pointer bytes).
    off += 2;

    // Second loop: decrement words at stride 4 (tick_ptr every 4 bytes) until p2.
    while off < p2 {
        if off + 1 >= out.len() { break; }
        let v = read_u16(&out, off).wrapping_sub(load_base as u16);
        write_u16(&mut out, off, v);
        off += 4;
    }

    Some(Cow::Owned(out))
}

/// Detect the tracker file format from the raw bytes of a file, without
/// relying on a filename extension.
///
/// Returns a lowercase extension string (e.g. `"pt3"`, `"vtm"`, `"ay"`) when
/// the format can be identified, or `None` when it cannot.
///
/// Detection rules (in priority order):
/// 1. AY container — magic `"ZXAYEMUL"` at offset 0.
/// 2. VTM text format — file starts with `"[Module]"`.
/// 3. PT3 — text header contains `"ProTracker 3"` in the first 100 bytes.
/// 4. TurboSound trailer — `"02TS"` at the last 4 bytes; inner type tags
///    resolved via [`ext_from_ts_type`].
/// 5. Any format for which the parser reports no error (not implemented here;
///    use [`load_and_detect`] for a full parse attempt).
pub fn detect_format_from_bytes(data: &[u8]) -> Option<&'static str> {
    if data.len() < 4 {
        return None;
    }

    // AY container
    if data.starts_with(b"ZXAYEMUL") {
        return Some("ay");
    }

    // VTM text format
    if data.starts_with(b"[Module]") {
        return Some("vtm");
    }

    // PT3 — look for "ProTracker 3" in the first 100 bytes of the text header
    let header_region = &data[..data.len().min(100)];
    if header_region.windows(12).any(|w| w == b"ProTracker 3") {
        return Some("pt3");
    }

    // TurboSound trailer
    if let Some(ts) = parse_ts_trailer(data) {
        if let Some(ext) = ext_from_ts_type(ts.type1) {
            return Some(ext);
        }
    }

    None
}

/// Load a [`Module`] from raw bytes without requiring a filename extension.
///
/// Uses [`detect_format_from_bytes`] to identify the format from magic bytes,
/// then delegates to the appropriate parser.  Returns an error when the format
/// cannot be detected.
///
/// For multi-chip (TurboSound) files, use [`load_modules`] with a filename
/// instead — this function returns only the first module.
pub fn load_and_detect(data: &[u8]) -> Result<Module> {
    let ext = detect_format_from_bytes(data)
        .ok_or_else(|| anyhow::anyhow!("Cannot detect file format from content"))?;
    load_by_ext(data, ext)
}

fn load_by_ext(data: &[u8], ext: &str) -> Result<Module> {
    match ext {
        "vtm" => {
            let text = std::str::from_utf8(data)
                .map_err(|e| anyhow::anyhow!("VTM file is not valid UTF-8: {}", e))?;
            vtm::parse(text)
        }
        "pt3" => pt3::parse(data),
        "pt2" => pt2::parse(data),
        "pt1" => pt1::parse(data),
        "stc" => stc::parse(data),
        "stp" => stp::parse(data),
        "ay" => ay::parse(data, 0),
        "sqt" => sqt::parse(&prepare_zx_module_sqt(data)),
        "asc" => asc::parse(data),
        "as0" => asc::parse_asc0(data),
        "gtr" => gtr::parse(data),
        "fls" => match prepare_zx_module_fls(data) {
            Some(prepared) => fls::parse(&prepared),
            None => bail!("FLS file has an unrecognised ZX Spectrum load address"),
        },
        _ => bail!("Unsupported file format: .{}", ext),
    }
}

/// Load one or two modules from a file.
///
/// Legacy VT2 supported a TurboSound trailer (`02TS`) that appends a second
/// tracker module to the same file. When that trailer is present and both
/// embedded module types are supported by this Rust port, this function returns
/// both modules (`chip 1`, `chip 2`) in order.
pub fn load_modules(data: &[u8], filename: &str) -> Result<Vec<Module>> {
    if let Some(ts) = parse_ts_trailer(data) {
        let Some(ext1) = ext_from_ts_type(ts.type1) else {
            return Ok(vec![load(data, filename)?]);
        };
        let Some(ext2) = ext_from_ts_type(ts.type2) else {
            return Ok(vec![load(data, filename)?]);
        };

        ensure!(
            ts.size1 + ts.size2 + TS_TRAILER_SIZE <= data.len(),
            "TurboSound trailer sizes exceed file length"
        );

        let first = load_by_ext(&data[..ts.size1], ext1)?;
        let second = load_by_ext(&data[ts.size1..ts.size1 + ts.size2], ext2)?;
        return Ok(vec![first, second]);
    }

    Ok(vec![load(data, filename)?])
}

/// Detect the file format from the filename extension (case-insensitive) and
/// parse the bytes into a [`Module`].
///
/// Currently supported for *loading*:
/// - `.vtm` — VTM text format
/// - `.pt3` — Pro Tracker 3 binary
/// - `.pt2` — Pro Tracker 2 binary
/// - `.pt1` — Pro Tracker 1 binary
/// - `.stc` — Sound Tracker Compiled binary
/// - `.stp` — Sound Tracker Pro binary
/// - `.ay`  — ZXAY container (ST11 sub-format; EMUL embedded-module extraction)
/// - `.sqt` — Square Tracker binary
/// - `.asc` — ASC Sound Master binary (v1, with loop position)
/// - `.as0` — ASC Sound Master binary (v0, without loop position)
/// - `.gtr` — Global Tracker binary
/// - `.fls` — Flying Ledger Sound binary
pub fn load(data: &[u8], filename: &str) -> Result<Module> {
    let ext = filename.rsplit('.').next().unwrap_or("").to_lowercase();
    load_by_ext(data, ext.as_str())
}

/// Serialise a [`Module`] to a VTM text string suitable for writing to a `.vtm`
/// file.
pub fn save_vtm(module: &Module) -> String {
    vtm::write(module)
}

/// Serialise a [`Module`] to a PT3 binary blob suitable for writing to a `.pt3`
/// file.
pub fn save_pt3(module: &Module) -> Result<Vec<u8>> {
    pt3::write(module)
}

/// Export a [`Module`] to a ZX Spectrum binary in the format specified by
/// `opts`.  See [`zx_export::ZxExportOptions`] and [`zx_export::ZxFormat`].
pub fn save_zx(module: &Module, opts: &zx_export::ZxExportOptions) -> Result<Vec<u8>> {
    zx_export::export_zx(module, opts)
}
