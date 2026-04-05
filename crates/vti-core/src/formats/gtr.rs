//! Global Tracker (*.gtr) binary format parser.
//!
//! Ported from `GTR2VTM` in `trfuncs.pas` (c) 2000-2009 S.V.Bulba.

use crate::types::*;
use anyhow::{ensure, Result};

// ─── GTR binary layout offsets ───────────────────────────────────────────────
//
// Struct case 11 in TSpeccyModule (trfuncs.pas):
//   GTR_Delay              : byte         @ 0
//   GTR_ID                 : array[0..3]  @ 1  (4 bytes; ID[3]==$10 → GTR 2.x)
//   GTR_Address            : word         @ 5
//   GTR_Name               : array[0..31] @ 7  (32 bytes)
//   GTR_SamplesPointers    : array[0..14] of word  @ 39  (15×2 = 30 bytes)
//   GTR_OrnamentsPointers  : array[0..15] of word  @ 69  (16×2 = 32 bytes)
//   GTR_PatternsPointers   : array[0..31] of {A,B,C: word}  @ 101  (32×6 = 192 bytes)
//   GTR_NumberOfPositions  : byte         @ 293
//   GTR_LoopPosition       : byte         @ 294
//   GTR_Positions          : array[0..N]  @ 295  (raw bytes; pattern = byte/6)

const OFF_DELAY: usize = 0;
const OFF_ID: usize = 1;
const OFF_NAME: usize = 7;
const OFF_SAM_PTRS: usize = 39; // [0..14] × 2
const OFF_ORN_PTRS: usize = 69; // [0..15] × 2
const OFF_PAT_PTRS: usize = 101; // [0..31] × 6
const OFF_NUM_POS: usize = 293;
const OFF_LOOP_POS: usize = 294;
const OFF_POSITIONS: usize = 295;

const MIN_FILE_SIZE: usize = 296;

/// Parse a raw GTR binary blob into a [`Module`].
///
/// Ported from `GTR2VTM` in `trfuncs.pas`.
pub fn parse(data: &[u8]) -> Result<Module> {
    ensure!(data.len() >= MIN_FILE_SIZE, "GTR: file too small");

    let mut module = Module::default();
    module.features_level = FeaturesLevel::Pt35;
    module.vortex_module_header = false;
    module.ton_table = 1;

    // ── Metadata ──────────────────────────────────────────────────────────────
    if data.len() >= OFF_NAME + 32 {
        module.title = trim_right_ascii(&data[OFF_NAME..OFF_NAME + 32]);
    }
    module.author = String::new();
    module.initial_delay = data[OFF_DELAY];
    module.positions.loop_pos = data[OFF_LOOP_POS] as usize;
    let num_positions = data[OFF_NUM_POS] as usize;

    // GTR_ID[3] == 0x10 → GTR 2.x (affects E0 opcode and envelope/ornament handling)
    let gtr2 = data.get(OFF_ID + 3).copied().unwrap_or(0) == 0x10;

    let mut is_ornament = [false; 16]; // indices 1..15
    let mut is_sample = [false; 17]; // indices 1..16

    // ── Positions & Patterns ──────────────────────────────────────────────────
    // Pascal: j := GTR^.GTR_Positions[Pos] div 6
    let mut pos = 0usize;
    while pos < num_positions {
        let pos_off = OFF_POSITIONS + pos;
        if pos_off >= data.len() {
            break;
        }
        let j = data[pos_off] as usize / 6;
        if j > crate::MAX_NUM_OF_PATS {
            pos += 1;
            continue;
        }
        module.positions.value[pos] = j;
        pos += 1;

        if module.patterns[j].is_none() {
            let pat_tbl_off = OFF_PAT_PTRS + j * 6;
            if pat_tbl_off + 6 > data.len() {
                continue;
            }
            let ch_ptrs = [
                read_word(data, pat_tbl_off) as usize,
                read_word(data, pat_tbl_off + 2) as usize,
                read_word(data, pat_tbl_off + 4) as usize,
            ];
            let pattern = decode_pattern(data, ch_ptrs, gtr2, &mut is_ornament, &mut is_sample);
            module.patterns[j] = Some(Box::new(pattern));
        }
    }
    module.positions.length = pos;
    if pos > 0 && module.positions.loop_pos >= pos {
        module.positions.loop_pos = pos - 1;
    }

    // ── Ornaments ─────────────────────────────────────────────────────────────
    // GTR_OrnamentsPointers[0..15] at OFF_ORN_PTRS; indices 1..15 used.
    // At j: [loop: byte, length: byte, items[0..length-1]]
    for i in 1..=15usize {
        if !is_ornament[i] {
            continue;
        }
        let ptr_off = OFF_ORN_PTRS + i * 2;
        if ptr_off + 1 >= data.len() {
            continue;
        }
        let j = read_word(data, ptr_off) as usize;
        if j + 1 >= data.len() {
            continue;
        }
        let mut orn = Ornament::default();
        orn.loop_pos = data[j] as usize;
        let len = data.get(j + 1).copied().unwrap_or(0) as usize;
        orn.length = len.min(MAX_ORN_LEN);
        if orn.length == 0 {
            orn.length = 1;
        }
        if orn.loop_pos >= orn.length {
            orn.loop_pos = orn.length - 1;
        }
        for k in 0..orn.length {
            orn.items[k] = data.get(j + 2 + k).copied().unwrap_or(0) as i8;
        }
        module.ornaments[i] = Some(Box::new(orn));
    }

    // ── Samples ───────────────────────────────────────────────────────────────
    // GTR_SamplesPointers[0..14] at OFF_SAM_PTRS; supports samples 1..15
    // (sample 16 would need index 15, out of range — skip gracefully).
    // At j: [loop_raw: byte, length_raw: byte, ticks: 4 bytes each]
    // loop = loop_raw / 4, length = length_raw / 4
    // Tick bytes: b0=amplitude(3:0), b1=flags/noise, b2-b3=add_to_ton LE
    for i in 1..=15usize {
        if !is_sample[i] {
            continue;
        }
        let ptr_off = OFF_SAM_PTRS + (i - 1) * 2;
        if ptr_off + 1 >= data.len() {
            continue;
        }
        let j = read_word(data, ptr_off) as usize;
        if j + 1 >= data.len() {
            continue;
        }

        let mut sam = Sample::default();
        sam.loop_pos = data[j] / 4;
        let raw_len = data.get(j + 1).copied().unwrap_or(0) / 4;
        sam.length = if raw_len == 0 || raw_len as usize > MAX_SAM_LEN {
            MAX_SAM_LEN as u8
        } else {
            raw_len
        };
        if sam.loop_pos >= sam.length {
            sam.loop_pos = sam.length - 1;
        }

        let base = j + 2;
        for k in 0..sam.length as usize {
            let b0 = data.get(base + k * 4).copied().unwrap_or(0);
            let b1 = data.get(base + k * 4 + 1).copied().unwrap_or(0);
            let ton_lo = data.get(base + k * 4 + 2).copied().unwrap_or(0);
            let ton_hi = data.get(base + k * 4 + 3).copied().unwrap_or(0);
            let tick = &mut sam.items[k];
            tick.amplitude = b0 & 0x0F;
            tick.mixer_ton = (b1 & 0x20) == 0; // bit5=0 → tone on
            tick.mixer_noise = (b1 & 0x40) == 0; // bit6=0 → noise on
            tick.envelope_enabled = (b1 & 0x80) != 0; // bit7=1 → envelope
            tick.add_to_ton = i16::from_le_bytes([ton_lo, ton_hi]);
            if tick.mixer_noise {
                let raw = b1 & 0x1F;
                tick.add_to_envelope_or_noise = if (raw & 0x10) != 0 {
                    (raw | 0xF0) as i8
                } else {
                    raw as i8
                };
            }
        }
        module.samples[i] = Some(Box::new(sam));
    }

    Ok(module)
}

// ─── Pattern decoder ──────────────────────────────────────────────────────────

fn decode_pattern(
    data: &[u8],
    ch_ptrs: [usize; 3],
    gtr2: bool,
    is_ornament: &mut [bool; 16],
    is_sample: &mut [bool; 17],
) -> Pattern {
    let mut pattern = Pattern::default();
    let mut ptrs = ch_ptrs;
    let mut skip_ctr: [i8; 3] = [0; 3];
    let mut c_orn = [0u8; 3];
    let mut env_en = [false; 3];
    let mut env_t = [15u8; 3];
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
            if ch == 0 && data.get(ptrs[0]).copied().unwrap_or(0xFF) == 0xFF {
                break 'row;
            }
            // Pascal: SkipCounter[ChNum] := 0 at start of PatternInterpreter
            let mut this_skip: i8 = 0;
            interpret_channel(
                data,
                &mut ptrs[ch],
                gtr2,
                is_ornament,
                is_sample,
                &mut c_orn[ch],
                &mut env_en[ch],
                &mut env_t[ch],
                &mut this_skip,
                &mut pattern.items[i],
                ch,
            );
            skip_ctr[ch] = this_skip;
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
    gtr2: bool,
    is_ornament: &mut [bool; 16],
    is_sample: &mut [bool; 17],
    c_orn: &mut u8,
    env_en: &mut bool,
    env_t: &mut u8,
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
                cl.note = b as i8;
                break;
            }
            0x60..=0x6F => {
                let i = (b - 0x5F) as usize; // 0x60→1 .. 0x6F→16
                if i <= 16 {
                    is_sample[i] = true;
                }
                cl.sample = b - 0x5F;
            }
            0x70..=0x7F => {
                let i = b - 0x70;
                *c_orn = i;
                if i > 0 {
                    is_ornament[i as usize] = true;
                }
                if *env_en && gtr2 {
                    cl.envelope = *env_t;
                } else {
                    *env_en = false;
                    cl.envelope = 15;
                }
                cl.ornament = i;
            }
            0x80..=0xBF => {
                *skip = (b - 0x80) as i8;
            }
            0xC0..=0xCF => {
                *env_en = true;
                let mut i = b - 0xC0;
                if i == 0 {
                    i = 9;
                } else if i == 15 {
                    i = 7;
                }
                *env_t = i;
                cl.envelope = i;
                cl.ornament = *c_orn;
                let period = data.get(*ptr).copied().unwrap_or(0);
                *ptr += 1;
                row.envelope = period as u16;
            }
            0xD0..=0xDF => {
                // end of row, no note
                break;
            }
            0xE0 => {
                cl.note = NOTE_SOUND_OFF;
                if !gtr2 {
                    break;
                }
                // GTR 2.x: note release + continue reading more opcodes
            }
            0xE1..=0xEF => {
                cl.volume = b - 0xE0;
            }
            _ => {}
        }
    }
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

#[inline]
fn read_word(data: &[u8], off: usize) -> u16 {
    let lo = data.get(off).copied().unwrap_or(0) as u16;
    let hi = data.get(off + 1).copied().unwrap_or(0) as u16;
    lo | (hi << 8)
}

fn trim_right_ascii(bytes: &[u8]) -> String {
    let end = bytes.iter().rposition(|&b| b > 0x20).map_or(0, |i| i + 1);
    String::from_utf8_lossy(&bytes[..end]).to_string()
}
