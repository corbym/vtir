//! Pro Tracker 3.xx (*.pt3) binary format parser and writer.
//!
//! Ported from `PT32VTM` and `VTM2PT3` in `trfuncs.pas`
//! (c) 2000-2009 S.V.Bulba.

use crate::types::*;
use anyhow::{bail, ensure, Context, Result};

// ─── PT3 binary layout offsets ───────────────────────────────────────────────

const PT3_NAME_LEN: usize = 0x63;
const OFF_TABLE: usize = 0x63;
const OFF_DELAY: usize = 0x64;
const OFF_NUM_POS: usize = 0x65;
const OFF_LOOP_POS: usize = 0x66;
const OFF_PAT_PTR: usize = 0x67; // word
const OFF_SAM_PTRS: usize = 0x69; // 32 × word
const OFF_ORN_PTRS: usize = 0xA9; // 16 × word
const OFF_POS_LIST: usize = 0xC9;

// ─── Parser ──────────────────────────────────────────────────────────────────

/// Parse a raw PT3 binary blob into a [`Module`].
pub fn parse(data: &[u8]) -> Result<Module> {
    ensure!(data.len() >= OFF_POS_LIST + 2, "PT3: file too small");

    let mut module = Module::default();

    // Title (bytes 0x00..0x62, null-terminated or full)
    let name_bytes = &data[0..PT3_NAME_LEN];
    let name_end = name_bytes.iter().position(|&b| b == 0).unwrap_or(PT3_NAME_LEN);
    module.title = String::from_utf8_lossy(&name_bytes[..name_end]).to_string();

    module.ton_table = data[OFF_TABLE] & 0x0F;
    module.initial_delay = data[OFF_DELAY];

    // Position list
    let num_pos = data[OFF_NUM_POS] as usize;
    let loop_pos = data[OFF_LOOP_POS] as usize;
    ensure!(num_pos > 0, "PT3: no positions");

    module.positions.length = num_pos;
    module.positions.loop_pos = loop_pos;
    for i in 0..num_pos {
        let off = OFF_POS_LIST + i;
        ensure!(off < data.len(), "PT3: position list truncated");
        module.positions.value[i] = data[off] as usize;
    }

    // Patterns pointer (word, little-endian, relative to file start)
    let pat_ptr = u16::from_le_bytes([data[OFF_PAT_PTR], data[OFF_PAT_PTR + 1]]) as usize;

    // Sample pointers (32 entries, indices 0..31)
    for i in 0..32usize {
        let off = OFF_SAM_PTRS + i * 2;
        if off + 1 >= data.len() {
            break;
        }
        let ptr = u16::from_le_bytes([data[off], data[off + 1]]) as usize;
        if ptr == 0 || ptr >= data.len() {
            continue;
        }
        if let Ok(sam) = parse_sample(&data[ptr..]) {
            module.samples[i] = Some(Box::new(sam));
        }
    }

    // Ornament pointers (16 entries, indices 0..15)
    for i in 0..16usize {
        let off = OFF_ORN_PTRS + i * 2;
        if off + 1 >= data.len() {
            break;
        }
        let ptr = u16::from_le_bytes([data[off], data[off + 1]]) as usize;
        if ptr == 0 || ptr >= data.len() {
            continue;
        }
        if let Ok(orn) = parse_ornament(&data[ptr..]) {
            module.ornaments[i] = Some(Box::new(orn));
        }
    }

    // Patterns
    if pat_ptr < data.len() {
        parse_patterns(&data[pat_ptr..], &mut module)
            .context("PT3: parsing patterns")?;
    }

    Ok(module)
}

fn parse_sample(data: &[u8]) -> Result<Sample> {
    ensure!(data.len() >= 2, "sample too small");
    let mut sam = Sample::default();
    sam.loop_pos = data[0];
    sam.length = data[1];
    ensure!(sam.length as usize <= MAX_SAM_LEN, "sample length overflow");

    for i in 0..sam.length as usize {
        let off = 2 + i * 3;
        ensure!(off + 2 < data.len(), "sample data truncated");
        let b0 = data[off];
        let b1 = data[off + 1];
        let b2 = data[off + 2];

        let tick = &mut sam.items[i];
        tick.ton_accumulation    = (b0 & 0x80) != 0;
        tick.mixer_noise         = (b0 & 0x40) == 0;
        tick.mixer_ton           = (b0 & 0x01) == 0;
        tick.amplitude_sliding   = (b1 & 0x80) != 0;
        tick.amplitude_slide_up  = (b1 & 0x40) != 0;
        tick.amplitude           = b1 & 0x0F;
        tick.envelope_enabled    = (b2 & 0x80) != 0;
        tick.envelope_or_noise_accumulation = (b2 & 0x40) != 0;
        // Add_to_Ton: signed 5-bit from b0[6:2], sign-extended
        let raw_ton = ((b0 & 0x3E) >> 1) as i8;
        let raw_ton = if (b0 & 0x20) != 0 { raw_ton | (!0x1F_i8) } else { raw_ton };
        tick.add_to_ton = raw_ton as i16;
        // Add_to_Envelope_or_Noise: signed 4-bit from b2[3:0]
        let raw_env = (b2 & 0x0F) as i8;
        tick.add_to_envelope_or_noise = if (b2 & 0x08) != 0 { raw_env | (!0x0F_i8) } else { raw_env };
    }

    Ok(sam)
}

fn parse_ornament(data: &[u8]) -> Result<Ornament> {
    ensure!(data.len() >= 2, "ornament too small");
    let mut orn = Ornament::default();
    orn.loop_pos = data[0] as usize;
    orn.length = data[1] as usize;
    ensure!(orn.length <= MAX_ORN_LEN, "ornament length overflow");
    for i in 0..orn.length {
        ensure!(2 + i < data.len(), "ornament data truncated");
        orn.items[i] = data[2 + i] as i8;
    }
    Ok(orn)
}

fn parse_patterns(data: &[u8], module: &mut Module) -> Result<()> {
    // PT3 patterns block: three channel offsets per pattern, then channel data
    let mut pos = 0;
    loop {
        if pos + 6 > data.len() {
            break;
        }
        let off_a = u16::from_le_bytes([data[pos], data[pos + 1]]) as usize;
        let off_b = u16::from_le_bytes([data[pos + 2], data[pos + 3]]) as usize;
        let off_c = u16::from_le_bytes([data[pos + 4], data[pos + 5]]) as usize;
        pos += 6;

        if off_a == 0 && off_b == 0 && off_c == 0 {
            break;
        }

        let pat_index = (pos / 6) - 1;
        if pat_index >= MAX_NUM_OF_PATS {
            bail!("PT3: too many patterns");
        }

        let mut pattern = Pattern::default();
        pattern.length = 0;

        // Decode channels A, B, C in parallel
        let (rows_a, env_a, _noise_a) = decode_channel(data, off_a)?;
        let (rows_b, _env_b, _noise_b) = decode_channel(data, off_b)?;
        let (rows_c, _env_c, noise_c) = decode_channel(data, off_c)?;

        let len = rows_a.len().min(rows_b.len()).min(rows_c.len());
        pattern.length = len;

        for i in 0..len {
            pattern.items[i].channel[0] = rows_a[i];
            pattern.items[i].channel[1] = rows_b[i];
            pattern.items[i].channel[2] = rows_c[i];
            pattern.items[i].noise = noise_c.get(i).copied().unwrap_or(0);
            pattern.items[i].envelope = env_a.get(i).copied().unwrap_or(0);
        }

        module.patterns[pat_index] = Some(Box::new(pattern));
    }
    Ok(())
}

/// Decode one channel stream from a PT3 binary blob.
/// Returns (channel_lines, envelope_values, noise_values).
fn decode_channel(data: &[u8], start: usize) -> Result<(Vec<ChannelLine>, Vec<u16>, Vec<u8>)> {
    let mut lines = Vec::new();
    let mut envs = Vec::new();
    let mut noises = Vec::new();
    let mut pos = start;
    let mut cur_line = ChannelLine::default();
    let last_env: u16 = 0;
    let last_noise: u8 = 0;

    loop {
        ensure!(pos < data.len(), "PT3: channel data truncated");
        let b = data[pos];
        pos += 1;

        if b == 0xFF {
            // End of pattern
            lines.push(cur_line);
            envs.push(last_env);
            noises.push(last_noise);
            break;
        }

        if b == 0x00 {
            // End of row
            lines.push(cur_line);
            envs.push(last_env);
            noises.push(last_noise);
            cur_line = ChannelLine::default();
            continue;
        }

        // Simplified decoder — a proper implementation must handle the full
        // PT3 channel bytecode (length prefixes, note encoding, commands, etc.)
        // TODO: complete PT3 bytecode decoder (see PLAN.md §3.3)
        if b < 0x60 {
            cur_line.note = (b as i8) - 1; // rough mapping; full decode needed
        }
    }

    Ok((lines, envs, noises))
}

// ─── Writer ──────────────────────────────────────────────────────────────────

/// Serialise a [`Module`] to a PT3 binary blob.
///
/// **TODO** — stub; see PLAN.md §3.3.
pub fn write(_module: &Module) -> Result<Vec<u8>> {
    bail!("PT3 writer not yet implemented — see PLAN.md §3.3")
}
