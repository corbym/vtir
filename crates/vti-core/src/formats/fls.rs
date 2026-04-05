//! Flying Ledger Sound (*.fls) binary format parser.
//!
//! Ported from `FLS2VTM` in `trfuncs.pas` (c) 2000-2009 S.V.Bulba.

use crate::types::*;
use anyhow::{ensure, Result};

// ─── FLS binary layout offsets ───────────────────────────────────────────────
//
// Struct case 9 in TSpeccyModule (trfuncs.pas):
//   FLS_PositionsPointer  : word  @ 0
//   FLS_OrnamentsPointer  : word  @ 2
//   FLS_SamplesPointer    : word  @ 4
//   FLS_PatternsPointers  : array[1..N] of {A, B, C: word}  @ 6
//     (1-indexed; index j at offset j*6)
//
// Position table at FLS_PositionsPointer:
//   [0]     : initial delay
//   [1+pos] : pattern index (1-based); 0 = terminator
//
// Ornament pointer table at FLS_OrnamentsPointer + (i-1)*2:
//   LE word → absolute address of ornament data (32 signed bytes)
//
// Sample table at FLS_SamplesPointer + (i-1)*4:
//   [0]   : loop count (l)
//   [1]   : extra count
//   [2-3] : LE word → absolute address of sample tick data
//
// Sample tick format (3 bytes each, same as STC/PT1):
//   b0: amplitude(3:0), ton_hi(7:4)
//   b1: NOT(mixer_noise)(7), NOT(mixer_ton)(6), ton_sign(5), noise_add(4:0)
//   b2: ton_lo

const OFF_POS_PTR: usize = 0;
const OFF_ORN_PTR: usize = 2;
const OFF_SAM_PTR: usize = 4;
const OFF_PAT_PTRS: usize = 6; // 1-indexed: index j at j*6

const MIN_FILE_SIZE: usize = 64; // enough for a minimal-header file

/// Parse a raw FLS binary blob into a [`Module`].
///
/// Ported from `FLS2VTM` in `trfuncs.pas`.
pub fn parse(data: &[u8]) -> Result<Module> {
    ensure!(data.len() >= MIN_FILE_SIZE, "FLS: file too small");

    let mut module = Module::default();
    module.features_level = FeaturesLevel::Pt35;
    module.vortex_module_header = false;
    module.ton_table = 1;
    module.title = String::new();
    module.author = String::new();
    module.positions.loop_pos = 0;

    let pos_ptr = read_word(data, OFF_POS_PTR) as usize;
    let orn_ptr = read_word(data, OFF_ORN_PTR) as usize;
    let sam_ptr = read_word(data, OFF_SAM_PTR) as usize;

    if pos_ptr >= data.len() {
        return Ok(module);
    }

    module.initial_delay = data.get(pos_ptr).copied().unwrap_or(0);

    // ── Ornament/sample cross-reference ───────────────────────────────────────
    let mut is_ornament = [false; 16]; // indices 1..15
    let mut is_sample = [false; 17]; // indices 1..16
    let mut orn2sam = [0u8; 16]; // ornament → last paired sample (1-based, 0=none)
    let mut c_sam = [0u8; 3];
    let mut c_orn = [0u8; 3];

    // ── Positions & Patterns ──────────────────────────────────────────────────
    // Pascal: j := FLS^.Index[Pos + FLS_PositionsPointer + 1]; loop while j != 0
    let mut pos = 0usize;
    loop {
        if pos >= 256 {
            break;
        }
        let j_off = pos_ptr + 1 + pos;
        if j_off >= data.len() {
            break;
        }
        let j = data[j_off] as usize;
        if j == 0 {
            break; // terminator
        }
        if j > crate::MAX_NUM_OF_PATS {
            pos += 1;
            continue;
        }
        module.positions.value[pos] = j;
        pos += 1;

        if module.patterns[j].is_none() {
            // Pattern channel pointers: FLS_PatternsPointers[j] at offset j*6
            let pat_tbl_off = j * 6;
            if pat_tbl_off + 6 > data.len() {
                continue;
            }
            let ch_ptrs = [
                read_word(data, pat_tbl_off) as usize,
                read_word(data, pat_tbl_off + 2) as usize,
                read_word(data, pat_tbl_off + 4) as usize,
            ];
            let pattern = decode_pattern(
                data,
                ch_ptrs,
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
    // Loop/length derived from paired sample (Orn2Sam[i]).
    // Pascal:
    //   k := Orn2Sam[i] - 1  (0-based sample index, -1 = none)
    //   j := sam_ptr + k*4   (sample table entry)
    //   l := FLS.Index[j]    (loop count of associated sample)
    //   Extra := FLS.Index[j+1]
    //   then compute loop/length same as sample...
    //   then ornament data from: word at orn_ptr+(i-1)*2 → absolute pointer j
    for i in 1..=15usize {
        if !is_ornament[i] {
            continue;
        }
        let k = orn2sam[i] as isize - 1; // 0-based sample index (-1 = none)

        let (orn_loop, orn_length) = if k >= 0 {
            let k = k as usize;
            let sam_entry = sam_ptr + k * 4;
            let l = data.get(sam_entry).copied().unwrap_or(0) as usize;
            if l == 0 {
                (0usize, 32usize)
            } else {
                let mut lp = l.saturating_sub(1).min(31);
                let extra = data.get(sam_entry + 1).copied().unwrap_or(0) as usize;
                let mut len = (l.saturating_sub(1) + extra).min(32);
                if len == 0 {
                    len = 1;
                }
                if lp >= len {
                    lp = len - 1;
                }
                let lp1 = lp + 1;
                if len < 32 {
                    // Extend
                    (32usize, 32 + len - lp1 + 1)
                } else {
                    (lp, 32)
                }
            }
        } else {
            (0, 32)
        };

        // Ornament data pointer
        let ptr_off = orn_ptr + (i - 1) * 2;
        if ptr_off + 1 >= data.len() {
            continue;
        }
        let j = read_word(data, ptr_off) as usize;

        let mut orn = Ornament::default();
        orn.loop_pos = orn_loop;
        orn.length = orn_length.min(MAX_ORN_LEN);
        if orn.length == 0 {
            orn.length = 1;
        }
        if orn.loop_pos >= orn.length {
            orn.loop_pos = orn.length - 1;
        }

        // First 32 items from data
        for kk in 0..32usize.min(orn.length) {
            orn.items[kk] = data.get(j + kk).copied().unwrap_or(0) as i8;
        }
        // Extended items: repeat from loop (Pascal: Items[k] := Items[k + lp - 33])
        // Here lp is the original loop position (before extension)
        if orn.loop_pos == 32 {
            let lp1 = if k >= 0 {
                let k = k as usize;
                let sam_entry = sam_ptr + k * 4;
                let l = data.get(sam_entry).copied().unwrap_or(0) as usize;
                if l > 0 {
                    (l.saturating_sub(1).min(31)) + 1
                } else {
                    1
                }
            } else {
                1
            };
            for kk in 32..orn.length {
                orn.items[kk] = orn.items[kk + lp1 - 33];
            }
        }

        module.ornaments[i] = Some(Box::new(orn));
    }

    // ── Samples ───────────────────────────────────────────────────────────────
    // Sample table at sam_ptr + (i-1)*4:
    //   [0]: l (loop count)
    //   [1]: extra
    //   [2-3]: LE word → absolute address of tick data
    for i in 1..=16usize {
        if !is_sample[i] {
            continue;
        }
        let entry = sam_ptr + (i - 1) * 4;
        if entry + 3 >= data.len() {
            continue;
        }
        let l = data[entry] as usize;
        let extra = data[entry + 1] as usize;
        let tick_ptr = read_word(data, entry + 2) as usize;
        if tick_ptr + 3 > data.len() {
            continue;
        }

        let mut sam = Sample::default();
        if l == 0 {
            sam.length = 33;
            sam.loop_pos = 32;
        } else {
            let mut lp = l.saturating_sub(1);
            if lp > 31 {
                lp = 31;
            }
            let mut len = lp + extra;
            if len > 32 {
                len = 32;
            }
            if len == 0 {
                len = 1;
            }
            if lp >= len {
                // Pascal uses sam_ptr+j (wrong index?) — mirror faithfully with safe clamp
                lp = len.saturating_sub(1);
            }
            sam.loop_pos = lp as u8;
            sam.length = len as u8;
            let lp1 = lp + 1;
            if len < 32 {
                sam.length = (len + 33 - lp1) as u8;
                sam.loop_pos = 32;
            }
        }

        // 32 ticks (3 bytes each), same format as STC/PT1
        for k in 0..32usize {
            let base = tick_ptr + k * 3;
            let b0 = data.get(base).copied().unwrap_or(0);
            let b1 = data.get(base + 1).copied().unwrap_or(0);
            let b2 = data.get(base + 2).copied().unwrap_or(0);
            let tick = &mut sam.items[k];
            tick.envelope_enabled = true;
            tick.amplitude = b0 & 0x0F;
            tick.mixer_noise = (b1 & 0x80) == 0; // bit7=0 → noise on
            if tick.mixer_noise {
                let raw = b1 & 0x1F;
                tick.add_to_envelope_or_noise = if (raw & 0x10) != 0 {
                    (raw | 0xF0) as i8
                } else {
                    raw as i8
                };
            }
            tick.mixer_ton = (b1 & 0x40) == 0; // bit6=0 → tone on
            let raw_ton = (((b0 & 0xF0) as u16) << 4) | (b2 as u16);
            tick.add_to_ton = if (b1 & 0x20) == 0 {
                -(raw_ton as i16)
            } else {
                raw_ton as i16
            };
        }

        // Extended ticks (loop region)
        if sam.loop_pos == 32 && sam.length > 33 {
            let lp1 = if l > 0 {
                l.saturating_sub(1).min(31) + 1
            } else {
                1
            };
            for k in 32..sam.length as usize {
                sam.items[k] = sam.items[k + lp1 - 33];
            }
        }
        if l == 0 {
            sam.items[32] = SampleTick::default();
        }

        module.samples[i] = Some(Box::new(sam));
    }

    Ok(module)
}

// ─── Pattern decoder ──────────────────────────────────────────────────────────

#[allow(clippy::too_many_arguments)]
fn decode_pattern(
    data: &[u8],
    ch_ptrs: [usize; 3],
    is_ornament: &mut [bool; 16],
    is_sample: &mut [bool; 17],
    orn2sam: &mut [u8; 16],
    c_sam: &mut [u8; 3],
    c_orn: &mut [u8; 3],
) -> Pattern {
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
            if ch == 0 && data.get(ptrs[0]).copied().unwrap_or(0xFF) == 0xFF {
                break 'row;
            }
            interpret_channel(
                data,
                &mut ptrs[ch],
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
    let mut quit = false;
    while !quit {
        if *ptr >= data.len() {
            break;
        }
        let b = data[*ptr];
        *ptr += 1;
        match b {
            0x00..=0x5F => {
                cl.note = b as i8;
                quit = true;
            }
            0x60..=0x6F => {
                // sample select: 0x60→1 .. 0x6F→16
                let s = (b - 0x5F) as usize;
                *c_sam = b - 0x5F;
                if s <= 16 {
                    is_sample[s] = true;
                }
                cl.sample = b - 0x5F;
            }
            0x70 => {
                // clear ornament
                *c_orn = 0;
                cl.envelope = 15;
                cl.ornament = 0;
            }
            0x71..=0x7F => {
                // ornament select: 0x71→1 .. 0x7F→15
                let o = b - 0x70;
                *c_orn = o;
                is_ornament[o as usize] = true;
                cl.envelope = 15;
                cl.ornament = o;
            }
            0x80 => {
                cl.note = NOTE_SOUND_OFF;
                quit = true;
            }
            0x81 => {
                // end of row, no note
                quit = true;
            }
            0x82..=0x8E => {
                // envelope type + 1-byte period
                cl.envelope = b - 0x80;
                cl.ornament = 0;
                let period = data.get(*ptr).copied().unwrap_or(0);
                *ptr += 1;
                row.envelope = period as u16;
            }
            _ => {
                // $A1+ → skip counter = byte - $A1
                *skip = (b - 0xA1) as i8;
            }
        }
    }
    // Pascal: if (COrn[ch] > 0) and (Orn2Sam[COrn[ch]] = 0) then Orn2Sam[...] := CSam
    if *c_orn > 0 && orn2sam[*c_orn as usize] == 0 {
        orn2sam[*c_orn as usize] = *c_sam;
    }
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

#[inline]
fn read_word(data: &[u8], off: usize) -> u16 {
    let lo = data.get(off).copied().unwrap_or(0) as u16;
    let hi = data.get(off + 1).copied().unwrap_or(0) as u16;
    lo | (hi << 8)
}
