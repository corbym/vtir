//! File format parsers and writers.
//!
//! Each submodule handles one tracker file format.
//!
//! # Status
//! - `vtm`  — implemented (text format, full round-trip)
//! - `pt3`  — full parser and writer
//! - `pt2`  — parser (Pro Tracker 2 binary)
//! - `pt1`  — parser (Pro Tracker 1 binary)
//! - `stc`  — parser (Sound Tracker Compiled binary)
//! - `stp`  — parser (Sound Tracker Pro binary)
//! - `ay`   — parser (ZXAY container, ST11 sub-format only)
//! - All others — **TODO** stubs; see PLAN.md

pub mod ay;
pub mod pt1;
pub mod pt2;
pub mod pt3;
pub mod stc;
pub mod stp;
pub mod vtm;
pub mod zx_export;

use crate::types::Module;
use anyhow::{bail, Result};

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
/// - `.ay`  — ZXAY container (ST11 sub-format; imports the first sub-song)
pub fn load(data: &[u8], filename: &str) -> Result<Module> {
    let ext = filename.rsplit('.').next().unwrap_or("").to_lowercase();
    match ext.as_str() {
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
        _ => bail!("Unsupported file format: .{}", ext),
    }
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

// TODO: implement remaining format parsers
// pub mod asc;
// pub mod sqt;
// pub mod gtr;
// pub mod ftc;
// pub mod fls;
// pub mod psc;
// pub mod psm;
// pub mod fxm;
// pub mod stc;
// pub mod asc;
// pub mod stp;
// pub mod sqt;
// pub mod gtr;
// pub mod ftc;
// pub mod fls;
// pub mod psc;
// pub mod psm;
// pub mod fxm;
