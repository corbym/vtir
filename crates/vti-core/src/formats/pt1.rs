//! Pro Tracker 1 (*.pt1) binary format parser.
//!
//! Ported from `PT12VTM` in `trfuncs.pas` (c) 2000-2009 S.V.Bulba.

use crate::types::*;
use anyhow::{ensure, Result};

// ─── PT1 binary layout offsets ───────────────────────────────────────────────
//
// Struct case 10 in TSpeccyModule (trfuncs.pas):
//   PT1_Delay              : byte         @ 0
//   PT1_NumberOfPositions  : byte         @ 1
//   PT1_LoopPosition       : byte         @ 2
//   PT1_SamplesPointers    : array[0..15] of word  @ 3  (32 bytes)
//   PT1_OrnamentsPointers  : array[0..15] of word  @ 35 (32 bytes)
//   PT1_PatternsPointer    : word                  @ 67
//   PT1_MusicName          : array[0..29] of char  @ 69 (30 bytes)
//   PT1_PositionList       : array[0..N] of byte   @ 99

const OFF_DELAY: usize = 0;
const OFF_NUM_POS: usize = 1;
const OFF_LOOP_POS: usize = 2;
const OFF_SAM_PTRS: usize = 3; // [0..15] × 2 bytes
const OFF_ORN_PTRS: usize = 35; // [0..15] × 2 bytes
const OFF_PAT_PTR: usize = 67;
const OFF_TITLE: usize = 69; // 30 bytes
const OFF_POS_LIST: usize = 99;

const MIN_FILE_SIZE: usize = OFF_POS_LIST + 1;

/// Parse a raw PT1 binary blob into a [`Module`].
///
/// Ported from `PT12VTM` in `trfuncs.pas`.
pub fn parse(data: &[u8]) -> Result<Module> {
    ensure!(data.len() >= MIN_FILE_SIZE, "PT1: file too small");

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
    let num_positions = data[OFF_NUM_POS] as usize;

    ensure!(data.len() >= OFF_PAT_PTR + 2, "PT1: truncated header");
    let pat_ptr = read_word(data, OFF_PAT_PTR) as usize;

    // ─── Tracking state for ornament/sample cross-referencing ────────────────
    // Pascal: Orn2Sam[i] = sample index (1-based) that ornament i was last used with
    let mut is_ornament = [false; 16]; // indices 1..15
    let mut is_sample = [false; 17]; // indices 1..16
    let mut orn2sam = [0u8; 16]; // orn → sample (1-based, 0 = none)
    let mut c_sam = [0u8; 3]; // current sample per channel
    let mut c_orn = [0u8; 3]; // current ornament per channel

    // ── Positions & patterns ──────────────────────────────────────────────────
    let mut pos = 0usize;
    while pos < num_positions {
        let off = OFF_POS_LIST + pos;
        if off >= data.len() {
            break;
        }
        let j = data[off] as usize; // pattern index
        // Guard: patterns has MAX_NUM_OF_PATS+1 slots (indices 0..MAX_NUM_OF_PATS).
        // A direct pt1::parse call with malformed data could supply j > MAX_NUM_OF_PATS,
        // which would panic on the Vec index below.  Skip invalid entries instead.
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
    ensure!(pos > 0, "PT1: no positions");
    module.positions.length = pos;

    // ── Ornaments (only those referenced in patterns) ─────────────────────────
    // Pascal: ornament length/loop comes from the paired sample's pointer header
    for i in 1..=15usize {
        if !is_ornament[i] {
            continue;
        }
        let orn_ptr_off = OFF_ORN_PTRS + i * 2;
        if orn_ptr_off + 1 >= data.len() {
            continue;
        }
        let orn_ptr = read_word(data, orn_ptr_off) as usize;

        let mut orn = Ornament::default();
        // Length/loop from associated sample header (Orn2Sam[i] is 1-based sample idx)
        let k = orn2sam[i] as usize; // 1-based, 0 = none
        if k > 0 {
            let sam_ptr_off = OFF_SAM_PTRS + (k - 1) * 2;
            if sam_ptr_off + 1 < data.len() {
                let sam_ptr = read_word(data, sam_ptr_off) as usize;
                if sam_ptr + 1 < data.len() {
                    orn.length = data[sam_ptr] as usize;
                    orn.loop_pos = data[sam_ptr + 1] as usize;
                }
            }
        }
        if orn.length == 0 {
            orn.length = 32;
            orn.loop_pos = 0;
        }
        if orn.loop_pos >= orn.length {
            orn.loop_pos = orn.length - 1;
        }
        for j in 0..orn.length {
            let off = orn_ptr + j;
            orn.items[j] = *data.get(off).unwrap_or(&0) as i8;
        }
        module.ornaments[i] = Some(Box::new(orn));
    }

    // ── Samples (only those referenced in patterns) ───────────────────────────
    // Pascal: for i := 1 to 16; PT1_SamplesPointers[i-1] → ptr; ticks at ptr+2
    for i in 1..=16usize {
        if !is_sample[i] {
            continue;
        }
        let sam_ptr_off = OFF_SAM_PTRS + (i - 1) * 2;
        if sam_ptr_off + 1 >= data.len() {
            continue;
        }
        let sam_ptr = read_word(data, sam_ptr_off) as usize;
        if sam_ptr + 1 >= data.len() {
            continue;
        }
        let mut sam = Sample::default();
        sam.length = data[sam_ptr];
        sam.loop_pos = data[sam_ptr + 1];
        if sam.length == 0 || sam.length as usize > MAX_SAM_LEN {
            sam.length = MAX_SAM_LEN as u8;
        }
        if sam.loop_pos >= sam.length {
            sam.loop_pos = sam.length - 1;
        }
        let base = sam_ptr + 2;
        for j in 0..sam.length as usize {
            // 3-byte tick layout (trfuncs.pas ~6007-6037):
            //   b0 @ base+j*3   : bits7:4 = ton_hi (MSBs of add_to_ton), bits3:0 = amplitude
            //   b1 @ base+j*3+1 : bit7=NOT(mixer_noise), bit6=NOT(mixer_ton),
            //                     bit5=ton_sign(1=+,0=-), bits4:0=add_to_env_or_noise (5-bit)
            //   b2 @ base+j*3+2 : ton_lo
            let b0 = *data.get(base + j * 3).unwrap_or(&0);
            let b1 = *data.get(base + j * 3 + 1).unwrap_or(&0);
            let b2 = *data.get(base + j * 3 + 2).unwrap_or(&0);
            let tick = &mut sam.items[j];
            tick.envelope_enabled = true;
            let raw_ton = (((b0 & 0xF0) as u16) << 4) | (b2 as u16);
            tick.add_to_ton = if (b1 & 0x20) == 0 {
                -(raw_ton as i16)
            } else {
                raw_ton as i16
            };
            tick.amplitude = b0 & 0x0F;
            tick.mixer_noise = (b1 & 0x80) == 0; // bit7 = NOT(mixer_noise)
            if tick.mixer_noise {
                let raw = b1 & 0x1F;
                tick.add_to_envelope_or_noise = if (raw & 0x10) != 0 {
                    (raw | 0xF0) as i8
                } else {
                    raw as i8
                };
            }
            tick.mixer_ton = (b1 & 0x40) == 0; // bit6 = NOT(mixer_ton)
        }
        module.samples[i] = Some(Box::new(sam));
    }

    Ok(module)
}

// ─── Pattern decoder ──────────────────────────────────────────────────────────

#[allow(clippy::too_many_arguments)]
fn decode_pattern(
    data: &[u8],
    pat_ptr: usize,
    pat_idx: usize,
    is_ornament: &mut [bool; 16],
    is_sample: &mut [bool; 17],
    orn2sam: &mut [u8; 16],
    c_sam: &mut [u8; 3],
    c_orn: &mut [u8; 3],
) -> Pattern {
    let tbl_off = pat_ptr + pat_idx * 6;
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
            // End-of-pattern: channel A byte == 0xFF
            if ch == 0 && (*data.get(ptrs[0]).unwrap_or(&0xFF) == 0xFF) {
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
    loop {
        if *ptr >= data.len() {
            break;
        }
        let b = data[*ptr];
        *ptr += 1;
        match b {
            0x00..=0x5F => {
                // note
                cl.note = b as i8;
                break;
            }
            0x60..=0x6F => {
                // sample select: samples 1..16
                let s = b - 0x5F; // 0x60 → 1, 0x61 → 2, ..., 0x6F → 16
                *c_sam = s;
                is_sample[s as usize] = true;
                cl.sample = s;
            }
            0x70..=0x7F => {
                // ornament select: ornaments 0..15
                let o = b - 0x70;
                *c_orn = o;
                if o > 0 {
                    is_ornament[o as usize] = true;
                }
                if cl.envelope == 0 {
                    cl.envelope = 15;
                }
                cl.ornament = o;
            }
            0x80 => {
                // note off
                cl.note = NOTE_SOUND_OFF;
                break;
            }
            0x81 => {
                // envelope 15, current ornament
                cl.envelope = 15;
                cl.ornament = *c_orn;
            }
            0x82..=0x8F => {
                // envelope type + period (LE word)
                cl.envelope = b - 0x81;
                cl.ornament = *c_orn;
                // read LE word envelope period
                if *ptr + 1 < data.len() {
                    row.envelope = read_word(data, *ptr);
                    *ptr += 2;
                }
            }
            0x90 => {
                // end of row, no note
                break;
            }
            0x91..=0xA0 => {
                // noise mask (cmd 11)
                cl.additional_command.number = 11;
                cl.additional_command.parameter = b - 0x91;
            }
            0xA1..=0xB0 => {
                // volume
                let v = b - 0xA1;
                cl.volume = if v == 0 { 1 } else { v };
            }
            _ => {
                // skip: $B1+ → skip = byte - $B1
                *skip = (b - 0xB1) as i8;
            }
        }
    }
    // Update orn2sam tracking
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
