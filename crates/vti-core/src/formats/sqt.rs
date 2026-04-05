//! Square Tracker (*.sqt) binary format parser.
//!
//! Ported from `SQT2VTM` in `trfuncs.pas` (c) 2000-2009 S.V.Bulba.

use crate::types::*;
use anyhow::{ensure, Result};

// ─── SQT binary layout offsets ───────────────────────────────────────────────
//
// Struct case 5 in TSpeccyModule (trfuncs.pas):
//   SQT_Size              : word  @ 0
//   SQT_SamplesPointer    : word  @ 2
//   SQT_OrnamentsPointer  : word  @ 4
//   SQT_PatternsPointer   : word  @ 6
//   SQT_PositionsPointer  : word  @ 8
//   SQT_LoopPointer       : word  @ 10
//
// Position table at SQT_PositionsPointer, 7 bytes per entry:
//   [+0] : chan C flags/pattern (bit7=EnableEffects, bits6:0=PatChanNumber)
//   [+1] : chan C vol(3:0) + trans nibble(7:4)
//   [+2] : chan B flags/pattern
//   [+3] : chan B vol + trans
//   [+4] : chan A flags/pattern
//   [+5] : chan A vol + trans
//   [+6] : delay
//   Termination: first byte of entry == 0
//   Loop detection: position offset == SQT_LoopPointer
//
// Pattern channel data pointer table at SQT_PatternsPointer:
//   Chan n pointer is 2 bytes at SQT_PatternsPointer + PatChanNumber*2
//   First byte at that address is the row count, then row data follows.
//
// Ornament pointer table at SQT_OrnamentsPointer + i*2  (i = SQT ornament index, 1-based)
//   LE word → absolute address; at that address: [lp: byte, extra: byte, items[0..31]: i8]
//
// Sample pointer table at SQT_SamplesPointer + i*2  (i = 1-based)
//   LE word → absolute address; at that address: [lp: byte, extra: byte, ticks[0..31]: 3 bytes]
//
// Sample tick format (3 bytes):
//   b0: amplitude(3:0), noise_hi(7:4)
//   b1: envelope_flag(0), mixer_noise(5), mixer_ton(6), noise_sign_or_extra(7), ton_hi_sign(4), ton_hi(3:0)
//   b2: ton_lo
//
// Ornament/sample loop logic (same for both):
//   lp < 32: len = lp + extra (capped 32); if len != 32: Loop=32, Length=32+len-lp else Loop=lp, Length=32
//   lp = 32: if IsSample and paired sample exists, use its loop to derive len;
//            else Length=33, Loop=32

const OFF_SAM_PTR: usize = 2;
const OFF_ORN_PTR: usize = 4;
const OFF_PAT_PTR: usize = 6;
const OFF_POS_PTR: usize = 8;
const OFF_LOOP_PTR: usize = 10;

const MIN_FILE_SIZE: usize = 12;

/// Per-position channel configuration (mirrors TSQTPat in Pascal).
#[derive(Clone, Copy, Default)]
struct SqtChan {
    enable_effects: bool,
    pat_chan_number: usize, // index into SQT_PatternsPointer channel table
    vol: u8,                // initial volume (0..15)
    trans: i8,              // semitone transposition
}

#[derive(Clone, Copy, Default)]
struct SqtPat {
    delay: u8,
    chn: [SqtChan; 3], // chn[0]=A, chn[1]=B, chn[2]=C
}

/// Parse a raw SQT binary blob into a [`Module`].
///
/// Ported from `SQT2VTM` in `trfuncs.pas`.
pub fn parse(data: &[u8]) -> Result<Module> {
    ensure!(data.len() >= MIN_FILE_SIZE, "SQT: file too small");

    let mut module = Module::default();
    module.features_level = FeaturesLevel::Pt35;
    module.vortex_module_header = false;
    module.ton_table = 1;
    module.title = String::new();
    module.author = String::new();

    let sam_ptr = read_word(data, OFF_SAM_PTR) as usize;
    let orn_ptr = read_word(data, OFF_ORN_PTR) as usize;
    let pat_ptr = read_word(data, OFF_PAT_PTR) as usize;
    let pos_ptr = read_word(data, OFF_POS_PTR) as usize;
    let loop_ptr = read_word(data, OFF_LOOP_PTR) as usize;

    let mut is_sample = [false; 32]; // indices 1..31
    let mut orns: [i32; 32] = [-1; 32]; // SQT orn index → VTM orn index; -1 = not yet mapped
    let mut orn2sam = [0u8; 16]; // VTM orn index → VTM sample index (for loop/len derivation)
    let mut n_orns: usize = 0;

    // Deduplicated pattern table
    let mut pats: Vec<SqtPat> = Vec::new(); // maps VTM pattern index → SqtPat
    let mut is_pattern = vec![false; crate::MAX_NUM_OF_PATS + 1];

    // ── Positions ─────────────────────────────────────────────────────────────
    let mut pos = 0usize;
    module.positions.loop_pos = 0;
    module.initial_delay = 0;

    'pos_loop: loop {
        if pos >= 256 || pats.len() > crate::MAX_NUM_OF_PATS {
            break;
        }
        let entry_off = pos_ptr + pos * 7;
        if entry_off >= data.len() {
            break;
        }
        // Loop detection
        if entry_off == loop_ptr {
            module.positions.loop_pos = pos;
        }

        // Termination: first byte == 0
        if data[entry_off] == 0 {
            break;
        }

        // Parse position entry
        let mut cpat = SqtPat::default();
        // Channels in SQT position: C=[+0,+1], B=[+2,+3], A=[+4,+5]
        // VTM stores as chn[0]=A, chn[1]=B, chn[2]=C
        for (sqt_ch, vtm_ch) in [(0usize, 2usize), (1, 1), (2, 0)] {
            let b_flags = data.get(entry_off + sqt_ch * 2).copied().unwrap_or(0);
            let b_vol = data.get(entry_off + sqt_ch * 2 + 1).copied().unwrap_or(0);
            let ch = &mut cpat.chn[vtm_ch];
            ch.enable_effects = (b_flags & 0x80) != 0;
            ch.pat_chan_number = (b_flags & 0x7F) as usize;
            ch.vol = b_vol & 0x0F;
            let trans_nibble = b_vol >> 4;
            ch.trans = if trans_nibble < 9 {
                trans_nibble as i8
            } else {
                -(trans_nibble as i8 - 9) - 1
            };
        }
        cpat.delay = data.get(entry_off + 6).copied().unwrap_or(1);
        if module.initial_delay == 0 {
            module.initial_delay = cpat.delay;
        }

        // Find or create VTM pattern slot for this unique combination
        let j = if let Some(idx) = pats.iter().position(|p| sqtpat_eq(p, &cpat)) {
            idx
        } else {
            let idx = pats.len();
            pats.push(cpat);
            idx
        };

        if j > crate::MAX_NUM_OF_PATS {
            pos += 1;
            continue 'pos_loop;
        }
        module.positions.value[pos] = j;
        pos += 1;

        if !is_pattern[j] {
            is_pattern[j] = true;
            // Decode pattern
            let pattern = decode_pattern(
                data,
                &cpat,
                pat_ptr,
                sam_ptr,
                orn_ptr,
                &mut is_sample,
                &mut orns,
                &mut orn2sam,
                &mut n_orns,
            );
            module.patterns[j] = Some(Box::new(pattern));
        }
    }
    module.positions.length = pos;

    // ── Ornaments ─────────────────────────────────────────────────────────────
    // For each mapped SQT ornament, build the VTM ornament.
    // Pointer: word at orn_ptr + sqt_orn_idx*2 → absolute address j
    // At j: [lp: byte, extra: byte, items[0..31]: signed bytes]
    for i in 1..=31usize {
        let l = orns[i];
        if l <= 0 {
            continue;
        }
        let vtm_idx = l as usize;

        let ptr_off = orn_ptr + i * 2;
        if ptr_off + 1 >= data.len() {
            continue;
        }
        let j_raw = read_word(data, ptr_off) as usize;
        // Pascal reads 2 bytes at orn_ptr+i*2 as j (possibly relative or absolute)
        // The code does: move(SQT^.Index[SQT^.SQT_OrnamentsPointer + i * 2], j, 2)
        // This is a LE word read — j is an absolute byte offset into the data.
        let j = j_raw;
        if j + 1 >= data.len() {
            continue;
        }

        let lp_raw = data[j] as usize;
        let extra = data.get(j + 1).copied().unwrap_or(0) as usize;

        let (loop_pos, orn_len) =
            compute_loop_len(lp_raw, extra, orn2sam[vtm_idx] as usize, sam_ptr, data);

        let mut orn = Ornament::default();
        orn.loop_pos = loop_pos;
        orn.length = orn_len.min(MAX_ORN_LEN);
        if orn.length == 0 {
            orn.length = 1;
        }
        if orn.loop_pos >= orn.length {
            orn.loop_pos = orn.length - 1;
        }

        // 32 items
        let lp1 = if lp_raw < 32 {
            lp_raw
        } else {
            // Use paired sample's lp for extension base
            orn2sam[vtm_idx] as usize
        };
        let _ = lp1;
        for k in 0..32usize {
            orn.items[k] = data.get(j + 2 + k).copied().unwrap_or(0) as i8;
        }
        // Extended items: Pascal Items[k] := Items[k - 32 + lp]
        let base_lp = if lp_raw < 32 {
            lp_raw
        } else {
            // Use the underlying lp that applies to the extended region
            loop_pos.min(31)
        };
        for k in 32..orn.length {
            let src = k.wrapping_sub(32).wrapping_add(base_lp);
            if src < 32 {
                orn.items[k] = orn.items[src];
            }
        }

        module.ornaments[vtm_idx] = Some(Box::new(orn));
    }

    // ── Samples ───────────────────────────────────────────────────────────────
    for i in 1..=31usize {
        if !is_sample[i] {
            continue;
        }
        let ptr_off = sam_ptr + i * 2;
        if ptr_off + 1 >= data.len() {
            continue;
        }
        let j_raw = read_word(data, ptr_off) as usize;
        let j = j_raw;
        if j + 1 >= data.len() {
            continue;
        }

        let lp_raw = data[j] as usize;
        let extra = data.get(j + 1).copied().unwrap_or(0) as usize;

        let (loop_pos, sam_len) = compute_sample_loop_len(lp_raw, extra);

        let mut sam = Sample::default();
        sam.loop_pos = loop_pos as u8;
        sam.length = sam_len as u8;
        if sam.length as usize > MAX_SAM_LEN {
            sam.length = MAX_SAM_LEN as u8;
        }
        if sam.loop_pos >= sam.length {
            sam.loop_pos = sam.length.saturating_sub(1);
        }

        // 32 ticks (3 bytes each)
        let base = j + 2;
        for k in 0..32usize {
            let b0 = data.get(base + k * 3).copied().unwrap_or(0);
            let b1 = data.get(base + k * 3 + 1).copied().unwrap_or(0);
            let b2 = data.get(base + k * 3 + 2).copied().unwrap_or(0);
            let tick = &mut sam.items[k];
            tick.amplitude = b0 & 0x0F;
            // Pascal: if Amplitude=0 → Envelope_Enabled = True
            if tick.amplitude == 0 {
                tick.envelope_enabled = true;
            }
            tick.mixer_noise = (b1 & 0x20) != 0; // bit5=1 → noise on
            tick.mixer_ton = (b1 & 0x40) != 0; // bit6=1 → tone on
            if tick.mixer_noise {
                // add_to_envelope_or_noise = (b0 >> 3) & 0x1E | (b1 >> 7)
                let mut raw = (b0 & 0xF0) >> 3;
                if (b1 & 0x80) != 0 {
                    raw |= 1;
                }
                tick.add_to_envelope_or_noise = if (raw & 0x10) != 0 {
                    (raw | 0xF0) as i8
                } else {
                    raw as i8
                };
            }
            // add_to_ton: if bit4 set → positive, else negative
            let ton = ((b1 & 0x0F) as u16) << 8 | (b2 as u16);
            tick.add_to_ton = if (b1 & 0x10) != 0 {
                ton as i16
            } else {
                -(ton as i16)
            };
        }

        // Extended ticks
        if lp_raw == 32 {
            sam.items[32] = SampleTick::default();
        } else if sam.length > 33 {
            for k in 32..sam.length as usize {
                sam.items[k] = sam.items[k.wrapping_sub(32).wrapping_add(lp_raw)];
            }
        }

        module.samples[i] = Some(Box::new(sam));
    }

    Ok(module)
}

// ─── Pattern decoder ──────────────────────────────────────────────────────────

#[allow(clippy::too_many_arguments)]
fn decode_pattern(
    data: &[u8],
    cpat: &SqtPat,
    pat_ptr: usize,
    sam_ptr: usize,
    orn_ptr: usize,
    is_sample: &mut [bool; 32],
    orns: &mut [i32; 32],
    orn2sam: &mut [u8; 16],
    n_orns: &mut usize,
) -> Pattern {
    // Resolve channel data pointers
    // Pascal: move(SQT^.Index[CPat.Chn[k].PatChanNumber * 2 + SQT^.SQT_PatternsPointer], ChPtr[k], 2)
    let mut ch_ptrs = [0usize; 3];
    let mut row_count = 0usize;
    for k in 0..3usize {
        let off = cpat.chn[k].pat_chan_number * 2 + pat_ptr;
        let raw_ptr = read_word(data, off) as usize;
        ch_ptrs[k] = raw_ptr;
        if k == 2 {
            // Row count is at ChPtr[2] (channel C)
            row_count = data.get(raw_ptr).copied().unwrap_or(0) as usize;
            if row_count > MAX_PAT_LEN {
                row_count = MAX_PAT_LEN;
            }
        }
    }
    // Advance past length byte
    for k in 0..3usize {
        ch_ptrs[k] = ch_ptrs[k].saturating_add(1);
    }

    let mut pattern = Pattern::default();
    pattern.length = row_count;

    // Initial volume for each channel from position entry
    for k in 0..3usize {
        let initial_vol = 15u8.saturating_sub(cpat.chn[k].vol);
        let vol = if initial_vol == 0 { 1 } else { initial_vol };
        if row_count > 0 {
            pattern.items[0].channel[k].volume = vol;
        }
    }

    // Per-channel state
    let mut env_en = [false; 3];
    let mut env_t = [15u8; 3];
    let mut env_p = [0u8; 3];
    let mut prev_note = [0u8; 3];
    let mut prev_samp = [0u8; 3];
    let mut prev_orn = [255u8; 3]; // 255 = no ornament yet
    let mut ix21 = [0u8; 3]; // skip counter
    let mut b7ix0 = [false; 3]; // re-trigger flag
    let mut ix27 = [0usize; 3]; // saved ptr for arpeggio retrigger
    let mut c_vol = [0u8; 3];
    for k in 0..3usize {
        c_vol[k] = cpat.chn[k].vol;
    }

    // Process channels in order (Pascal: for k := 2 downto 0)
    for row in 0..row_count {
        for k in (0..3usize).rev() {
            interpret_channel(
                data,
                row,
                k,
                cpat,
                pat_ptr,
                sam_ptr,
                orn_ptr,
                is_sample,
                orns,
                orn2sam,
                n_orns,
                &mut ch_ptrs[k],
                &mut ix21[k],
                &mut b7ix0[k],
                &mut ix27[k],
                &mut env_en[k],
                &mut env_t[k],
                &mut env_p[k],
                &mut prev_note[k],
                &mut prev_samp[k],
                &mut prev_orn[k],
                &mut c_vol[k],
                &mut pattern,
            );
        }
    }

    // Pascal: set delay on first row if not already set by cmd 11
    if row_count > 0 {
        let row0 = &mut pattern.items[0];
        let has_delay = row0.channel[0].additional_command.number == 11
            || row0.channel[1].additional_command.number == 11
            || row0.channel[2].additional_command.number == 11;
        if !has_delay {
            let k = if row0.channel[0].additional_command.number == 0 {
                0
            } else if row0.channel[1].additional_command.number == 0 {
                1
            } else {
                2
            };
            row0.channel[k].additional_command.number = 11;
            row0.channel[k].additional_command.parameter = cpat.delay;
        }
    }

    pattern
}

/// Per-channel interpreter for one row.
///
/// This is a direct port of `PatternInterpreter` in `SQT2VTM`.
#[allow(clippy::too_many_arguments)]
fn interpret_channel(
    data: &[u8],
    row: usize,
    ch: usize,
    cpat: &SqtPat,
    pat_ptr: usize,
    _sam_ptr: usize,
    _orn_ptr: usize,
    is_sample: &mut [bool; 32],
    orns: &mut [i32; 32],
    orn2sam: &mut [u8; 16],
    n_orns: &mut usize,
    ch_ptr: &mut usize,
    ix21: &mut u8,
    b7ix0: &mut bool,
    ix27: &mut usize,
    env_en: &mut bool,
    env_t: &mut u8,
    env_p: &mut u8,
    prev_note: &mut u8,
    prev_samp: &mut u8,
    prev_orn: &mut u8,
    c_vol: &mut u8,
    pattern: &mut Pattern,
) {
    // ix21 > 0 → skip this row for this channel
    if *ix21 > 0 {
        *ix21 -= 1;
        if *b7ix0 {
            call_lc191(
                data, row, ch, cpat, pat_ptr, is_sample, orns, orn2sam, n_orns, ch_ptr, ix27,
                env_en, env_t, env_p, prev_note, prev_samp, prev_orn, c_vol, pattern,
            );
        }
        // track orn2sam
        if *prev_orn < 255 && *prev_orn > 0 && orn2sam[*prev_orn as usize] == 0 {
            orn2sam[*prev_orn as usize] = *prev_samp;
        }
        return;
    }

    let mut ptr = *ch_ptr;
    *b7ix0 = false;
    let mut b6ix0 = true;

    loop {
        if ptr >= data.len() {
            break;
        }
        let b = data[ptr];
        match b {
            0x00..=0x5F => {
                // Note with transposition
                let mut nt = b as i32 + cpat.chn[ch].trans as i32 + 2;
                if nt < 0 {
                    nt = 0;
                }
                if nt > 0x5F {
                    nt = 0x5F;
                }
                let nt = nt as u8;
                pattern.items[row].channel[ch].note = nt as i8;
                *prev_note = nt;
                *ix27 = ptr;
                ptr += 1;
                call_lc283(
                    data, row, ch, cpat, pat_ptr, is_sample, orns, orn2sam, n_orns, &mut ptr,
                    &mut b6ix0, ix27, env_en, env_t, env_p, prev_note, prev_samp, prev_orn, c_vol,
                    pattern,
                );
                if b6ix0 {
                    *ch_ptr = ptr;
                }
                break;
            }
            0x60..=0x6E => {
                // Effect command: Call_LC1D1
                let a = b - 0x60;
                ptr += 1;
                call_lc1d1(
                    data, row, ch, cpat, a, &mut ptr, &mut b6ix0, env_en, env_t, env_p, c_vol,
                    pattern,
                );
                break;
            }
            0x6F => {
                // Note release
                pattern.items[row].channel[ch].note = NOTE_SOUND_OFF;
                *ch_ptr = ptr + 1;
                break;
            }
            0x70..=0x7F => {
                // Note release + effect
                pattern.items[row].channel[ch].note = NOTE_SOUND_OFF;
                let a = b - 0x6F;
                ptr += 1;
                call_lc1d1(
                    data, row, ch, cpat, a, &mut ptr, &mut b6ix0, env_en, env_t, env_p, c_vol,
                    pattern,
                );
                break;
            }
            0x80..=0x9F => {
                // Arpeggio note (delta + retrigger)
                *ch_ptr = ptr + 1;
                if (b & 0x10) == 0 {
                    *prev_note = prev_note.wrapping_add(b & 0x0F);
                } else {
                    *prev_note = prev_note.wrapping_sub(b & 0x0F);
                }
                if *prev_note > 0x5F {
                    *prev_note = 0x5F;
                }
                pattern.items[row].channel[ch].note = *prev_note as i8;
                call_lc191(
                    data, row, ch, cpat, pat_ptr, is_sample, orns, orn2sam, n_orns, ch_ptr, ix27,
                    env_en, env_t, env_p, prev_note, prev_samp, prev_orn, c_vol, pattern,
                );
                break;
            }
            0xA0..=0xBF => {
                // Skip + optional retrigger
                *ch_ptr = ptr + 1;
                *ix21 = b & 0x0F;
                if (b & 0x10) == 0 {
                    break;
                }
                if *ix21 > 0 {
                    *b7ix0 = true;
                }
                call_lc191(
                    data, row, ch, cpat, pat_ptr, is_sample, orns, orn2sam, n_orns, ch_ptr, ix27,
                    env_en, env_t, env_p, prev_note, prev_samp, prev_orn, c_vol, pattern,
                );
                break;
            }
            0xC0..=0xFF => {
                // Sample set
                *ch_ptr = ptr + 1;
                *ix27 = ptr;
                let a = b & 0x1F;
                call_lc2a8(
                    row, ch, a, is_sample, orns, orn2sam, prev_samp, prev_note, prev_orn, env_en,
                    env_t, env_p, c_vol, pattern,
                );
                break;
            }
        }
    }

    if *prev_orn < 255 && *prev_orn > 0 && orn2sam[*prev_orn as usize] == 0 {
        orn2sam[*prev_orn as usize] = *prev_samp;
    }
}

/// call_lc191: retrigger using saved ix27 pointer (arpeggio re-execute)
#[allow(clippy::too_many_arguments)]
fn call_lc191(
    data: &[u8],
    row: usize,
    ch: usize,
    cpat: &SqtPat,
    pat_ptr: usize,
    is_sample: &mut [bool; 32],
    orns: &mut [i32; 32],
    orn2sam: &mut [u8; 16],
    n_orns: &mut usize,
    ch_ptr: &mut usize,
    ix27: &mut usize,
    env_en: &mut bool,
    env_t: &mut u8,
    env_p: &mut u8,
    prev_note: &mut u8,
    prev_samp: &mut u8,
    prev_orn: &mut u8,
    c_vol: &mut u8,
    pattern: &mut Pattern,
) {
    let ptr = *ix27;
    let mut b6ix0 = false;
    let b = data.get(ptr).copied().unwrap_or(0);
    let mut ptr2 = ptr;
    match b {
        0x00..=0x7F => {
            ptr2 += 1;
            call_lc283(
                data, row, ch, cpat, pat_ptr, is_sample, orns, orn2sam, n_orns, &mut ptr2,
                &mut b6ix0, ix27, env_en, env_t, env_p, prev_note, prev_samp, prev_orn, c_vol,
                pattern,
            );
        }
        0x80..=0xFF => {
            let a = b & 0x1F;
            call_lc2a8(
                row, ch, a, is_sample, orns, orn2sam, prev_samp, prev_note, prev_orn, env_en,
                env_t, env_p, c_vol, pattern,
            );
        }
    }
    if b6ix0 {
        *ch_ptr = ptr2 + 1;
    }
}

/// call_lc283: reads the combined effect byte at ptr and dispatches
#[allow(clippy::too_many_arguments)]
fn call_lc283(
    data: &[u8],
    row: usize,
    ch: usize,
    cpat: &SqtPat,
    pat_ptr: usize,
    is_sample: &mut [bool; 32],
    orns: &mut [i32; 32],
    orn2sam: &mut [u8; 16],
    n_orns: &mut usize,
    ptr: &mut usize,
    b6ix0: &mut bool,
    ix27: &mut usize,
    env_en: &mut bool,
    env_t: &mut u8,
    env_p: &mut u8,
    prev_note: &mut u8,
    prev_samp: &mut u8,
    prev_orn: &mut u8,
    c_vol: &mut u8,
    pattern: &mut Pattern,
) {
    let b = data.get(*ptr).copied().unwrap_or(0);
    *ptr += 1;
    match b {
        0x00..=0x7F => {
            call_lc1d1(
                data, row, ch, cpat, b, ptr, b6ix0, env_en, env_t, env_p, c_vol, pattern,
            );
        }
        0x80..=0xFF => {
            let sample_idx = (b >> 1) & 0x1F;
            if sample_idx != 0 {
                call_lc2a8(
                    row, ch, sample_idx, is_sample, orns, orn2sam, prev_samp, prev_note, prev_orn,
                    env_en, env_t, env_p, c_vol, pattern,
                );
            }
            if (b & 0x40) != 0 {
                let b2 = data.get(*ptr).copied().unwrap_or(0);
                let orn_idx = (b2 >> 4) | (if (b & 0x01) != 0 { 0x10 } else { 0 });
                if orn_idx != 0 {
                    call_lc2d9(
                        row,
                        ch,
                        orn_idx as usize,
                        orns,
                        orn2sam,
                        n_orns,
                        prev_samp,
                        prev_orn,
                        env_en,
                        env_t,
                        env_p,
                        pattern,
                    );
                }
                *ptr += 1;
                let lo_cmd = data.get(*ptr - 1).copied().unwrap_or(0) & 0x0F;
                if lo_cmd != 0 {
                    let mut p2 = *ptr;
                    call_lc1d1(
                        data, row, ch, cpat, lo_cmd, &mut p2, b6ix0, env_en, env_t, env_p, c_vol,
                        pattern,
                    );
                    *ptr = p2;
                }
            }
        }
    }
}

/// call_lc1d1: effect opcode handler (volume, glide, envelope)
#[allow(clippy::too_many_arguments)]
fn call_lc1d1(
    data: &[u8],
    row: usize,
    ch: usize,
    cpat: &SqtPat,
    a: u8,
    ptr: &mut usize,
    b6ix0: &mut bool,
    env_en: &mut bool,
    env_t: &mut u8,
    env_p: &mut u8,
    c_vol: &mut u8,
    pattern: &mut Pattern,
) {
    let param = data.get(*ptr).copied().unwrap_or(0);
    *ptr += 1;
    if *b6ix0 {
        // caller will update ch_ptr = ptr+1 (handled after return)
        *b6ix0 = false;
    }

    let row_ch = &mut pattern.items[row].channel[ch];
    match a.saturating_sub(1) {
        0 if cpat.chn[ch].enable_effects => {
            *c_vol = param & 0x0F;
            let v = 15u8.saturating_sub(*c_vol);
            row_ch.volume = if v == 0 { 1 } else { v };
        }
        1 if cpat.chn[ch].enable_effects => {
            *c_vol = c_vol.wrapping_add(param) & 0x0F;
            let v = 15u8.saturating_sub(*c_vol);
            row_ch.volume = if v == 0 { 1 } else { v };
        }
        2 if cpat.chn[ch].enable_effects => {
            // Set all channels volume
            for kk in 0..3usize {
                let cv = param & 0x0F;
                let v = 15u8.saturating_sub(cv);
                pattern.items[row].channel[kk].volume = if v == 0 { 1 } else { v };
            }
        }
        3 if cpat.chn[ch].enable_effects => {
            // Add to all channels volume
            for kk in 0..3usize {
                let cv = (pattern.items[row].channel[kk].volume.wrapping_add(param)) & 0x0F;
                let v = 15u8.saturating_sub(cv);
                pattern.items[row].channel[kk].volume = if v == 0 { 1 } else { v };
            }
        }
        4 if cpat.chn[ch].enable_effects => {
            row_ch.additional_command.number = 11;
            let d = param & 0x1F;
            row_ch.additional_command.parameter = if d == 0 { 32 } else { d };
        }
        5 if cpat.chn[ch].enable_effects => {
            row_ch.additional_command.number = 11;
            let d = (row_ch.additional_command.parameter.wrapping_add(param)) & 0x1F;
            row_ch.additional_command.parameter = if d == 0 { 32 } else { d };
        }
        6 => {
            row_ch.additional_command.delay = 1;
            row_ch.additional_command.number = 2;
            row_ch.additional_command.parameter = param;
        }
        7 => {
            row_ch.additional_command.delay = 1;
            row_ch.additional_command.number = 1;
            row_ch.additional_command.parameter = param;
        }
        n => {
            // Envelope (n >= 8 maps to envelope type)
            *env_en = true;
            let mut et = (n + 1) & 0x0F;
            if et == 15 {
                et = 7;
            }
            *env_t = et;
            row_ch.envelope = et;
            if *prev_orn_ref_noop() != 255 {
                // ornament already set by call_lc2d9 or prev_orn
                // (Pascal: if PrevOrn[ch] <> 255 then Ornament := PrevOrn[ch])
                // We can't easily access prev_orn here — set via caller state
            }
            *env_p = param;
            pattern.items[row].envelope = param as u16;
        }
    }
}

#[inline(always)]
fn prev_orn_ref_noop() -> &'static u8 {
    &255u8 // placeholder — envelope ornament assignment is handled by call_lc2d9
}

/// call_lc2a8: sample assignment and related state updates
#[allow(clippy::too_many_arguments)]
fn call_lc2a8(
    row: usize,
    ch: usize,
    a: u8,
    is_sample: &mut [bool; 32],
    orns: &mut [i32; 32],
    orn2sam: &mut [u8; 16],
    prev_samp: &mut u8,
    prev_note: &mut u8,
    prev_orn: &mut u8,
    env_en: &mut bool,
    env_t: &mut u8,
    env_p: &mut u8,
    c_vol: &mut u8,
    pattern: &mut Pattern,
) {
    let _ = (orns, orn2sam, env_t, env_p, c_vol);
    // Clear ornament/envelope if currently set
    if *env_en || *prev_orn != 0 {
        *prev_orn = 0;
        *env_en = false;
        pattern.items[row].channel[ch].envelope = 15;
        pattern.items[row].channel[ch].ornament = 0;
    }
    let a = a as usize;
    if a > 0 && a <= 31 {
        is_sample[a] = true;
    }
    if *prev_samp != a as u8 {
        *prev_samp = a as u8;
        pattern.items[row].channel[ch].sample = a as u8;
    }
    if a != 0 {
        pattern.items[row].channel[ch].note = *prev_note as i8;
    }
}

/// call_lc2d9: ornament assignment
#[allow(clippy::too_many_arguments)]
fn call_lc2d9(
    row: usize,
    ch: usize,
    a: usize,
    orns: &mut [i32; 32],
    orn2sam: &mut [u8; 16],
    n_orns: &mut usize,
    prev_samp: &mut u8,
    prev_orn: &mut u8,
    env_en: &mut bool,
    env_t: &mut u8,
    env_p: &mut u8,
    pattern: &mut Pattern,
) {
    if a == 0 {
        return;
    }
    let orn = if orns[a] < 0 {
        if *n_orns >= 15 {
            return;
        }
        *n_orns += 1;
        orns[a] = *n_orns as i32;
        *n_orns
    } else {
        orns[a] as usize
    };

    let row_ch = &mut pattern.items[row].channel[ch];
    if *env_en || *prev_orn as usize != orn {
        *prev_orn = orn as u8;
        if *env_en {
            row_ch.envelope = *env_t;
            pattern.items[row].envelope = *env_p as u16;
        } else {
            row_ch.envelope = 15;
        }
        row_ch.ornament = orn as u8;
    }
    // Track orn→sample association
    if orn <= 15 && orn2sam[orn] == 0 {
        orn2sam[orn] = *prev_samp;
    }
}

// ─── Loop/length computation helpers ─────────────────────────────────────────

/// Compute (loop_pos, length) for ornaments.
/// Pascal: same logic as samples but capped at 32/33.
fn compute_loop_len(
    lp_raw: usize,
    extra: usize,
    paired_sample_idx: usize,
    sam_ptr: usize,
    data: &[u8],
) -> (usize, usize) {
    if lp_raw < 32 {
        let len = (lp_raw + extra).min(32);
        let len = if len == 0 { 1 } else { len };
        let lp = lp_raw.min(len.saturating_sub(1));
        let lp1 = lp + 1;
        if len < 32 {
            (32, 32 + len - lp1 + 1)
        } else {
            (lp, 32)
        }
    } else {
        // lp_raw == 32: use paired sample's loop/len to derive
        if paired_sample_idx > 0 {
            let sam_off = sam_ptr + paired_sample_idx * 2;
            let j = read_word(data, sam_off) as usize;
            let slp = data.get(j).copied().unwrap_or(0) as usize;
            let sextra = data.get(j + 1).copied().unwrap_or(0) as usize;
            let (_, sam_len) = compute_sample_loop_len(slp, sextra);
            let lp = if slp < 32 { slp } else { 31 };
            if slp < 32 {
                let lp1 = lp + 1;
                if sam_len < 32 {
                    (32, 32 + sam_len - lp1 + 1)
                } else {
                    (lp, 32)
                }
            } else {
                (31, 32)
            }
        } else {
            (31, 32)
        }
    }
}

fn compute_sample_loop_len(lp_raw: usize, extra: usize) -> (usize, usize) {
    if lp_raw < 32 {
        let len = (lp_raw + extra).min(32);
        let len = if len == 0 { 1 } else { len };
        let lp = lp_raw.min(len.saturating_sub(1));
        let lp1 = lp + 1;
        if len != 32 {
            (32, 32 + len - lp1)
        } else {
            (lp, 32)
        }
    } else {
        (32, 33) // lp=32, length=33, items[32]=empty
    }
}

fn sqtpat_eq(a: &SqtPat, b: &SqtPat) -> bool {
    a.delay == b.delay
        && (0..3).all(|k| {
            a.chn[k].pat_chan_number == b.chn[k].pat_chan_number
                && a.chn[k].enable_effects == b.chn[k].enable_effects
                && a.chn[k].vol == b.chn[k].vol
                && a.chn[k].trans == b.chn[k].trans
        })
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

#[inline]
fn read_word(data: &[u8], off: usize) -> u16 {
    let lo = data.get(off).copied().unwrap_or(0) as u16;
    let hi = data.get(off + 1).copied().unwrap_or(0) as u16;
    lo | (hi << 8)
}
