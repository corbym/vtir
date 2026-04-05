//! Sound Tracker Pro (*.stp) binary format parser.
//!
//! Ported from `STP2VTM` in `trfuncs.pas` (c) 2000-2009 S.V.Bulba.

use crate::types::*;
use anyhow::{ensure, Result};

// ─── STP binary layout offsets ───────────────────────────────────────────────
//
// Struct case 4 in TSpeccyModule (trfuncs.pas):
//   STP_Delay             : byte  @ 0
//   STP_PositionsPointer  : word  @ 1
//   STP_PatternsPointer   : word  @ 3
//   STP_OrnamentsPointer  : word  @ 5
//   STP_SamplesPointer    : word  @ 7
//   STP_Init_Id           : byte  @ 9
//
// KSA Software Compiler V2.0 format: bytes 10..37 = "KSA SOFTWARE COMPILER V2.0  "
// (28 bytes). If detected, title at bytes 38..62 (25 bytes).

const OFF_DELAY: usize = 0;
const OFF_POS_PTR: usize = 1;
const OFF_PAT_PTR: usize = 3;
const OFF_ORN_PTR: usize = 5;
const OFF_SAM_PTR: usize = 7;
const KSA_ID_OFF: usize = 10;
const KSA_ID_LEN: usize = 28;
const KSA_TITLE_OFF: usize = 38;
const KSA_TITLE_LEN: usize = 25;
const KSA_ID: &[u8] = b"KSA SOFTWARE COMPILER V2.0  ";

const MIN_FILE_SIZE: usize = 10;

/// Parse a raw STP binary blob into a [`Module`].
///
/// Ported from `STP2VTM` in `trfuncs.pas`.
pub fn parse(data: &[u8]) -> Result<Module> {
    ensure!(data.len() >= MIN_FILE_SIZE, "STP: file too small");

    let mut module = Module::default();
    module.features_level = FeaturesLevel::Pt35;
    module.vortex_module_header = false;
    module.ton_table = 1;

    // ── KSA metadata detection & title ────────────────────────────────────────
    if data.len() >= KSA_ID_OFF + KSA_ID_LEN
        && &data[KSA_ID_OFF..KSA_ID_OFF + KSA_ID_LEN] == KSA_ID
    {
        if data.len() >= KSA_TITLE_OFF + KSA_TITLE_LEN {
            module.title =
                trim_right_ascii(&data[KSA_TITLE_OFF..KSA_TITLE_OFF + KSA_TITLE_LEN]);
        }
    } else {
        module.title = String::new();
    }
    module.author = String::new();
    module.initial_delay = data[OFF_DELAY];

    ensure!(data.len() >= OFF_SAM_PTR + 2, "STP: truncated header");
    let pos_ptr = read_word(data, OFF_POS_PTR) as usize;
    let pat_ptr = read_word(data, OFF_PAT_PTR) as usize;
    let orn_ptr = read_word(data, OFF_ORN_PTR) as usize;
    let sam_ptr = read_word(data, OFF_SAM_PTR) as usize;

    // ── Positions ─────────────────────────────────────────────────────────────
    // Pascal: num_pos at pos_ptr[0], loop_pos at pos_ptr[1]
    //   then num_pos*2 bytes: [raw_byte/6, transposition]
    //   raw_byte/6 = pattern index (CPat.Numb = Index[pos_ptr+2+Pos*2] div 6)
    if pos_ptr + 1 >= data.len() {
        return Ok(module);
    }
    let num_pos = *data.get(pos_ptr).unwrap_or(&0) as usize;
    module.positions.loop_pos = *data.get(pos_ptr + 1).unwrap_or(&0) as usize;
    if module.positions.loop_pos >= num_pos && num_pos > 0 {
        module.positions.loop_pos = num_pos - 1;
    }

    // Tracking state
    let mut is_ornament = [false; 16];
    let mut is_sample = [false; 16]; // indices 1..15
    let mut gliss: [i8; 3] = [0; 3];
    let mut vtm_pat_max = 0usize;
    let mut pats: Vec<(usize, u8)> = Vec::new(); // (stc_numb, trans)

    let mut pos = 0usize;
    while pos < num_pos {
        let numb_off = pos_ptr + 2 + pos * 2;
        let trans_off = pos_ptr + 3 + pos * 2;
        if trans_off >= data.len() {
            break;
        }
        let raw_numb = *data.get(numb_off).unwrap_or(&0);
        let stc_numb = (raw_numb / 6) as usize;
        let trans = *data.get(trans_off).unwrap_or(&0);

        let j = if let Some(idx) = pats.iter().position(|&(n, t)| n == stc_numb && t == trans) {
            idx
        } else {
            let idx = vtm_pat_max;
            vtm_pat_max += 1;
            pats.push((stc_numb, trans));
            idx
        };
        module.positions.value[pos] = j;
        pos += 1;

        if module.patterns[j].is_none() {
            let pattern = decode_pattern(
                data,
                pat_ptr,
                stc_numb,
                trans,
                &mut is_ornament,
                &mut is_sample,
                &mut gliss,
            );
            module.patterns[j] = Some(Box::new(pattern));
        } else {
            // Already decoded: reset gliss for fresh use
            gliss = [0; 3];
        }
    }
    module.positions.length = pos;

    // ── Ornaments ─────────────────────────────────────────────────────────────
    // Table at orn_ptr: 16 entries × 2 bytes each (LE u16 pointers)
    // Entry i at orn_ptr + i*2 → pointer j
    // At j: loop (u8), length (u8), then length signed bytes
    for i in 1..=15usize {
        if !is_ornament[i] {
            continue;
        }
        let ptr_off = orn_ptr + i * 2;
        if ptr_off + 1 >= data.len() {
            continue;
        }
        let j = read_word(data, ptr_off) as usize;
        if j >= data.len() {
            continue;
        }
        let mut orn = Ornament::default();
        orn.loop_pos = *data.get(j).unwrap_or(&0) as usize;
        let len = *data.get(j + 1).unwrap_or(&0) as usize;
        orn.length = len.min(MAX_ORN_LEN);
        if orn.length == 0 {
            orn.length = 1;
        }
        if orn.loop_pos >= orn.length {
            orn.loop_pos = orn.length - 1;
        }
        for k in 0..orn.length {
            orn.items[k] = *data.get(j + 2 + k).unwrap_or(&0) as i8;
        }
        module.ornaments[i] = Some(Box::new(orn));
    }

    // ── Samples ───────────────────────────────────────────────────────────────
    // Table at sam_ptr: (i-1)*2 offset for sample i → pointer j
    // At j: loop (u8), length (u8), then length * 4 bytes of tick data
    // Tick format (4 bytes):
    //   b0: bits3:0=amplitude, bit4=NOT(mixer_ton), bit7=NOT(mixer_noise)
    //   b1: bit0=envelope_enabled, bits5:1=(add_to_env_or_noise via shr1 and 31)
    //   b2..b3: add_to_ton (LE i16, used directly)
    for i in 1..=15usize {
        if !is_sample[i] {
            continue;
        }
        let ptr_off = sam_ptr + (i - 1) * 2;
        if ptr_off + 1 >= data.len() {
            continue;
        }
        let j = read_word(data, ptr_off) as usize;
        if j + 1 >= data.len() {
            continue;
        }
        let mut sam = Sample::default();
        let raw_loop = data[j] as i8;
        sam.length = *data.get(j + 1).unwrap_or(&0);
        if sam.length == 0 || sam.length as usize > MAX_SAM_LEN {
            sam.length = MAX_SAM_LEN as u8;
        }

        let base = j + 2;
        for k in 0..sam.length as usize {
            let b0 = *data.get(base + k * 4).unwrap_or(&0);
            let b1 = *data.get(base + k * 4 + 1).unwrap_or(&0);
            let ton_lo = *data.get(base + k * 4 + 2).unwrap_or(&0);
            let ton_hi = *data.get(base + k * 4 + 3).unwrap_or(&0);
            let tick = &mut sam.items[k];
            tick.amplitude = b0 & 0x0F;
            tick.mixer_ton = (b0 & 0x10) == 0;
            tick.mixer_noise = (b0 & 0x80) == 0;
            tick.envelope_enabled = (b1 & 0x01) != 0;
            tick.add_to_ton = i16::from_le_bytes([ton_lo, ton_hi]);
            if tick.envelope_enabled || tick.mixer_noise {
                let raw = (b1 >> 1) & 0x1F;
                tick.add_to_envelope_or_noise = if (raw & 0x10) != 0 {
                    (raw | 0xF0) as i8
                } else {
                    raw as i8
                };
            }
        }

        // Pascal: if shortint(Loop) < 0 → loop = length, length++, add empty tick
        sam.loop_pos = if raw_loop < 0 {
            let lp = sam.length;
            sam.length = sam.length.saturating_add(1);
            if sam.length as usize <= MAX_SAM_LEN {
                sam.items[lp as usize] = SampleTick::default();
            }
            lp
        } else {
            raw_loop as u8
        };
        if sam.loop_pos >= sam.length {
            sam.loop_pos = sam.length - 1;
        }

        module.samples[i] = Some(Box::new(sam));
    }

    Ok(module)
}

// ─── Pattern decoder ──────────────────────────────────────────────────────────

fn decode_pattern(
    data: &[u8],
    pat_ptr: usize,
    stc_numb: usize,
    trans: u8,
    is_ornament: &mut [bool; 16],
    is_sample: &mut [bool; 16],
    gliss: &mut [i8; 3],
) -> Pattern {
    let tbl_off = pat_ptr + stc_numb * 6;
    if tbl_off + 6 > data.len() {
        return Pattern::default();
    }
    let ch_ptrs = [
        read_word(data, tbl_off) as usize,
        read_word(data, tbl_off + 2) as usize,
        read_word(data, tbl_off + 4) as usize,
    ];

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
            // End-of-pattern: channel A byte == 0x00
            if ch == 0 && (*data.get(ptrs[0]).unwrap_or(&1) == 0x00) {
                break 'row;
            }
            interpret_channel(
                data,
                &mut ptrs[ch],
                trans,
                is_ornament,
                is_sample,
                &mut gliss[ch],
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
    trans: u8,
    is_ornament: &mut [bool; 16],
    is_sample: &mut [bool; 16],
    gliss: &mut i8,
    skip: &mut i8,
    row: &mut PatternRow,
    ch: usize,
) {
    let cl = &mut row.channel[ch];
    let mut stop_gliss = false;

    loop {
        if *ptr >= data.len() {
            break;
        }
        let b = data[*ptr];
        *ptr += 1;
        match b {
            0x01..=0x60 => {
                // note with transposition
                let nt = ((b as i32 - 1 + trans as i32).min(0x5F).max(0)) as i8;
                cl.note = nt;
                if !stop_gliss {
                    let g = *gliss;
                    if g != 0 && cl.additional_command.number == 0 {
                        cl.additional_command.delay = 1;
                        if g > 0 {
                            cl.additional_command.number = 1;
                            cl.additional_command.parameter = g as u8;
                        } else {
                            cl.additional_command.number = 2;
                            cl.additional_command.parameter = (g as u8).wrapping_neg();
                        }
                    }
                } else {
                    stop_gliss = false;
                    *gliss = 0;
                }
                break;
            }
            0x61..=0x6F => {
                // sample select
                let s = b - 0x60;
                is_sample[s as usize] = true;
                cl.sample = s;
            }
            0x70..=0x7F => {
                // ornament select, stop gliss
                stop_gliss = true;
                let o = b - 0x70;
                cl.ornament = o;
                cl.envelope = 15;
                is_ornament[o as usize] = true;
            }
            0x80..=0xBF => {
                // skip
                *skip = (b - 0x80) as i8;
            }
            0xC0 => {
                // clear envelope (15), clear ornament, stop gliss
                stop_gliss = true;
                cl.envelope = 15;
                cl.ornament = 0;
            }
            0xC1..=0xCF => {
                // envelope type + 1-byte period, stop gliss
                stop_gliss = true;
                cl.envelope = if b == 0xCF { 7 } else { b - 0xC0 };
                row.envelope = *data.get(*ptr).unwrap_or(&0) as u16;
                *ptr += 1;
                cl.ornament = 0;
            }
            0xD0..=0xDF => {
                // note off
                cl.note = NOTE_SOUND_OFF;
                break;
            }
            0xE0..=0xEF => {
                // end of row, no note
                break;
            }
            0xF0 => {
                // gliss set/clear
                let raw = *data.get(*ptr).unwrap_or(&0);
                let p = raw as i8;
                *ptr += 1;
                if p == 0 {
                    stop_gliss = true;
                } else {
                    *gliss = p;
                    cl.additional_command.delay = 1;
                    if p >= 0 {
                        cl.additional_command.number = 1;
                        cl.additional_command.parameter = raw;
                    } else {
                        cl.additional_command.number = 2;
                        cl.additional_command.parameter = raw.wrapping_neg();
                    }
                }
            }
            0xF1..=0xFF => {
                // volume
                cl.volume = (256u16 - b as u16) as u8;
            }
            0x00 => {
                // shouldn't reach here (caught before entering loop)
                break;
            }
        }
    }

    // Post-process: if stop_gliss was set with active gliss, emit stop command
    if stop_gliss && *gliss != 0 {
        *gliss = 0;
        if cl.additional_command.number == 0 {
            cl.additional_command.number = 1;
            cl.additional_command.delay = 0;
            cl.additional_command.parameter = 0;
        }
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
