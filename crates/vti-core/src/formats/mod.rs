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
        "sqt" => sqt::parse(data),
        "asc" => asc::parse(data),
        "as0" => asc::parse_asc0(data),
        "gtr" => gtr::parse(data),
        "fls" => fls::parse(data),
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
