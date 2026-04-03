//! File format parsers and writers.
//!
//! Each submodule handles one tracker file format.
//!
//! # Status
//! - `vtm`  — implemented (text format, full round-trip)
//! - `pt3`  — partial parser; writer TODO
//! - All others — **TODO** stubs; see PLAN.md

pub mod pt3;
pub mod vtm;

use crate::types::Module;
use anyhow::{bail, Result};

/// Detect the file format from the filename extension (case-insensitive) and
/// parse the bytes into a [`Module`].
///
/// Currently supported for *loading*:
/// - `.vtm` — VTM text format
/// - `.pt3` — Pro Tracker 3 binary (partial; complex patterns may not decode fully)
pub fn load(data: &[u8], filename: &str) -> Result<Module> {
    let ext = filename.rsplit('.').next().unwrap_or("").to_lowercase();
    match ext.as_str() {
        "vtm" => {
            let text = std::str::from_utf8(data)
                .map_err(|e| anyhow::anyhow!("VTM file is not valid UTF-8: {}", e))?;
            vtm::parse(text)
        }
        "pt3" => pt3::parse(data),
        _ => bail!("Unsupported file format: .{}", ext),
    }
}

/// Serialise a [`Module`] to a VTM text string suitable for writing to a `.vtm`
/// file.
pub fn save_vtm(module: &Module) -> String {
    vtm::write(module)
}

// TODO: implement remaining format parsers
// pub mod pt2;
// pub mod pt1;
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
