//! Pro Tracker 2 (*.pt2) binary format parser.
//!
//! Ported from `PT22VTM` in `trfuncs.pas` (c) 2000-2009 S.V.Bulba.

use crate::types::*;
use anyhow::{ensure, Result};

// ─── PT2 binary layout offsets ───────────────────────────────────────────────
//
// Struct case 2 in TSpeccyModule (trfuncs.pas):
//   PT2_Delay             : byte       @ 0
//   PT2_NumberOfPositions : byte       @ 1   (not directly used; list is self-terminating)
//   PT2_LoopPosition      : byte       @ 2
//   PT2_SamplePointers    : array[0..31] of word  @ 3   (64 bytes)
//   PT2_OrnamentPointers  : array[0..15] of word  @ 67  (32 bytes)
//   PT2_PatternsPointer   : word                  @ 99
//   PT2_MusicName         : array[0..29] of char  @ 101 (30 bytes)
//   PT2_PositionList      : array[0..N] of byte   @ 131 (stops when byte >= 128)

const OFF_DELAY: usize = 0;
const OFF_LOOP_POS: usize = 2;
const OFF_SAM_PTRS: usize = 3; // [0..31] × 2 bytes each
const OFF_ORN_PTRS: usize = 67; // [0..15] × 2 bytes each
const OFF_PAT_PTR: usize = 99;
const OFF_TITLE: usize = 101; // 30 bytes
const OFF_POS_LIST: usize = 131;

const MIN_FILE_SIZE: usize = OFF_POS_LIST + 1;

/// Parse a raw PT2 binary blob into a [`Module`].
///
/// Ported from `PT22VTM` in `trfuncs.pas`.
pub fn parse(data: &[u8]) -> Result<Module> {
    ensure!(data.len() >= MIN_FILE_SIZE, "PT2: file too small");

    let mut module = Module::default();
    module.features_level = FeaturesLevel::Pt35;
    module.vortex_module_header = false;
    module.ton_table = 1;

    // ── Title ─────────────────────────────────────────────────────────────────
    if data.len() >= OFF_TITLE + 30 {
        module.title = trim_right_ascii(&data[OFF_TITLE..OFF_TITLE + 30]);
    }
    module.author = String::new();

    // ── Timing ────────────────────────────────────────────────────────────────
    module.initial_delay = data[OFF_DELAY];
    module.positions.loop_pos = data[OFF_LOOP_POS] as usize;

    // ── Patterns pointer ──────────────────────────────────────────────────────
    ensure!(data.len() >= OFF_PAT_PTR + 2, "PT2: truncated header");
    let pat_ptr = read_word(data, OFF_PAT_PTR) as usize;

    // ── Ornaments (indices 1..15) ─────────────────────────────────────────────
    // Pascal: for i := 1 to 15; if PT2.PT2_OrnamentPointers[i] = 0 → nil
    for i in 1..=15usize {
        let ptr_off = OFF_ORN_PTRS + i * 2;
        if ptr_off + 1 >= data.len() {
            break;
        }
        let ptr = read_word(data, ptr_off) as usize;
        if ptr == 0 || ptr + 1 >= data.len() {
            continue;
        }
        let mut orn = Ornament::default();
        orn.length = data[ptr] as usize;
        orn.loop_pos = data[ptr + 1] as usize;
        if orn.length == 0 || orn.length > MAX_ORN_LEN {
            orn.length = MAX_ORN_LEN;
        }
        if orn.loop_pos >= orn.length {
            orn.loop_pos = orn.length - 1;
        }
        for j in 0..orn.length {
            let off = ptr + 2 + j;
            orn.items[j] = *data.get(off).unwrap_or(&0) as i8;
        }
        module.ornaments[i] = Some(Box::new(orn));
    }

    // ── Samples (indices 1..31) ───────────────────────────────────────────────
    // Pascal: for i := 1 to 31; PT2_SamplePointers[i] (note: array[0..31], but 0-index unused)
    // Offset of pointer for sample i: OFF_SAM_PTRS + i*2
    for i in 1..=31usize {
        let ptr_off = OFF_SAM_PTRS + i * 2;
        if ptr_off + 1 >= data.len() {
            break;
        }
        let ptr = read_word(data, ptr_off) as usize;
        if ptr == 0 || ptr + 1 >= data.len() {
            continue;
        }
        let mut sam = Sample::default();
        // Pascal: Length @ ptr[0], Loop @ ptr[1], ticks start at ptr+2, 3 bytes each
        sam.length = data[ptr];
        sam.loop_pos = data[ptr + 1];
        if sam.length == 0 || sam.length as usize > MAX_SAM_LEN {
            sam.length = MAX_SAM_LEN as u8;
        }
        if sam.loop_pos >= sam.length {
            sam.loop_pos = sam.length - 1;
        }
        for j in 0..sam.length as usize {
            // 3-byte tick layout (trfuncs.pas ~2985-3018):
            //   b0 @ ptr+2+j*3  : bit0=NOT(mixer_noise), bit1=NOT(mixer_ton),
            //                     bit2=ton_sign(1=+), bits7:3=(add_to_env_or_noise shr 3) and 31
            //   b1 @ ptr+3+j*3  : bits7:4=amplitude, bits3:0=add_to_ton[11:8]
            //   b2 @ ptr+4+j*3  : add_to_ton[7:0]
            let b0 = *data.get(ptr + 2 + j * 3).unwrap_or(&0);
            let b1 = *data.get(ptr + 3 + j * 3).unwrap_or(&0);
            let b2 = *data.get(ptr + 4 + j * 3).unwrap_or(&0);
            let tick = &mut sam.items[j];
            tick.envelope_enabled = true;
            // add_to_ton: (b1[3:0] shl 8) | b2; negate when b0 bit2 == 0
            let raw_ton = (((b1 & 0x0F) as u16) << 8) | (b2 as u16);
            tick.add_to_ton = if (b0 & 0x04) == 0 {
                -(raw_ton as i16)
            } else {
                raw_ton as i16
            };
            tick.amplitude = b1 >> 4;
            tick.mixer_noise = (b0 & 0x01) == 0;
            if tick.mixer_noise {
                let raw = (b0 >> 3) & 0x1F;
                tick.add_to_envelope_or_noise = if (raw & 0x10) != 0 {
                    (raw | 0xF0) as i8
                } else {
                    raw as i8
                };
            }
            tick.mixer_ton = (b0 & 0x02) == 0;
        }
        module.samples[i] = Some(Box::new(sam));
    }

    // ── Position list & patterns ───────────────────────────────────────────────
    // Pascal: while (Pos < 256) and (PT2.PT2_PositionList[Pos] < 128)
    let mut pos = 0usize;
    while pos < 256 {
        let off = OFF_POS_LIST + pos;
        if off >= data.len() {
            break;
        }
        let b = data[off];
        if b >= 128 {
            break;
        }
        let j = b as usize; // pattern index
        module.positions.value[pos] = j;
        pos += 1;

        if module.patterns[j].is_none() {
            let pattern =
                decode_pattern(data, pat_ptr, j).unwrap_or_else(|_| Pattern::default());
            module.patterns[j] = Some(Box::new(pattern));
        }
    }
    ensure!(pos > 0, "PT2: no positions");
    module.positions.length = pos;

    Ok(module)
}

// ─── Pattern decoder ──────────────────────────────────────────────────────────

fn decode_pattern(data: &[u8], pat_ptr: usize, pat_idx: usize) -> Result<Pattern> {
    let tbl_off = pat_ptr + pat_idx * 6;
    if tbl_off + 6 > data.len() {
        return Ok(Pattern::default());
    }
    let ch_ptrs = [
        read_word(data, tbl_off) as usize,
        read_word(data, tbl_off + 2) as usize,
        read_word(data, tbl_off + 4) as usize,
    ];

    let mut pattern = Pattern::default();
    let mut ptrs = ch_ptrs;
    // Pascal uses shortint (i8) for skip/skipCounter; init 0 → first Dec makes -1 → decode.
    let mut skip: [i8; 3] = [0; 3];
    let mut skip_ctr: [i8; 3] = [0; 3];
    let mut prev_orn: [u8; 3] = [0; 3];
    let mut ns_base: u8 = 0;
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
            // End-of-pattern marker: channel A byte == 0
            if ch == 0 {
                if ptrs[0] >= data.len() || data[ptrs[0]] == 0x00 {
                    break 'row;
                }
            }
            interpret_channel(
                data,
                &mut ptrs[ch],
                &mut prev_orn[ch],
                &mut skip[ch],
                &mut ns_base,
                &mut pattern.items[i],
                ch,
            );
            skip_ctr[ch] = skip[ch];
        }
        pattern.items[i].noise = ns_base;
        i += 1;
    }
    pattern.length = i;
    Ok(pattern)
}

/// Decode one channel's opcodes for one row.
///
/// Ported from the nested `PatternInterpreter` in `PT22VTM` (trfuncs.pas ~2838-2929).
fn interpret_channel(
    data: &[u8],
    ptr: &mut usize,
    prev_orn: &mut u8,
    skip: &mut i8,
    ns_base: &mut u8,
    row: &mut PatternRow,
    ch: usize,
) {
    let cl = &mut row.channel[ch];
    loop {
        if *ptr >= data.len() {
            break;
        }
        let b = data[*ptr];
        match b {
            0xE1..=0xFF => {
                // sample select
                cl.sample = b - 0xE0;
            }
            0xE0 => {
                // note off
                cl.note = NOTE_SOUND_OFF;
                *ptr += 1;
                return;
            }
            0x80..=0xDF => {
                // note
                cl.note = (b - 0x80) as i8;
                *ptr += 1;
                return;
            }
            0x7F => {
                // envelope 15, keep prev ornament
                cl.envelope = 15;
                cl.ornament = *prev_orn;
            }
            0x71..=0x7E => {
                // envelope type + period
                cl.ornament = *prev_orn;
                cl.envelope = b - 0x70;
                *ptr += 1; // move to low byte of period
                if *ptr + 1 < data.len() {
                    row.envelope = read_word(data, *ptr);
                    *ptr += 1; // consumed 2 bytes (the Inc(ChPtr,1) then global Inc adds one more)
                }
            }
            0x70 => {
                // end of row, no note
                *ptr += 1;
                return;
            }
            0x60..=0x6F => {
                // ornament select
                *prev_orn = b - 0x60;
                cl.ornament = *prev_orn;
                if cl.envelope == 0 {
                    cl.envelope = 15;
                }
            }
            0x20..=0x5F => {
                // skip
                *skip = (b - 0x20) as i8;
            }
            0x10..=0x1F => {
                // volume
                cl.volume = b - 0x10;
            }
            0x0F => {
                // noise mask command (cmd 11)
                cl.additional_command.number = 11;
                *ptr += 1;
                cl.additional_command.parameter = *data.get(*ptr).unwrap_or(&0);
            }
            0x0E => {
                // glide up/down (cmd 1 or 2)
                cl.additional_command.delay = 1;
                *ptr += 1;
                let raw = *data.get(*ptr).unwrap_or(&0);
                let p = raw as i8;
                if p >= 0 {
                    cl.additional_command.number = 1;
                    cl.additional_command.parameter = raw;
                } else {
                    cl.additional_command.number = 2;
                    cl.additional_command.parameter = raw.wrapping_neg();
                }
            }
            0x0D => {
                // tone slide (cmd 3)
                cl.additional_command.delay = 1;
                cl.additional_command.number = 3;
                *ptr += 1;
                let raw = *data.get(*ptr).unwrap_or(&0);
                let p = raw as i8;
                cl.additional_command.parameter = if p >= 0 { raw } else { raw.wrapping_neg() };
                *ptr += 2;
            }
            0x0C => {
                // stop glide (cmd 1, delay 0, param 0)
                cl.additional_command.delay = 0;
                cl.additional_command.number = 1;
                cl.additional_command.parameter = 0;
            }
            _ => {
                // default: advance ptr, then read ns_base byte
                *ptr += 1;
                *ns_base = *data.get(*ptr).unwrap_or(&0);
            }
        }
        *ptr += 1;
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
