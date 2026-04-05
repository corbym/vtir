//! Sound Tracker Compiled (*.stc) binary format parser.
//!
//! Ported from `STC2VTM` in `trfuncs.pas` (c) 2000-2009 S.V.Bulba.

use crate::types::*;
use anyhow::{ensure, Result};

// ─── STC binary layout offsets ───────────────────────────────────────────────
//
// Struct case 3 in TSpeccyModule (trfuncs.pas):
//   ST_Delay              : byte   @ 0
//   ST_PositionsPointer   : word   @ 1
//   ST_OrnamentsPointer   : word   @ 3
//   ST_PatternsPointer    : word   @ 5
//   ST_Name               : array[0..17] of char  @ 7  (18 bytes)
//   ST_Size               : word   @ 25
//
// Samples are at fixed offset $1B (27), 16 entries × $63 (99) bytes each:
//   entry i (0..15) at $1B + i*$63:
//     byte[0]  = STC sample index (maps to VTM sample index+1)
//     bytes[1..96] = 32 ticks × 3 bytes
//     byte[97] = loop_count (l): if 0 → Length=33, Loop=32
//     byte[98] = extra: Loop=l-1, Length=l+extra

const OFF_DELAY: usize = 0;
const OFF_POS_PTR: usize = 1;
const OFF_ORN_PTR: usize = 3;
const OFF_PAT_PTR: usize = 5;
const OFF_NAME: usize = 7; // 18 bytes
const OFF_SIZE: usize = 25;
const SAMPLES_BASE: usize = 0x1B; // 27
const SAMPLE_ENTRY_SIZE: usize = 0x63; // 99

const MIN_FILE_SIZE: usize = SAMPLES_BASE + SAMPLE_ENTRY_SIZE; // need at least 1 sample slot

// Generic title strings that should be cleared (compiled-in defaults)
const GENERIC_TITLES: &[&[u8]] = &[
    b"SONG BY ST COMPILE",
    b"SONG BY MB COMPILE",
    b"SONG BY ST-COMPILE",
    b"SOUND TRACKER v1.1",
    b"S.T.FULL EDITION  ",
    b"SOUND TRACKER v1.3",
];

/// Parse a raw STC binary blob into a [`Module`].
///
/// Ported from `STC2VTM` in `trfuncs.pas`.
pub fn parse(data: &[u8]) -> Result<Module> {
    ensure!(data.len() >= MIN_FILE_SIZE, "STC: file too small");

    let mut module = Module::default();
    module.features_level = FeaturesLevel::Pt35;
    module.vortex_module_header = false;
    module.ton_table = 1;
    module.positions.loop_pos = 0;

    // ── Title ─────────────────────────────────────────────────────────────────
    if data.len() >= OFF_NAME + 18 {
        let raw_name = &data[OFF_NAME..OFF_NAME + 18];
        let is_generic = GENERIC_TITLES.iter().any(|&t| raw_name == t)
            || (raw_name == b"S.T.FULL EDITION \x7F");
        if is_generic {
            module.title = String::new();
        } else {
            let mut title = trim_right_ascii(raw_name);
            // Pascal: if ST_Size != FSize, may append extra chars
            if data.len() >= OFF_SIZE + 2 {
                let st_size = read_word(data, OFF_SIZE) as usize;
                if st_size != data.len() {
                    let lo = (st_size & 0xFF) as u8;
                    if (32..=127).contains(&lo) {
                        title.push(lo as char);
                        let hi = ((st_size >> 8) & 0xFF) as u8;
                        if (32..=127).contains(&hi) {
                            title.push(hi as char);
                        }
                    }
                }
            }
            module.title = title.trim_end().to_string();
        }
    }
    module.author = String::new();
    module.initial_delay = data[OFF_DELAY];

    ensure!(data.len() >= OFF_PAT_PTR + 2, "STC: truncated header");
    let pos_ptr = read_word(data, OFF_POS_PTR) as usize;
    let orn_ptr = read_word(data, OFF_ORN_PTR) as usize;
    let pat_ptr = read_word(data, OFF_PAT_PTR) as usize;

    // ─── Tracking ─────────────────────────────────────────────────────────────
    let mut is_ornament = [false; 16]; // indices 0..15
    let mut is_sample = [false; 17]; // indices 1..16
    let mut orn2sam = [0u8; 16]; // ornament → sample (1-based)
    let mut c_sam = [0u8; 3];
    let mut c_orn = [0u8; 3];

    // ── Positions (count + pairs of [pattern_num, transposition]) ────────────
    // Pascal: while Pos <= STC.Index[ST_PositionsPointer]
    //   CPat.Numb = Index[pos_ptr+1+Pos*2]
    //   CPat.Trans = Index[pos_ptr+2+Pos*2]
    if pos_ptr >= data.len() {
        module.positions.length = 0;
        return Ok(module);
    }
    let num_pos_entries = data[pos_ptr] as usize;
    let mut vtm_pat_max = 0usize; // next free VTM pattern slot
    let mut pats: Vec<(usize, i32)> = Vec::new(); // (stc_num, trans)

    let mut pos = 0usize;
    while pos <= num_pos_entries {
        // Guard: positions.value has MAX_NUM_OF_PATS slots (indices 0..MAX_NUM_OF_PATS-1).
        // The pre-check in ay.rs enforces num_pos_entries < MAX_NUM_OF_PATS, but we add a
        // runtime guard here too so a direct call to stc::parse cannot panic on bad data.
        if pos >= crate::MAX_NUM_OF_PATS {
            break;
        }
        let numb_off = pos_ptr + 1 + pos * 2;
        let trans_off = pos_ptr + 2 + pos * 2;
        if trans_off >= data.len() {
            break;
        }
        let stc_numb = data[numb_off] as usize;
        let trans = data[trans_off] as i32;

        // Find or create VTM pattern slot for (stc_numb, trans) combination
        let j = if let Some(idx) =
            pats.iter().position(|&(n, t)| n == stc_numb && t == trans)
        {
            idx
        } else {
            let idx = vtm_pat_max;
            vtm_pat_max += 1;
            pats.push((stc_numb, trans));
            idx
        };
        // Guard: patterns has MAX_NUM_OF_PATS+1 slots (indices 0..MAX_NUM_OF_PATS).
        if j > crate::MAX_NUM_OF_PATS {
            pos += 1;
            continue;
        }
        module.positions.value[pos] = j;
        pos += 1;

        if module.patterns[j].is_none() {
            let pattern = decode_pattern(
                data,
                pat_ptr,
                stc_numb,
                trans,
                j,
                &mut is_ornament,
                &mut is_sample,
                &mut orn2sam,
                &mut c_sam,
                &mut c_orn,
            );
            module.patterns[j] = Some(Box::new(pattern));
        }
    }
    module.positions.length = pos;

    // ── Ornaments ─────────────────────────────────────────────────────────────
    // Ornament table at orn_ptr: entries of $21 (33) bytes each:
    //   byte[0] = ornament index (1-15)
    //   bytes[1..32] = 32 note offsets (signed)
    // Loop/length derived from the paired sample (via orn2sam).
    for i in 0..16usize {
        let entry_off = orn_ptr + 0x21 * i;
        if entry_off >= data.len() {
            break;
        }
        let orn_idx = data[entry_off] as usize;
        if orn_idx == 0 || orn_idx > 15 || !is_ornament[orn_idx] {
            continue;
        }
        is_ornament[orn_idx] = false; // mark processed

        let mut orn = Ornament::default();
        // Get loop info from associated sample
        let k = orn2sam[orn_idx] as usize; // 1-based sample idx, 0=none
        let mut l = 0usize;
        if k > 0 {
            // Find the STC sample entry whose first byte == k-1
            let target = (k - 1) as u8;
            for n in 0..16usize {
                if SAMPLES_BASE + SAMPLE_ENTRY_SIZE * n >= data.len() {
                    break;
                }
                if data[SAMPLES_BASE + SAMPLE_ENTRY_SIZE * n] == target {
                    l = data[SAMPLES_BASE + SAMPLE_ENTRY_SIZE * n + 0x61] as usize;
                    break;
                }
            }
        }

        if l == 0 {
            orn.loop_pos = 0;
            orn.length = 32;
        } else {
            orn.loop_pos = (l - 1).min(31);
            let extra = if SAMPLES_BASE + SAMPLE_ENTRY_SIZE * (k.saturating_sub(1)) + 0x62
                < data.len()
            {
                // find sample n again for extra byte
                let target = (k - 1) as u8;
                let mut ext = 0usize;
                for n in 0..16usize {
                    if SAMPLES_BASE + SAMPLE_ENTRY_SIZE * n >= data.len() {
                        break;
                    }
                    if data[SAMPLES_BASE + SAMPLE_ENTRY_SIZE * n] == target {
                        ext = data[SAMPLES_BASE + SAMPLE_ENTRY_SIZE * n + 0x62] as usize;
                        break;
                    }
                }
                ext
            } else {
                0
            };
            orn.length = (l + extra).min(32);
            if orn.length == 0 {
                orn.length = 1;
            }
            if orn.loop_pos >= orn.length {
                orn.loop_pos = orn.length - 1;
            }
            let lp = orn.loop_pos + 1;
            if orn.length < 32 {
                // Extend to fill: items[32..Length-1] repeat from loop
                orn.length += 33 - lp;
                orn.loop_pos = 32;
            }
        }

        // Copy 32 ornament bytes from entry
        for k in 0..32usize {
            let off = entry_off + 1 + k;
            orn.items[k] = *data.get(off).unwrap_or(&0) as i8;
        }
        // Fill extended positions by repeating from loop
        if orn.loop_pos == 32 && orn.length > 32 {
            let lp = if l > 0 { (l - 1).min(31) + 1 } else { 1 };
            for k in 32..orn.length {
                orn.items[k] = orn.items[k + lp - 33];
            }
        }
        module.ornaments[orn_idx] = Some(Box::new(orn));
    }

    // ── Samples ───────────────────────────────────────────────────────────────
    // Samples stored at fixed SAMPLES_BASE, 16 entries × SAMPLE_ENTRY_SIZE bytes.
    for i in 0..16usize {
        let entry = SAMPLES_BASE + SAMPLE_ENTRY_SIZE * i;
        if entry + SAMPLE_ENTRY_SIZE > data.len() {
            break;
        }
        let vtm_sam_idx = data[entry] as usize + 1; // STC idx + 1 = VTM idx
        if vtm_sam_idx == 0 || vtm_sam_idx > 16 || !is_sample[vtm_sam_idx] {
            continue;
        }
        is_sample[vtm_sam_idx] = false;

        let mut sam = Sample::default();
        let l = data[entry + 0x61] as usize;
        if l == 0 {
            sam.length = 33;
            sam.loop_pos = 32;
        } else {
            sam.loop_pos = ((l - 1).min(31)) as u8;
            let extra = data[entry + 0x62] as usize;
            sam.length = ((l + extra).min(32)) as u8;
            if sam.length == 0 {
                sam.length = 1;
            }
            if sam.loop_pos >= sam.length {
                sam.loop_pos = sam.length - 1;
            }
            let lp = sam.loop_pos as usize + 1;
            if (sam.length as usize) < 32 {
                sam.length = (sam.length as usize + 33 - lp) as u8;
                sam.loop_pos = 32;
            }
        }

        // Fill 32 tick entries from the fixed area
        for k in 0..32usize {
            let base = entry + 1 + k * 3;
            let b0 = *data.get(base).unwrap_or(&0);
            let b1 = *data.get(base + 1).unwrap_or(&0);
            let b2 = *data.get(base + 2).unwrap_or(&0);
            let tick = &mut sam.items[k];
            tick.envelope_enabled = true;
            // add_to_ton: b2 + (b0[7:4] shl 4) shl 4 = b2 + word(b0 and $F0) shl 4
            let raw_ton = (b2 as u16) | (((b0 & 0xF0) as u16) << 4);
            tick.add_to_ton = if (b1 & 0x20) == 0 {
                -(raw_ton as i16)
            } else {
                raw_ton as i16
            };
            tick.amplitude = b0 & 0x0F;
            tick.mixer_noise = (b1 & 0x80) == 0;
            if tick.mixer_noise {
                let raw = b1 & 0x1F;
                tick.add_to_envelope_or_noise = if (raw & 0x10) != 0 {
                    (raw | 0xF0) as i8
                } else {
                    raw as i8
                };
            }
            tick.mixer_ton = (b1 & 0x40) == 0;
        }

        // Fill extended positions (32..length-1) by repeating from loop
        if sam.loop_pos == 32 && sam.length > 33 {
            // l was the original loop count (before extension)
            let lp = if l > 0 { (l - 1).min(31) + 1 } else { 1 };
            for k in 32..sam.length as usize {
                sam.items[k] = sam.items[k + lp - 33];
            }
        }
        if l == 0 {
            sam.items[32] = SampleTick::default();
        }

        module.samples[vtm_sam_idx] = Some(Box::new(sam));
    }

    Ok(module)
}

// ─── Pattern decoder ──────────────────────────────────────────────────────────

#[allow(clippy::too_many_arguments)]
fn decode_pattern(
    data: &[u8],
    pat_ptr: usize,
    stc_numb: usize,
    trans: i32,
    vtm_idx: usize,
    is_ornament: &mut [bool; 16],
    is_sample: &mut [bool; 17],
    orn2sam: &mut [u8; 16],
    c_sam: &mut [u8; 3],
    c_orn: &mut [u8; 3],
) -> Pattern {
    // Find pattern entry in table: scan for byte matching stc_numb
    let mut k = 0usize;
    loop {
        let off = pat_ptr + k * 7;
        if off >= data.len() {
            return Pattern::default();
        }
        if data[off] == stc_numb as u8 {
            break;
        }
        k += 1;
        if k > MAX_NUM_OF_PATS {
            return Pattern::default();
        }
    }
    let tbl_off = pat_ptr + k * 7 + 1;
    if tbl_off + 6 > data.len() {
        return Pattern::default();
    }
    let ch_ptrs = [
        read_word(data, tbl_off) as usize,
        read_word(data, tbl_off + 2) as usize,
        read_word(data, tbl_off + 4) as usize,
    ];

    let _ = vtm_idx;
    let mut pattern = Pattern::default();
    let mut ptrs = ch_ptrs;
    let mut skip: [i8; 3] = [0; 3];
    let mut skip_ctr: [i8; 3] = [0; 3];
    let mut i = 0usize;

    'row: loop {
        if i >= MAX_PAT_LEN {
            break;
        }
        for ch in 0..3usize {
            skip_ctr[ch] = skip_ctr[ch].wrapping_sub(1);
            if skip_ctr[ch] >= 0 {
                continue;
            }
            // End-of-pattern: channel A byte == 0xFF
            if ch == 0 && (*data.get(ptrs[0]).unwrap_or(&0xFF) == 0xFF) {
                break 'row;
            }
            interpret_channel(
                data,
                &mut ptrs[ch],
                trans,
                is_ornament,
                is_sample,
                orn2sam,
                &mut c_sam[ch],
                &mut c_orn[ch],
                &mut skip[ch],
                &mut pattern.items[i],
                ch,
            );
            skip_ctr[ch] = skip[ch];
        }
        i += 1;
    }
    pattern.length = i;
    pattern
}

#[allow(clippy::too_many_arguments)]
fn interpret_channel(
    data: &[u8],
    ptr: &mut usize,
    trans: i32,
    is_ornament: &mut [bool; 16],
    is_sample: &mut [bool; 17],
    orn2sam: &mut [u8; 16],
    c_sam: &mut u8,
    c_orn: &mut u8,
    skip: &mut i8,
    row: &mut PatternRow,
    ch: usize,
) {
    let cl = &mut row.channel[ch];
    loop {
        if *ptr >= data.len() {
            break;
        }
        let b = data[*ptr];
        *ptr += 1;
        match b {
            0x00..=0x5F => {
                // note with transposition
                let nt = ((b as i32 + trans).min(0x5F).max(0)) as i8;
                cl.note = nt;
                break;
            }
            0x60..=0x6F => {
                // sample select: $60→1, ..., $6F→16
                let s = b - 0x5F;
                *c_sam = s;
                is_sample[s as usize] = true;
                cl.sample = s;
            }
            0x70..=0x7F => {
                // ornament select: $70→0, $71→1, ..., $7F→15
                let o = b - 0x70;
                *c_orn = o;
                cl.ornament = o;
                cl.envelope = 15;
                is_ornament[o as usize] = true;
            }
            0x80 => {
                // note off
                cl.note = NOTE_SOUND_OFF;
                break;
            }
            0x81 => {
                // end of row (no note change)
                break;
            }
            0x82 => {
                // clear ornament, envelope 15
                cl.ornament = 0;
                cl.envelope = 15;
            }
            0x83..=0x8E => {
                // envelope type + 1-byte period
                cl.envelope = b - 0x80;
                cl.ornament = 0;
                // read 1-byte envelope period
                row.envelope = *data.get(*ptr).unwrap_or(&0) as u16;
                *ptr += 1;
            }
            _ => {
                // $A1+ → skip
                *skip = (b - 0xA1) as i8;
            }
        }
    }
    // Track orn2sam
    if *c_orn > 0 && orn2sam[*c_orn as usize] == 0 {
        orn2sam[*c_orn as usize] = *c_sam;
    }
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

#[inline]
fn read_word(data: &[u8], off: usize) -> u16 {
    let lo = *data.get(off).unwrap_or(&0) as u16;
    let hi = *data.get(off + 1).unwrap_or(&0) as u16;
    lo | (hi << 8)
}

fn trim_right_ascii(bytes: &[u8]) -> String {
    let end = bytes.iter().rposition(|&b| b > 0x20).map_or(0, |i| i + 1);
    String::from_utf8_lossy(&bytes[..end]).to_string()
}
