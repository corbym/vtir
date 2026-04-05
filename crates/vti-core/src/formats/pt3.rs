//! Pro Tracker 3.xx (*.pt3) binary format parser and writer.
//!
//! Ported from `PT32VTM` and `VTM2PT3` in `trfuncs.pas`
//! (c) 2000-2009 S.V.Bulba.

use crate::note_tables::get_note_freq;
use crate::types::*;
use anyhow::{bail, ensure, Context, Result};

// ─── PT3 binary layout offsets ───────────────────────────────────────────────

// PT3 header offsets (all absolute from file start)
const OFF_TITLE: usize = 0x1E; // 32 bytes, space-padded
const OFF_AUTHOR: usize = 0x42; // 32 bytes, space-padded
const OFF_TABLE: usize = 0x63; // tone table index
const OFF_DELAY: usize = 0x64; // initial delay
const OFF_NUM_POS: usize = 0x65; // number of positions
const OFF_LOOP_POS: usize = 0x66; // loop position
const OFF_PAT_PTR: usize = 0x67; // word: absolute offset of patterns table
const OFF_SAM_PTRS: usize = 0x69; // 32 × word: absolute sample offsets (index 0..31)
const OFF_ORN_PTRS: usize = 0xA9; // 16 × word: absolute ornament offsets (index 0..15)
const OFF_POS_LIST: usize = 0xC9; // position list bytes, terminated by 0xFF

const MIN_FILE_SIZE: usize = OFF_POS_LIST + 2;

// ─── Parser ──────────────────────────────────────────────────────────────────

/// Parse a raw PT3 binary blob into a [`Module`].
///
/// Ported from `PT32VTM` in `trfuncs.pas`.
pub fn parse(data: &[u8]) -> Result<Module> {
    ensure!(data.len() >= MIN_FILE_SIZE, "PT3: file too small");

    let mut module = Module::default();

    // ── Header name / version detection ──────────────────────────────────────
    // Pascal: StrLComp(@PT3.PT3_Name, 'ProTracker 3.', 13)
    // Pascal: StrLComp(@PT3.PT3_Name, 'Vortex Tracker II', 17)
    if data.starts_with(b"ProTracker 3.") && data.len() > 13 {
        module.features_level = match data[13] {
            b'0'..=b'5' => FeaturesLevel::Pt35,
            b'7'..=b'9' => FeaturesLevel::Pt37,
            _ => FeaturesLevel::Vt2,
        };
        module.vortex_module_header = false;
    } else if data.starts_with(b"Vortex Tracker II") {
        module.features_level = FeaturesLevel::Vt2;
        module.vortex_module_header = true;
    } else {
        module.features_level = FeaturesLevel::Pt35;
        module.vortex_module_header = false;
    }

    // ── Title and Author ─────────────────────────────────────────────────────
    // Pascal: Move(PT3.PT3_Name[$1E], VTM1.Title[1], 32); TrimRight
    // Pascal: Move(PT3.PT3_Name[$42], VTM1.Author[1], 32); TrimRight
    if data.len() >= OFF_TITLE + 32 {
        module.title = trim_right_ascii(&data[OFF_TITLE..OFF_TITLE + 32]);
    }
    if data.len() >= OFF_AUTHOR + 32 {
        module.author = trim_right_ascii(&data[OFF_AUTHOR..OFF_AUTHOR + 32]);
    }

    // ── Tone table, delay ─────────────────────────────────────────────────────
    module.ton_table = data[OFF_TABLE] & 0x0F;
    module.initial_delay = data[OFF_DELAY];

    // ── Position list ─────────────────────────────────────────────────────────
    // Pascal: PT3.PT3_LoopPosition = loop_pos (raw byte)
    module.positions.loop_pos = data[OFF_LOOP_POS] as usize;
    // Position list is at OFF_POS_LIST; bytes until 0xFF; each byte / 3 = pattern index
    let mut num_pos = 0usize;
    for i in 0..256usize {
        let off = OFF_POS_LIST + i;
        if off >= data.len() {
            break;
        }
        let b = data[off];
        if b == 0xFF {
            break;
        }
        module.positions.value[i] = (b / 3) as usize;
        num_pos += 1;
    }
    ensure!(num_pos > 0, "PT3: no positions");
    module.positions.length = num_pos;

    // ── Patterns pointer ──────────────────────────────────────────────────────
    let pat_ptr = read_word(data, OFF_PAT_PTR) as usize;

    // ── Samples (indices 1..31) ───────────────────────────────────────────────
    // Pascal: loop i := 1 to 31; if PT3_SamplePointers[i] = 0 → skip
    for i in 1..32usize {
        let ptr_off = OFF_SAM_PTRS + i * 2;
        if ptr_off + 1 >= data.len() {
            break;
        }
        let ptr = read_word(data, ptr_off) as usize;
        if ptr == 0 || ptr >= data.len() {
            continue;
        }
        if let Ok(sam) = parse_sample(&data[ptr..]) {
            module.samples[i] = Some(Box::new(sam));
        }
    }

    // ── Ornaments (indices 1..15) ─────────────────────────────────────────────
    // Ornament 0 is never stored in PT3; it's always empty/default
    // Pascal: loop i := 1 to 15
    for i in 1..16usize {
        let ptr_off = OFF_ORN_PTRS + i * 2;
        if ptr_off + 1 >= data.len() {
            break;
        }
        let ptr = read_word(data, ptr_off) as usize;
        if ptr == 0 || ptr >= data.len() {
            continue;
        }
        if let Ok(orn) = parse_ornament(&data[ptr..]) {
            module.ornaments[i] = Some(Box::new(orn));
        }
    }

    // ── Patterns ──────────────────────────────────────────────────────────────
    if pat_ptr > 0 && pat_ptr < data.len() {
        decode_patterns(data, pat_ptr, &mut module).context("PT3: parsing patterns")?;
    }

    Ok(module)
}

// ─── Sample parser ────────────────────────────────────────────────────────────

/// Parse a PT3 sample from a byte slice starting at the sample pointer.
///
/// PT3 sample binary layout (ported from `PT32VTM`, lines 1905–1943 of trfuncs.pas):
/// ```text
/// byte[0]       : Loop
/// byte[1]       : Length
/// For each tick j (0..Length-1):
///   byte[2+j*4]   : b0 — envelope_enabled=NOT(bit0), add_to_env_or_noise=bits6:1, amplitude_sliding=bit7, amplitude_slide_up=bit6 (wait, see below)
///   byte[3+j*4]   : b1 — amplitude=bits3:0, mixer_ton=NOT(bit4), mixer_noise=NOT(bit7), env_or_noise_accum=bit5, ton_accumulation=bit6
///   word[4+j*4]   : add_to_ton (signed LE word)
/// ```
fn parse_sample(data: &[u8]) -> Result<Sample> {
    ensure!(data.len() >= 2, "PT3: sample too small");
    let mut sam = Sample::default();
    sam.loop_pos = data[0];
    sam.length = data[1];
    ensure!(
        (sam.length as usize) <= MAX_SAM_LEN,
        "PT3: sample length overflow"
    );

    for j in 0..(sam.length as usize) {
        let base = 2 + j * 4;
        ensure!(base + 3 < data.len(), "PT3: sample data truncated");
        let b0 = data[base];
        let b1 = data[base + 1];
        let add_to_ton = i16::from_le_bytes([data[base + 2], data[base + 3]]);

        let tick = &mut sam.items[j];

        // b0: bit0 = NOT(envelope_enabled), bits6:1 = add_to_env_or_noise & 0x1F (shl 1),
        //     bit7 = amplitude_sliding, bit6 = amplitude_slide_up (when bit7=1)
        // Pascal read: Add_to_Env = byte shr 1; then sign-extend from bit4
        tick.envelope_enabled = (b0 & 0x01) == 0;
        let raw = b0 >> 1; // bits 6:0 of b0 — upper bits may be set from sliding flags
        tick.add_to_envelope_or_noise = if (raw & 0x10) != 0 {
            (raw | 0xF0) as i8 // sign-extend 5-bit from bit4
        } else {
            (raw & 0x0F) as i8
        };
        tick.amplitude_sliding = (b0 & 0x80) != 0;
        tick.amplitude_slide_up = (b0 & 0x40) != 0;

        // b1: bits3:0 = amplitude, bit4 = NOT(mixer_ton), bit5 = env_or_noise_accumulation,
        //     bit6 = ton_accumulation, bit7 = NOT(mixer_noise)
        tick.amplitude = b1 & 0x0F;
        tick.mixer_ton = (b1 & 0x10) == 0;
        tick.envelope_or_noise_accumulation = (b1 & 0x20) != 0;
        tick.ton_accumulation = (b1 & 0x40) != 0;
        tick.mixer_noise = (b1 & 0x80) == 0;

        tick.add_to_ton = add_to_ton;
    }

    Ok(sam)
}

// ─── Ornament parser ──────────────────────────────────────────────────────────

fn parse_ornament(data: &[u8]) -> Result<Ornament> {
    ensure!(data.len() >= 2, "PT3: ornament too small");
    let mut orn = Ornament::default();
    orn.loop_pos = data[0] as usize;
    orn.length = data[1] as usize;
    ensure!(orn.length <= MAX_ORN_LEN, "PT3: ornament length overflow");
    for i in 0..orn.length {
        ensure!(2 + i < data.len(), "PT3: ornament data truncated");
        orn.items[i] = data[2 + i] as i8;
    }
    Ok(orn)
}

// ─── Pattern decoder ──────────────────────────────────────────────────────────

/// Decode all patterns referenced by the module's position list.
///
/// Ported from `DecodePattern` in `PT32VTM` (trfuncs.pas lines 1797–1834).
fn decode_patterns(data: &[u8], pat_ptr: usize, module: &mut Module) -> Result<()> {
    let mut decoded = std::collections::HashSet::new();

    for pos_idx in 0..module.positions.length {
        let j = module.positions.value[pos_idx]; // VTM pattern index
        if !decoded.insert(j) {
            continue; // already decoded this pattern
        }
        if j >= MAX_NUM_OF_PATS {
            bail!("PT3: pattern index {} out of range", j);
        }

        // Channel pointers for pattern j are at pat_ptr + j*6.
        // These are absolute file offsets (little-endian words).
        let tbl_off = pat_ptr + j * 6;
        if tbl_off + 6 > data.len() {
            continue;
        }
        let ch_ptrs = [
            read_word(data, tbl_off) as usize,
            read_word(data, tbl_off + 2) as usize,
            read_word(data, tbl_off + 4) as usize,
        ];

        let pattern = decode_one_pattern(data, ch_ptrs)
            .with_context(|| format!("PT3: decoding pattern {}", j))?;
        module.patterns[j] = Some(Box::new(pattern));
    }
    Ok(())
}

/// Decode one pattern from its three channel byte streams.
///
/// Ported from `DecodePattern` + `PatternInterpreter` in `PT32VTM`
/// (trfuncs.pas lines 1656–1834).
fn decode_one_pattern(data: &[u8], ch_ptrs: [usize; 3]) -> Result<Pattern> {
    let mut pattern = Pattern::default();

    // Per-channel state (mirrors Pascal locals)
    let mut ptrs = ch_ptrs;
    let mut skip: [u8; 3] = [1, 1, 1];
    let mut skip_counter: [u8; 3] = [1, 1, 1];
    let mut prev_orn: [u8; 3] = [0, 0, 0];
    let mut ns_base: u8 = 0;
    let mut i: usize = 0; // current row

    'row_loop: while i < MAX_PAT_LEN {
        for ch in 0..3usize {
            skip_counter[ch] -= 1;
            if skip_counter[ch] != 0 {
                continue;
            }
            // Check for end-of-pattern marker on channel A only
            if ch == 0 {
                if ptrs[0] >= data.len() || data[ptrs[0]] == 0x00 {
                    // Pascal: Dec(i); break; then noise[i] = ns_base; inc(i); length = i
                    // Net: length = i (unchanged, since Dec then Inc).
                    break 'row_loop;
                }
            }
            pattern_interpreter(
                data,
                &mut ptrs[ch],
                &mut prev_orn[ch],
                &mut skip[ch],
                &mut ns_base,
                &mut pattern.items[i],
                ch,
            )
            .with_context(|| format!("PT3: channel {} row {}", ch, i))?;
            skip_counter[ch] = skip[ch];
        }
        pattern.items[i].noise = ns_base;
        i += 1;
    }

    pattern.length = i;
    Ok(pattern)
}

/// Decode one channel's bytecodes for one row, updating `row` in-place.
///
/// Ported from `PatternInterpreter` in `PT32VTM` (trfuncs.pas lines 1656–1795).
fn pattern_interpreter(
    data: &[u8],
    ptr: &mut usize,
    prev_orn: &mut u8,
    skip: &mut u8,
    ns_base: &mut u8,
    row: &mut PatternRow,
    ch: usize,
) -> Result<()> {
    let cl = &mut row.channel[ch];
    let mut quit = false;

    while !quit {
        ensure!(
            *ptr < data.len(),
            "PT3: channel data truncated (inner loop)"
        );
        let b = data[*ptr];
        *ptr += 1;

        match b {
            // ── Ornament + Sample (envelope off→15, set orn from nibble, read sample) ──
            0xF0..=0xFF => {
                cl.envelope = 15;
                *prev_orn = b - 0xF0;
                cl.ornament = *prev_orn;
                ensure!(*ptr < data.len(), "PT3: F0-FF sample byte missing");
                cl.sample = data[*ptr] / 2;
                *ptr += 1;
                // no quit — wait for note byte
            }

            // ── Sample only (1..31) ────────────────────────────────────────────
            0xD1..=0xEF => {
                cl.sample = b - 0xD0;
                // no quit
            }

            // ── Rest (no note, end of row) ─────────────────────────────────────
            0xD0 => {
                // note stays NOTE_NONE
                quit = true;
            }

            // ── Volume ────────────────────────────────────────────────────────
            0xC1..=0xCF => {
                cl.volume = b - 0xC0;
                // no quit
            }

            // ── Sound-off ─────────────────────────────────────────────────────
            0xC0 => {
                cl.note = NOTE_SOUND_OFF;
                quit = true;
            }

            // ── Envelope type (B2..BF) + ornament + 2-byte period ─────────────
            0xB2..=0xBF => {
                cl.envelope = b - 0xB1; // 1..14
                cl.ornament = *prev_orn;
                ensure!(
                    *ptr + 1 < data.len(),
                    "PT3: B2-BF envelope period truncated"
                );
                // Period stored big-endian: high byte then low byte
                row.envelope = ((data[*ptr] as u16) << 8) | (data[*ptr + 1] as u16);
                *ptr += 2;
                // no quit
            }

            // ── Delay/skip (B1) ───────────────────────────────────────────────
            0xB1 => {
                ensure!(*ptr < data.len(), "PT3: B1 skip byte missing");
                *skip = data[*ptr];
                *ptr += 1;
                // no quit
            }

            // ── Envelope off (B0) ─────────────────────────────────────────────
            0xB0 => {
                cl.envelope = 15;
                cl.ornament = *prev_orn;
                // no quit
            }

            // ── Note (0..95) ──────────────────────────────────────────────────
            0x50..=0xAF => {
                cl.note = (b - 0x50) as i8;
                quit = true;
            }

            // ── Ornament set (40..4F) ─────────────────────────────────────────
            0x40..=0x4F => {
                // $40 with envelope==0 → implicitly enable envelope-off marker
                if b == 0x40 && cl.envelope == 0 {
                    cl.envelope = 15;
                }
                *prev_orn = b - 0x40;
                cl.ornament = *prev_orn;
                // no quit
            }

            // ── Noise base (20..3F) ───────────────────────────────────────────
            0x20..=0x3F => {
                *ns_base = b - 0x20;
                // no quit
            }

            // ── Envelope type (10..1F) + optional period + sample ─────────────
            0x10..=0x1F => {
                if b == 0x10 {
                    // Just disable envelope (=15 means "use envelope off")
                    cl.envelope = 15;
                } else {
                    cl.envelope = b - 0x10; // 1..14
                    ensure!(
                        *ptr + 1 < data.len(),
                        "PT3: 10-1F envelope period truncated"
                    );
                    row.envelope = ((data[*ptr] as u16) << 8) | (data[*ptr + 1] as u16);
                    *ptr += 2;
                }
                cl.ornament = *prev_orn;
                ensure!(*ptr < data.len(), "PT3: 10-1F sample byte missing");
                cl.sample = data[*ptr] / 2;
                *ptr += 1;
                // no quit — wait for note byte
            }

            // ── Effect command codes ───────────────────────────────────────────
            0x08 | 0x09 => {
                cl.additional_command.number = b;
                // no quit
            }
            0x01..=0x05 => {
                cl.additional_command.number = b;
                // no quit
            }

            // ── Unknown / ignored bytes ───────────────────────────────────────
            _ => {
                // 0x00 cannot be reached here (caught before calling this fn)
                // 0x06, 0x07, 0x0A..0x0F are not used by the format
            }
        }
    }

    // ── Post-note: read command parameter bytes ───────────────────────────────
    // Ported from the `case Additional_Command.Number of` block after the
    // `repeat...until quit` in PatternInterpreter (trfuncs.pas lines 1735–1793).
    match cl.additional_command.number {
        // Command 1 (glide): delay + signed word → cmd 1 (up) or 2 (down)
        1 => {
            ensure!(*ptr + 2 < data.len(), "PT3: cmd1 params truncated");
            cl.additional_command.delay = data[*ptr];
            *ptr += 1;
            let tmp = i16::from_le_bytes([data[*ptr], data[*ptr + 1]]);
            *ptr += 2;
            if tmp < 0 {
                cl.additional_command.number = 2; // glide down
                cl.additional_command.parameter = ((-tmp) & 0xFF) as u8;
            } else {
                cl.additional_command.parameter = (tmp & 0xFF) as u8;
            }
        }

        // Command 2 (tone slide): → cmd 3; skip 3 bytes after delay, read signed word
        2 => {
            cl.additional_command.number = 3;
            ensure!(*ptr + 4 < data.len(), "PT3: cmd2 params truncated");
            cl.additional_command.delay = data[*ptr];
            *ptr += 3; // skip delay + 2 Dl bytes
            let tmp = i16::from_le_bytes([data[*ptr], data[*ptr + 1]]);
            *ptr += 2;
            if tmp < 0 {
                cl.additional_command.parameter = ((-tmp) & 0xFF) as u8;
            } else {
                cl.additional_command.parameter = (tmp & 0xFF) as u8;
            }
        }

        // Commands 3 and 4 (sample / ornament position): → cmd 4 or 5; 1 param byte
        3 | 4 => {
            cl.additional_command.number += 1;
            ensure!(*ptr < data.len(), "PT3: cmd3/4 param truncated");
            cl.additional_command.parameter = data[*ptr];
            *ptr += 1;
        }

        // Command 5 (envelope slide): → cmd 6; 2 nibble bytes
        5 => {
            cl.additional_command.number = 6;
            ensure!(*ptr + 1 < data.len(), "PT3: cmd5 params truncated");
            cl.additional_command.parameter = (data[*ptr] << 4) | (data[*ptr + 1] & 0x0F);
            *ptr += 2;
        }

        // Command 8 (env slide): delay + signed word → cmd 9 (up) or 10 (down)
        8 => {
            cl.additional_command.number = 9;
            ensure!(*ptr + 2 < data.len(), "PT3: cmd8 params truncated");
            cl.additional_command.delay = data[*ptr];
            *ptr += 1;
            let tmp = i16::from_le_bytes([data[*ptr], data[*ptr + 1]]);
            *ptr += 2;
            if tmp < 0 {
                cl.additional_command.number = 10; // env slide down
                cl.additional_command.parameter = ((-tmp) & 0xFF) as u8;
            } else {
                cl.additional_command.parameter = (tmp & 0xFF) as u8;
            }
        }

        // Command 9 (delay): → cmd 11; 1 param byte
        9 => {
            cl.additional_command.number = 11;
            ensure!(*ptr < data.len(), "PT3: cmd9 param truncated");
            cl.additional_command.parameter = data[*ptr];
            *ptr += 1;
        }

        _ => {}
    }

    Ok(())
}

// ─── Writer ──────────────────────────────────────────────────────────────────

/// Serialise a [`Module`] to a PT3 binary blob.
///
/// Ported from `VTM2PT3` in `trfuncs.pas` (lines 2307–2822).
pub fn write(module: &Module) -> Result<Vec<u8>> {
    let mut out = vec![0u8; 65536];

    // ── Header: identifier string ─────────────────────────────────────────────
    // Pascal: Move(Pt3Id[VortexModule_Header and (FeaturesLevel = 1), 0], PT3.PT3_Name, 30)
    let id: &[u8] = if module.vortex_module_header && module.features_level == FeaturesLevel::Vt2 {
        b"Vortex Tracker II 1.0 module: "
    } else {
        b"ProTracker 3.6 compilation of "
    };
    out[..30].copy_from_slice(id);
    // Adjust version digit for features level
    if module.features_level != FeaturesLevel::Vt2 {
        out[13] = 0x35 + module.features_level as u8; // '5' or '7'
    }

    // Title (32 bytes, space-padded at offset 30)
    let title = module.title.as_bytes();
    let tlen = title.len().min(32);
    out[30..30 + tlen].copy_from_slice(&title[..tlen]);
    out[30 + tlen..62].fill(b' ');

    // " by " at offset 62
    out[62..66].copy_from_slice(b" by ");

    // Author (32 bytes, space-padded at offset 66; Pascal fills 33 bytes)
    let auth = module.author.as_bytes();
    let alen = auth.len().min(32);
    out[66..66 + alen].copy_from_slice(&auth[..alen]);
    out[66 + alen..99].fill(b' ');

    // Tone table + delay
    out[OFF_TABLE] = module.ton_table;
    out[OFF_DELAY] = module.initial_delay;

    let num_pos = module.positions.length;
    out[OFF_NUM_POS] = num_pos as u8;
    out[OFF_LOOP_POS] = module.positions.loop_pos as u8;

    // PT3_PatternsPointer = 0xC9 + num_pos + 1
    let pat_ptr = OFF_POS_LIST + num_pos + 1;
    write_word(&mut out, OFF_PAT_PTR, pat_ptr as u16);

    // Clear sample and ornament pointer tables
    for b in out[OFF_SAM_PTRS..OFF_SAM_PTRS + 96].iter_mut() {
        *b = 0;
    }

    // Terminator at end of position list
    out[OFF_POS_LIST + num_pos] = 0xFF;

    // ── Determine which patterns are needed and build compact mapping ─────────
    // Pascal: VTMPat2PT3Pat[] maps VTM index → compacted PT3 index (gaps removed)
    let mut patterns_used = vec![false; MAX_NUM_OF_PATS];
    let mut max_pattern = 0usize;
    for i in 0..num_pos {
        let p = module.positions.value[i];
        if p < MAX_NUM_OF_PATS {
            patterns_used[p] = true;
            if p > max_pattern {
                max_pattern = p;
            }
        }
    }

    // Build VTMPat2PT3Pat: for each VTM pattern, subtract the number of gaps before it
    let mut vtm_to_pt3 = vec![0usize; MAX_NUM_OF_PATS];
    {
        let mut gap_count = 0usize;
        for i in 0..=max_pattern {
            if !patterns_used[i] {
                gap_count += 1;
            }
            vtm_to_pt3[i] = i.saturating_sub(gap_count);
        }
    }

    // Write position list (each byte = pt3_pattern_index * 3)
    for i in 0..num_pos {
        let p = module.positions.value[i];
        out[OFF_POS_LIST + i] = (vtm_to_pt3[p] * 3) as u8;
    }

    // ── Generate channel byte streams (PatStrs) ───────────────────────────────
    // Pascal uses strings; we use Vec<u8>.
    let mut pat_strs: Vec<Vec<u8>> = Vec::new();
    // PatsIndexes[pat_num][ch] → index in pat_strs
    let mut pats_indexes: Vec<[usize; 3]> = vec![[0; 3]; MAX_NUM_OF_PATS];

    // Per-channel carry-over state (mirrors Pascal DeltT, TnDl, TnCurDl, TnStp)
    let mut delt_t = [0i32; 3];
    let mut tn_dl = [0i32; 3];
    let mut tn_cur_dl = [0i32; 3];
    let mut tn_stp = [0i32; 3];

    let empty_pattern_string: Vec<u8> = vec![0xB1, 64, 0xD0, 0x00];

    let mut compiled_patterns = vec![false; MAX_NUM_OF_PATS];

    for i1 in 0..num_pos {
        let i = module.positions.value[i1];
        let pat_num = vtm_to_pt3[i];

        if compiled_patterns[i] {
            continue;
        }
        compiled_patterns[i] = true;

        if module.patterns[i].is_none() {
            // Empty pattern → emit the empty pattern string for all 3 channels
            let ep_idx = find_or_push(&mut pat_strs, &empty_pattern_string);
            pats_indexes[pat_num] = [ep_idx, ep_idx, ep_idx];
            continue;
        }

        let pat = module.patterns[i].as_deref().unwrap();
        let pat_len = pat.length;
        let mut prev_noise = 0u8;

        for k in 0..3usize {
            let mut str_num = pat_strs.len();
            let mut dl = delt_t[k];
            let mut sample_prev = usize::MAX;
            let mut ornament_prev = usize::MAX;
            let mut envelope_prev: i32 = -1;
            let mut volume_prev: i32 = -1;
            let mut skip_prev: i32 = 255;
            let mut ch_str: Vec<u8> = Vec::new();

            let mut j = 0usize;
            while j < pat_len {
                let item = &pat.items[j];
                let cl = &item.channel[k];

                // ── Determine what needs emitting ─────────────────────────────
                let env_val = cl.envelope as i32;
                let orn_val = cl.ornament as usize;
                let sam_val = cl.sample as usize;
                let note_val = cl.note;

                // Orn: emit if envelope or ornament changed (or re-trigger on note)
                let orn_needed = (env_val != 0 || orn_val != 0)
                    && (orn_val != ornament_prev || (ornament_prev != 0 && note_val == NOTE_NONE));
                // (which ornaments are used is tracked implicitly via the patterns)

                let sam_needed = note_val != NOTE_NONE && sam_val != 0 && sam_val != sample_prev;
                if sam_needed {
                    sample_prev = sam_val;
                }

                // ── Emit combined F0-FF / 10-1F byte sequences ────────────────
                let mut orn1 = orn_needed;
                let mut sam1 = sam_needed;

                if sam_needed && orn_needed && env_val != 0 {
                    if env_val == 15 {
                        if envelope_prev != 0 {
                            sam1 = false;
                            orn1 = false;
                            // $F0 + orn, sample*2
                            ch_str.push(0xF0 + cl.ornament);
                            ch_str.push(cl.sample * 2);
                        }
                    } else {
                        sam1 = false;
                        orn1 = false;
                        // $10 + env, Hi(period), Lo(period), sample*2
                        ch_str.push(0x10 + cl.envelope);
                        ch_str.push((item.envelope >> 8) as u8);
                        ch_str.push(item.envelope as u8);
                        ch_str.push(cl.sample * 2);
                        // also emit ornament
                        ch_str.push(0x40 + cl.ornament);
                    }
                }

                if sam1 {
                    ch_str.push(0xD0 + cl.sample);
                }

                if orn1 {
                    ch_str.push(0x40 + cl.ornament);
                    if env_val >= 1 && env_val <= 14 {
                        // $B1 + envelope, Hi(period), Lo(period)
                        ch_str.push(0xB1 + cl.envelope);
                        ch_str.push((item.envelope >> 8) as u8);
                        ch_str.push(item.envelope as u8);
                    } else if env_val == 15 && envelope_prev != 0 {
                        ch_str.push(0xB0);
                    }
                }

                // Envelope only (no ornament change)
                if !orn_needed && env_val > 0 {
                    if env_val != 15 {
                        ch_str.push(0xB1 + cl.envelope);
                        ch_str.push((item.envelope >> 8) as u8);
                        ch_str.push(item.envelope as u8);
                    } else if envelope_prev != 0 {
                        ch_str.push(0xB0);
                    }
                }

                if orn_needed {
                    ornament_prev = orn_val;
                }
                if env_val != 0 {
                    envelope_prev = if env_val < 15 { 1 } else { 0 };
                }

                // Volume
                if cl.volume != 0 && cl.volume as i32 != volume_prev {
                    ch_str.push(0xC0 + cl.volume);
                    volume_prev = cl.volume as i32;
                }

                // Noise base (only on channel B / k==1)
                if k == 1 && item.noise != prev_noise {
                    prev_noise = item.noise;
                    ch_str.push(0x20 + item.noise);
                }

                // ── Effect command pre-bytes ──────────────────────────────────
                let cmd = cl.additional_command.number;
                match cmd {
                    1 | 2 => {
                        ch_str.push(0x01);
                        tn_dl[k] = cl.additional_command.delay as i32;
                        if cmd == 1 {
                            tn_dl[k] = -tn_dl[k];
                        } // sign for direction
                        tn_cur_dl[k] = tn_dl[k].abs();
                        tn_stp[k] = if cmd == 1 {
                            cl.additional_command.parameter as i32
                        } else {
                            -(cl.additional_command.parameter as i32)
                        };
                    }
                    3 => {
                        // Tone slide: check conditions (Pascal lines 2531-2548)
                        let note_ok = note_val >= 0
                            || (note_val != NOTE_SOUND_OFF && module.features_level as u8 >= 1);
                        if note_ok {
                            ch_str.push(0x02);
                            tn_dl[k] = -(cl.additional_command.delay as i32);
                            tn_cur_dl[k] = tn_dl[k].abs();
                            if note_val >= 0 {
                                dl += get_note_freq(module.ton_table, note_val as u8) as i32
                                    - get_note_freq(module.ton_table, 0) as i32;
                            }
                            tn_stp[k] = if dl >= 0 {
                                cl.additional_command.parameter as i32
                            } else {
                                -(cl.additional_command.parameter as i32)
                            };
                            delt_t[k] = dl;
                        }
                    }
                    4..=6 => {
                        ch_str.push(cmd - 1);
                    }
                    9 | 10 => {
                        ch_str.push(0x08);
                    }
                    11 => {
                        if cl.additional_command.parameter != 0 {
                            ch_str.push(0x09);
                        }
                    }
                    _ => {}
                }

                // ── Reset tone-slide state on plain note or sound-off ─────────
                if note_val == NOTE_SOUND_OFF || (note_val >= 0 && !(cmd >= 1 && cmd <= 3)) {
                    dl = 0;
                    tn_dl[k] = 0;
                    delt_t[k] = 0;
                }

                // ── Skip / repeat control ─────────────────────────────────────
                // Advance j until next "significant" row (note, volume, envelope, ornament change)
                let d = j; // row index of the current note event
                let mut this_skip = 0i32;
                loop {
                    // Update tone-slide accumulator
                    if tn_dl[k] != 0 {
                        tn_cur_dl[k] -= 1;
                        if tn_cur_dl[k] == 0 {
                            tn_cur_dl[k] = tn_dl[k].abs();
                            delt_t[k] -= tn_stp[k];
                            // Tone-slide reached target → stop
                            if tn_dl[k] < 0
                                && ((delt_t[k] >= 0 && tn_stp[k] < 0)
                                    || (delt_t[k] <= 0 && tn_stp[k] >= 0))
                            {
                                tn_dl[k] = 0;
                                delt_t[k] = 0;
                            }
                        }
                    }
                    this_skip += 1;
                    j += 1;

                    if j >= pat_len {
                        break;
                    }
                    let nitem = &pat.items[j];
                    let ncl = &nitem.channel[k];
                    // Stop skipping on any "significant" change
                    if ncl.note != NOTE_NONE
                        || (ncl.additional_command.number == 11
                            && ncl.additional_command.parameter != 0)
                        || !(ncl.additional_command.number == 0
                            || ncl.additional_command.number == 11)
                        || ncl.volume != 0
                        || (ncl.envelope >= 1 && ncl.envelope <= 14)
                        || (ncl.envelope == 15
                            && (envelope_prev != 0 || (ncl.ornament == 0 && ornament_prev != 0)))
                        || ncl.ornament != 0
                        || (k == 1 && pat.items[d].noise != nitem.noise)
                    {
                        break;
                    }
                }

                // Emit skip byte if changed
                if this_skip != skip_prev {
                    ch_str.push(0xB1);
                    ch_str.push(this_skip as u8);
                    skip_prev = this_skip;
                }

                // ── Emit note / rest / sound-off byte ─────────────────────────
                let note_d = pat.items[d].channel[k].note;
                if note_d == NOTE_SOUND_OFF {
                    ch_str.push(0xC0);
                } else if note_d == NOTE_NONE {
                    ch_str.push(0xD0);
                } else {
                    ch_str.push(0x50 + note_d as u8);
                }

                // ── Emit post-note command parameters ─────────────────────────
                let cmd_d = pat.items[d].channel[k].additional_command.number;
                match cmd_d {
                    1 => {
                        // Glide up: delay, lo(param), 0x00
                        ch_str.push(cl.additional_command.delay);
                        ch_str.push(cl.additional_command.parameter);
                        ch_str.push(0x00);
                    }
                    2 => {
                        // Glide down: delay, lo(-param), 0xFF
                        ch_str.push(cl.additional_command.delay);
                        ch_str.push(cl.additional_command.parameter.wrapping_neg());
                        ch_str.push(0xFF);
                    }
                    3 => {
                        // Tone slide (written as cmd byte $02)
                        let note_ok = note_d >= 0
                            || (note_d != NOTE_SOUND_OFF && module.features_level as u8 >= 1);
                        if note_ok {
                            if dl >= 0 {
                                ch_str.push(cl.additional_command.delay);
                                ch_str.push((dl & 0xFF) as u8);
                                ch_str.push(((dl >> 8) & 0xFF) as u8);
                                ch_str.push(cl.additional_command.parameter);
                                ch_str.push(0x00);
                            } else {
                                let ndl = -dl;
                                ch_str.push(cl.additional_command.delay);
                                ch_str.push((ndl & 0xFF) as u8);
                                ch_str.push(((ndl >> 8) & 0xFF) as u8);
                                ch_str.push(cl.additional_command.parameter.wrapping_neg());
                                ch_str.push(0xFF);
                            }
                        }
                    }
                    4 | 5 => {
                        ch_str.push(cl.additional_command.parameter);
                    }
                    6 => {
                        ch_str.push(cl.additional_command.parameter >> 4);
                        ch_str.push(cl.additional_command.parameter & 0x0F);
                    }
                    9 => {
                        // Env slide up
                        ch_str.push(cl.additional_command.delay);
                        ch_str.push(cl.additional_command.parameter);
                        ch_str.push(0x00);
                    }
                    10 => {
                        // Env slide down
                        ch_str.push(cl.additional_command.delay);
                        ch_str.push(cl.additional_command.parameter.wrapping_neg());
                        ch_str.push(0xFF);
                    }
                    11 => {
                        if cl.additional_command.parameter != 0 {
                            ch_str.push(cl.additional_command.parameter);
                        }
                    }
                    _ => {}
                }

                dl = delt_t[k];
            }
            // End of pattern: null terminator
            ch_str.push(0x00);

            // Deduplicate: reuse an existing identical string if present
            let idx = find_or_push(&mut pat_strs, &ch_str);
            if idx == str_num {
                str_num += 1;
            }
            pats_indexes[pat_num][k] = idx;
        }
    }

    // ── Lay out channel data and pattern pointer table ────────────────────────
    // pt3_pat_count = VTMPat2PT3Pat[max_pattern] + 1
    let pt3_pat_count = vtm_to_pt3[max_pattern] + 1;
    let mut write_pos = pat_ptr + 6 * pt3_pat_count;

    // Write channel data strings
    let mut pat_offsets = vec![0u16; pat_strs.len()];
    for (i, s) in pat_strs.iter().enumerate() {
        if write_pos + s.len() > 65533 {
            bail!("PT3: output too large (channel data)");
        }
        pat_offsets[i] = write_pos as u16;
        out[write_pos..write_pos + s.len()].copy_from_slice(s);
        write_pos += s.len();
    }

    // Write pattern pointer table
    let mut tbl_pos = pat_ptr;
    for i in 0..=max_pattern {
        if patterns_used[i] {
            let pt3_idx = vtm_to_pt3[i];
            for ch in 0..3 {
                let off = pat_offsets[pats_indexes[pt3_idx][ch]];
                write_word(&mut out, tbl_pos, off);
                tbl_pos += 2;
            }
        }
    }

    // ── Samples ───────────────────────────────────────────────────────────────
    // Determine which samples are actually referenced
    let mut is_sample = [false; 32];
    for pos in 0..module.positions.length {
        let i = module.positions.value[pos];
        if let Some(pat) = module.patterns[i].as_deref() {
            for row in 0..pat.length {
                for ch in 0..3 {
                    let s = pat.items[row].channel[ch].sample as usize;
                    if s >= 1 && s <= 31 {
                        is_sample[s] = true;
                    }
                }
            }
        }
    }

    // Build the binary content for every used sample, then deduplicate: if two
    // samples have identical byte content, point them both at the same file offset.
    // This is the key compactness improvement over the original Pascal code, which
    // wrote each sample independently even when content was repeated.
    let mut sample_bytes: Vec<Option<Vec<u8>>> = vec![None; 32];
    for i in 1..32usize {
        if !is_sample[i] {
            continue;
        }
        let mut buf: Vec<u8> = Vec::new();
        if let Some(sam) = module.samples[i].as_deref() {
            buf.push(sam.loop_pos);
            buf.push(sam.length);
            for j in 0..(sam.length as usize) {
                let tick = &sam.items[j];
                // b0: bit0=NOT(envelope_enabled), bits5:1=add_to_env&0x1F, bit6=amp_slide_up, bit7=amp_sliding
                let mut b0: u8 = if !tick.envelope_enabled { 1 } else { 0 };
                b0 |= ((tick.add_to_envelope_or_noise as u8) & 0x1F) << 1;
                if tick.amplitude_sliding {
                    b0 |= 0x80;
                    if tick.amplitude_slide_up {
                        b0 |= 0x40;
                    }
                }
                // b1: bits3:0=amplitude, bit4=NOT(mixer_ton), bit5=env_or_noise_accum, bit6=ton_accum, bit7=NOT(mixer_noise)
                let mut b1: u8 = tick.amplitude & 0x0F;
                if !tick.mixer_ton {
                    b1 |= 0x10;
                }
                if tick.envelope_or_noise_accumulation {
                    b1 |= 0x20;
                }
                if tick.ton_accumulation {
                    b1 |= 0x40;
                }
                if !tick.mixer_noise {
                    b1 |= 0x80;
                }
                let ton_bytes = tick.add_to_ton.to_le_bytes();
                buf.extend_from_slice(&[b0, b1, ton_bytes[0], ton_bytes[1]]);
            }
        } else {
            // Null sample placeholder: loop=0, length=1, silent tick.
            buf.extend_from_slice(&[0x00, 0x01, 0x01, 0x90, 0x00, 0x00]);
        }
        sample_bytes[i] = Some(buf);
    }

    // Write samples, deduplicating identical content.
    let mut sample_written_at: [Option<u16>; 32] = [None; 32];
    for i in 1..32usize {
        let Some(ref content) = sample_bytes[i] else {
            continue;
        };
        // Check whether any earlier sample was identical.
        let reuse = (1..i).find(|&j| sample_bytes[j].as_deref() == Some(content.as_slice()));
        if let Some(j) = reuse {
            // Point this sample at the same offset as the earlier identical one.
            write_word(
                &mut out,
                OFF_SAM_PTRS + i * 2,
                sample_written_at[j].unwrap(),
            );
        } else {
            if write_pos > 65533 {
                bail!("PT3: output too large (samples)");
            }
            let pos = write_pos as u16;
            out[write_pos..write_pos + content.len()].copy_from_slice(content);
            write_pos += content.len();
            write_word(&mut out, OFF_SAM_PTRS + i * 2, pos);
            sample_written_at[i] = Some(pos);
        }
    }

    // ── Ornament 0 (always written) ────────────────────────────────────────────
    if write_pos > 65532 {
        bail!("PT3: output too large (ornaments)");
    }
    write_word(&mut out, OFF_ORN_PTRS, write_pos as u16); // ornament 0 pointer
    out[write_pos] = 0; // loop
    out[write_pos + 1] = 1; // length
    out[write_pos + 2] = 0; // item[0]
    write_pos += 3;

    // ── Ornaments 1..15 ────────────────────────────────────────────────────────
    // Determine which ornaments are actually used
    let mut is_ornament = [false; 16];
    for pos in 0..module.positions.length {
        let i = module.positions.value[pos];
        if let Some(pat) = module.patterns[i].as_deref() {
            for row in 0..pat.length {
                for ch in 0..3 {
                    let cl = &pat.items[row].channel[ch];
                    // Ornament needed when envelope or ornament are non-zero
                    let env_v = cl.envelope as i32;
                    let orn_v = cl.ornament as usize;
                    if (env_v != 0 || orn_v != 0) && orn_v >= 1 && orn_v <= 15 {
                        is_ornament[orn_v] = true;
                    }
                }
            }
        }
    }

    // Build ornament byte content first, then deduplicate on write (same approach
    // as for samples above).
    let mut ornament_bytes: Vec<Option<Vec<u8>>> = vec![None; 16];
    for i in 1..16usize {
        if !is_ornament[i] {
            continue;
        }
        let mut buf: Vec<u8> = Vec::new();
        if let Some(orn) = module.ornaments[i].as_deref() {
            buf.push(orn.loop_pos as u8);
            buf.push(orn.length as u8);
            for j in 0..orn.length {
                buf.push(orn.items[j] as u8);
            }
        } else {
            buf.extend_from_slice(&[0x00, 0x01, 0x00]);
        }
        ornament_bytes[i] = Some(buf);
    }

    let mut orn_written_at: [Option<u16>; 16] = [None; 16];
    for i in 1..16usize {
        let Some(ref content) = ornament_bytes[i] else {
            continue;
        };
        let reuse = (1..i).find(|&j| ornament_bytes[j].as_deref() == Some(content.as_slice()));
        if let Some(j) = reuse {
            write_word(&mut out, OFF_ORN_PTRS + i * 2, orn_written_at[j].unwrap());
        } else {
            if write_pos > 65533 {
                bail!("PT3: output too large (ornaments)");
            }
            let pos = write_pos as u16;
            out[write_pos..write_pos + content.len()].copy_from_slice(content);
            write_pos += content.len();
            write_word(&mut out, OFF_ORN_PTRS + i * 2, pos);
            orn_written_at[i] = Some(pos);
        }
    }

    out.truncate(write_pos);
    Ok(out)
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

#[inline]
fn read_word(data: &[u8], off: usize) -> u16 {
    u16::from_le_bytes([data[off], data[off + 1]])
}

#[inline]
fn write_word(buf: &mut [u8], off: usize, val: u16) {
    let bytes = val.to_le_bytes();
    buf[off] = bytes[0];
    buf[off + 1] = bytes[1];
}

fn trim_right_ascii(bytes: &[u8]) -> String {
    let end = bytes.iter().rposition(|&b| b > 0x20).map_or(0, |i| i + 1);
    String::from_utf8_lossy(&bytes[..end]).to_string()
}

/// Return the index in `strs` of a slice equal to `s`, inserting it if not found.
fn find_or_push(strs: &mut Vec<Vec<u8>>, s: &[u8]) -> usize {
    for (i, existing) in strs.iter().enumerate() {
        if existing.as_slice() == s {
            return i;
        }
    }
    strs.push(s.to_vec());
    strs.len() - 1
}
