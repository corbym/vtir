//! ASC Sound Master (*.asc / *.as0) binary format parser.
//!
//! Ported from `ASC2VTM` / `ASC02VTM` in `trfuncs.pas` (c) 2000-2009 S.V.Bulba.

use crate::note_tables::PT3_NOTE_TABLE_ST;
use crate::types::*;
use anyhow::{ensure, Result};

// ─── ASC1 binary layout offsets ──────────────────────────────────────────────
//
// Struct case 6 (ASC1) in TSpeccyModule (trfuncs.pas):
//   ASC1_Delay              : byte  @ 0
//   ASC1_LoopingPosition    : byte  @ 1
//   ASC1_PatternsPointers   : word  @ 2
//   ASC1_SamplesPointers    : word  @ 4
//   ASC1_OrnamentsPointers  : word  @ 6
//   ASC1_Number_Of_Positions: byte  @ 8
//   ASC1_Positions          : array @ 9  (one byte per position, 0-based pattern index)
//
// ASC0 is the same but without the LoopingPosition field:
//   ASC0_Delay              : byte  @ 0
//   ASC0_PatternsPointers   : word  @ 1
//   ASC0_SamplesPointers    : word  @ 3
//   ASC0_OrnamentsPointers  : word  @ 5
//   ASC0_Number_Of_Positions: byte  @ 7
//   ASC0_Positions          : array @ 8
//
// ASC02VTM inserts a zero loop-position byte, making it look like ASC1 to the
// shared parsing logic (all pointers incremented by 1).
//
// Pattern channel pointers at ASC1_PatternsPointers + 6*j (relative offsets):
//   ChPtr[k] = word at (ASC1_PatternsPointers + 6*j + k*2) + ASC1_PatternsPointers
//   (the stored word is relative; add the base pointer to get absolute offset)
//
// Ornament pointer table at ASC1_OrnamentsPointers + i*2 (i = ASC orn index, 0-based):
//   LE word (relative) + ASC1_OrnamentsPointers → absolute pointer to orn data
//   Ornament data: 2-byte ticks [flags:byte, delta:i8]; terminated by bit6 set
//   Loop marker: shortint(flags) < 0 (bit7 set)
//
// Sample pointer table at ASC1_SamplesPointers + i*2 (i = ASC samp index, 0-based):
//   LE word (relative) + ASC1_SamplesPointers → absolute pointer to sample data
//   Sample data: 3-byte ticks; terminated by bit6 or bit5+bit6 of byte 0
//   Loop marker: shortint(byte[0]) < 0 (bit7 set); end: bit6 set; loop-end: bits5+6 set

const ASC1_OFF_DELAY: usize = 0;
const ASC1_OFF_LOOP_POS: usize = 1;
const ASC1_OFF_PAT_PTRS: usize = 2;
const ASC1_OFF_SAM_PTRS: usize = 4;
const ASC1_OFF_ORN_PTRS: usize = 6;
const ASC1_OFF_NUM_POS: usize = 8;
const ASC1_OFF_POSITIONS: usize = 9;

const MIN_FILE_SIZE: usize = ASC1_OFF_POSITIONS + 1;

/// Parse a raw ASC Sound Master v1 (`.asc`) binary blob into a [`Module`].
///
/// Ported from `ASC2VTM` in `trfuncs.pas`.
pub fn parse(data: &[u8]) -> Result<Module> {
    ensure!(data.len() >= MIN_FILE_SIZE, "ASC: file too small");
    parse_asc1(data)
}

/// Parse a raw ASC Sound Master v0 (`.as0`) binary blob into a [`Module`].
///
/// ASC0 lacks the loop-position byte; we prepend a zero internally to reuse
/// the ASC1 parser (mirrors `ASC02VTM` in `trfuncs.pas`).
pub fn parse_asc0(data: &[u8]) -> Result<Module> {
    ensure!(data.len() >= MIN_FILE_SIZE - 1, "ASC0: file too small");
    if data.len() >= 65535 {
        anyhow::bail!("ASC0: file too large");
    }
    // Pascal ASC02VTM:
    //   Move(ASC0_PatternsPointers, ASC1_PatternsPointers, FSize - 1)
    //   ASC1_LoopingPosition := 0
    //   Inc(ASC1_PatternsPointers); Inc(ASC1_SamplesPointers); Inc(ASC1_OrnamentsPointers)
    //
    // In Rust: create a copy with a 0 loop-position byte inserted at offset 1,
    // and increment all three pointer fields by 1.
    let mut v: Vec<u8> = Vec::with_capacity(data.len() + 1);
    v.push(data[0]); // delay
    v.push(0); // inserted loop position = 0
    v.extend_from_slice(&data[1..]); // rest of ASC0 data (pointers onward)

    // The three 16-bit pointer fields are now at ASC1 offsets (2, 4, 6).
    // Each stored pointer value was relative to the OLD base; since we inserted
    // one byte, each value needs +1.
    for &off in &[ASC1_OFF_PAT_PTRS, ASC1_OFF_SAM_PTRS, ASC1_OFF_ORN_PTRS] {
        if off + 1 < v.len() {
            let w = u16::from_le_bytes([v[off], v[off + 1]]);
            let w2 = w.wrapping_add(1);
            v[off] = (w2 & 0xFF) as u8;
            v[off + 1] = (w2 >> 8) as u8;
        }
    }

    parse_asc1(&v)
}

// ─── Internal parser ──────────────────────────────────────────────────────────

fn parse_asc1(data: &[u8]) -> Result<Module> {
    let pat_ptrs_base = read_word(data, ASC1_OFF_PAT_PTRS) as usize;
    let sam_ptrs_base = read_word(data, ASC1_OFF_SAM_PTRS) as usize;
    let orn_ptrs_base = read_word(data, ASC1_OFF_ORN_PTRS) as usize;
    let num_pos = data[ASC1_OFF_NUM_POS] as usize;

    let mut module = Module::default();
    module.features_level = FeaturesLevel::Pt35;
    module.vortex_module_header = false;
    module.ton_table = 1;
    module.initial_delay = data[ASC1_OFF_DELAY];
    module.positions.loop_pos = data[ASC1_OFF_LOOP_POS] as usize;

    // Title/author detection: if pat_ptrs_base - num_pos == 72, there's embedded text
    if pat_ptrs_base.wrapping_sub(num_pos) == 72 {
        let title_off = pat_ptrs_base.wrapping_sub(44);
        let author_off = pat_ptrs_base.wrapping_sub(20);
        if title_off + 20 <= data.len() {
            module.title = trim_right_ascii(&data[title_off..title_off + 20]);
        }
        if author_off + 20 <= data.len() {
            module.author = trim_right_ascii(&data[author_off..author_off + 20]);
        }
    } else {
        module.title = String::new();
        module.author = String::new();
    }

    // Ornament/sample index remapping:
    // ASC uses 0-based indices 0..31 for both; VTM uses 1-based 1..16 (orns) and 1..31 (sams).
    let mut orns: [i32; 32] = [-1i32; 32]; // ASC orn idx → VTM orn idx; -1 = unmapped
    let mut sams: [i32; 32] = [-1i32; 32]; // ASC samp idx → VTM samp idx; -1 = unmapped
    let mut n_orns: usize = 0;
    let mut n_sams: usize = 0;

    // Per-channel state across pattern rows
    let mut ts_cnt = [0i16; 3];
    let mut ts = [0i16; 3];
    let mut volume_counter = [0i32; 3];
    let mut vc_dop = [0i32; 3];
    let mut prev_note = [0u8; 3];
    let mut vol = [0i8; 3];
    let mut prev_vol = [0i8; 3];
    let mut pat_vol = [0i8; 3];
    let mut prev_orn = [0u8; 3];
    let mut env_t: i32 = 0;
    let mut ns = 0u8; // noise value

    // ── Positions & Patterns ──────────────────────────────────────────────────
    let mut pos = 0usize;
    while pos < num_pos {
        let j_off = ASC1_OFF_POSITIONS + pos;
        if j_off >= data.len() {
            break;
        }
        let j = data[j_off] as usize; // VTM pattern index (direct)
        if j > crate::MAX_NUM_OF_PATS {
            pos += 1;
            continue;
        }
        module.positions.value[pos] = j;
        pos += 1;

        if module.patterns[j].is_none() {
            // Resolve channel pointers (relative + base)
            let tbl_off = pat_ptrs_base + 6 * j;
            if tbl_off + 6 > data.len() {
                module.patterns[j] = Some(Box::new(Pattern::default()));
                continue;
            }
            let ch_ptrs = [
                (read_word(data, tbl_off) as usize).wrapping_add(pat_ptrs_base),
                (read_word(data, tbl_off + 2) as usize).wrapping_add(pat_ptrs_base),
                (read_word(data, tbl_off + 4) as usize).wrapping_add(pat_ptrs_base),
            ];

            // Reset per-pattern state
            let c_delay = module.initial_delay as i32;
            let mut env_en = [false; 3];
            for k in 0..3usize {
                env_en[k] = false;
                pat_vol[k] = 0;
                prev_orn[k] = 0;
                ts_cnt[k] = 0;
                ts[k] = 0;
                volume_counter[k] = 0;
                vc_dop[k] = 0;
                prev_note[k] = 0;
                vol[k] = 0;
                prev_vol[k] = 0;
            }
            ns = 0;

            let pattern = decode_pattern(
                data,
                ch_ptrs,
                c_delay,
                pat_ptrs_base,
                sam_ptrs_base,
                orn_ptrs_base,
                &mut env_en,
                &mut ts_cnt,
                &mut ts,
                &mut volume_counter,
                &mut vc_dop,
                &mut prev_note,
                &mut vol,
                &mut prev_vol,
                &mut pat_vol,
                &mut prev_orn,
                &mut env_t,
                &mut ns,
                &mut orns,
                &mut sams,
                &mut n_orns,
                &mut n_sams,
            );
            module.patterns[j] = Some(Box::new(pattern));
        }
    }
    module.positions.length = pos;
    if pos > 0 && module.positions.loop_pos >= pos {
        module.positions.loop_pos = pos - 1;
    }

    // ── Zero-ornament elimination ─────────────────────────────────────────────
    // Pascal: find any ornament that is a single tick with no delta → "zo" ornament
    // If found, remove it from the orn map and fixup pattern references.
    let zo = find_zero_ornament(&orns, data, orn_ptrs_base);
    if zo > 0 {
        // Renumber all orns > zo down by 1
        for i in 0..32usize {
            if orns[i] > zo as i32 {
                orns[i] -= 1;
            }
        }
        // Fixup patterns
        for pi in 0..=crate::MAX_NUM_OF_PATS {
            if let Some(pat) = module.patterns[pi].as_deref_mut() {
                for row in pat.items.iter_mut().take(pat.length) {
                    for ch in 0..3usize {
                        let o = row.channel[ch].ornament as usize;
                        if o > zo {
                            row.channel[ch].ornament -= 1;
                        } else if o == zo {
                            row.channel[ch].ornament = 0;
                        }
                    }
                }
            }
        }
    } else if n_orns == 16 {
        // If orn 16 was allocated but no zero-ornament found, remove orn 16
        for i in 0..32usize {
            if orns[i] == 16 {
                orns[i] = -1;
                break;
            }
        }
        for pi in 0..=crate::MAX_NUM_OF_PATS {
            if let Some(pat) = module.patterns[pi].as_deref_mut() {
                for row in pat.items.iter_mut().take(pat.length) {
                    for ch in 0..3usize {
                        if row.channel[ch].ornament == 16 {
                            row.channel[ch].ornament = 0;
                        }
                    }
                }
            }
        }
    }

    // ── Ornaments ─────────────────────────────────────────────────────────────
    for i in 0..32usize {
        let l = orns[i];
        if l <= 0 {
            continue;
        }
        let vtm_idx = l as usize;
        let ptr_off = orn_ptrs_base + i * 2;
        if ptr_off + 1 >= data.len() {
            continue;
        }
        let j = (read_word(data, ptr_off) as usize).wrapping_add(orn_ptrs_base);

        let mut orn = Ornament::default();
        orn.loop_pos = 0;

        // Simulate ornament: accumulate deltas to find loop length
        // Pascal: 2-byte ticks [flags, delta]; bit7(flags) = loop marker; bit6(flags) = end
        let mut jl = j;
        let mut k = 0usize;
        let mut n = 0i32;
        let mut nb = 0i32;
        'outer: loop {
            let mut jj = jl;
            loop {
                let tmp = n;
                let delta = data.get(jj + 1).copied().unwrap_or(0) as i8 as i32;
                n = n.wrapping_add(delta);
                if n < -0x55 || n > 0x55 {
                    break 'outer;
                }
                let flags = data.get(jj).copied().unwrap_or(0);
                if (flags as i8) < 0 {
                    // loop marker
                    nb = tmp;
                    jl = jj;
                    orn.loop_pos = k;
                }
                orn.items[k] = n as i8;
                k += 1;
                jj += 2;
                if k >= MAX_ORN_LEN { break 'outer; }
                if (flags & 0x40) != 0 { break; } // end of sequence
            }
            if k >= MAX_ORN_LEN || n == nb || n < -0x55 || n > 0x55 {
                break;
            }
        }
        orn.length = k;
        if orn.length == 0 { orn.length = 1; }
        if orn.loop_pos >= orn.length { orn.loop_pos = orn.length - 1; }

        module.ornaments[vtm_idx] = Some(Box::new(orn));
    }

    // ── Samples ───────────────────────────────────────────────────────────────
    for i in 0..32usize {
        let l = sams[i];
        if l <= 0 {
            continue;
        }
        let vtm_idx = l as usize;
        let ptr_off = sam_ptrs_base + i * 2;
        if ptr_off + 1 >= data.len() {
            continue;
        }
        let j = (read_word(data, ptr_off) as usize).wrapping_add(sam_ptrs_base);
        if j >= data.len() {
            continue;
        }

        let mut sam = Sample::default();
        sam.loop_pos = 0;
        let mut k = 0usize;

        // 3-byte ticks:
        //   b0: add_to_envelope_or_noise (upper 5 bits as signed via shl3/div8), bit7=loop, bit6=end
        //   b1: add_to_ton (signed byte)
        //   b2: bit0=NOT(mixer_ton), bit3=NOT(mixer_noise), bits5:6=amp_slide(01=down,10=up,11=up?),
        //       bit2=envelope_enable (val&6=2), bit7:4=amplitude
        let mut jj = j;
        loop {
            if jj + 2 >= data.len() { break; }
            let b0 = data[jj];
            let b1 = data[jj + 1];
            let b2 = data[jj + 2];
            let tick = &mut sam.items[k];
            tick.ton_accumulation = true;
            tick.add_to_ton = b1 as i8 as i16;
            tick.mixer_ton = (b2 & 0x01) == 0; // bit0=0 → tone on
            tick.mixer_noise = (b2 & 0x08) == 0; // bit3=0 → noise on
            tick.envelope_enabled = (b2 & 0x06) == 0x02; // bits1:2=01 → envelope
            if (b2 & 0x06) == 0x04 {
                tick.amplitude_sliding = true;
                tick.amplitude_slide_up = false;
            } else if (b2 & 0x06) == 0x06 {
                tick.amplitude_sliding = true;
                tick.amplitude_slide_up = true;
            }
            tick.amplitude = b2 >> 4;
            tick.envelope_or_noise_accumulation = true;
            if tick.envelope_enabled || tick.mixer_noise {
                // Pascal: shortint(b0 shl 3) div 8  = sign-extends upper 5 bits of b0
                let raw = ((b0 as i8) << 3) as i8;
                tick.add_to_envelope_or_noise = raw / 8;
            }
            // Loop marker
            if (b0 as i8) < 0 {
                sam.loop_pos = k as u8;
            }
            k += 1;
            jj += 3;
            if k >= MAX_SAM_LEN { break; }
            // Termination
            let flags = b0 & (0x40 | 0x20);
            if flags != 0 {
                // bit6 = end; bit5 = loop-end (add empty tick then set loop)
                if (b0 & 0x20) != 0 && (b0 & 0x40) == 0 {
                    // loop-end marker: set loop_pos = k, add empty tick
                    sam.loop_pos = k as u8;
                    if k < MAX_SAM_LEN {
                        sam.items[k] = SampleTick::default();
                        k += 1;
                    }
                }
                break;
            }
        }
        sam.length = k as u8;
        if sam.length == 0 { sam.length = 1; }
        if sam.loop_pos >= sam.length { sam.loop_pos = sam.length - 1; }

        module.samples[vtm_idx] = Some(Box::new(sam));
    }

    Ok(module)
}

// ─── Pattern decoder ──────────────────────────────────────────────────────────

#[allow(clippy::too_many_arguments)]
fn decode_pattern(
    data: &[u8],
    ch_ptrs: [usize; 3],
    c_delay: i32,
    _pat_ptrs_base: usize,
    _sam_ptrs_base: usize,
    _orn_ptrs_base: usize,
    env_en: &mut [bool; 3],
    ts_cnt: &mut [i16; 3],
    ts: &mut [i16; 3],
    volume_counter: &mut [i32; 3],
    vc_dop: &mut [i32; 3],
    prev_note: &mut [u8; 3],
    vol: &mut [i8; 3],
    prev_vol: &mut [i8; 3],
    pat_vol: &mut [i8; 3],
    prev_orn: &mut [u8; 3],
    env_t: &mut i32,
    ns: &mut u8,
    orns: &mut [i32; 32],
    sams: &mut [i32; 32],
    n_orns: &mut usize,
    n_sams: &mut usize,
) -> Pattern {
    let mut pattern = Pattern::default();
    let mut ptrs = ch_ptrs;
    let mut skip: [i8; 3] = [0; 3];
    let mut skip_ctr: [i8; 3] = [0; 3];
    let c_delay = if c_delay == 0 { 256i32 } else { c_delay };
    let mut i = 0usize;

    'row: loop {
        if i >= MAX_PAT_LEN {
            break;
        }

        // Volume counter interpolation (Pascal ASC2VTM inner loop)
        for k in 0..3usize {
            if volume_counter[k] != 0 {
                if volume_counter[k] > 0 {
                    let n = (c_delay + vc_dop[k]) / volume_counter[k];
                    vc_dop[k] = (c_delay + vc_dop[k]) % volume_counter[k];
                    let n = n + prev_vol[k] as i32;
                    let n = n.min(15) as i8;
                    if n != prev_vol[k] {
                        pattern.items[i].channel[k].volume = n as u8;
                        prev_vol[k] = n;
                    }
                } else {
                    let neg_vc = -volume_counter[k];
                    let n = (c_delay + vc_dop[k]) / neg_vc;
                    vc_dop[k] = (c_delay + vc_dop[k]) % neg_vc;
                    let n = prev_vol[k] as i32 - n;
                    let n = n.max(0) as i8;
                    if n != prev_vol[k] {
                        pattern.items[i].channel[k].volume = n as u8;
                        if n != 0 {
                            prev_vol[k] = n;
                        }
                    }
                }
            }
        }

        for k in 0..3usize {
            skip_ctr[k] = skip_ctr[k].wrapping_sub(1);
            if skip_ctr[k] >= 0 {
                // TS counter update even when skipping
                for _ in 0..c_delay {
                    if ts_cnt[k] != 0 {
                        if ts_cnt[k] > 0 { ts_cnt[k] -= 1; }
                        ts[k] = ts[k].wrapping_sub(ts[k]);
                    }
                }
                continue;
            }
            // End-of-pattern: channel A byte == 0xFF
            if k == 0 && data.get(ptrs[0]).copied().unwrap_or(0xFF) == 0xFF {
                break 'row;
            }
            interpret_channel(
                data,
                k,
                i,
                &mut ptrs[k],
                c_delay,
                env_en,
                ts_cnt,
                ts,
                volume_counter,
                vc_dop,
                prev_note,
                vol,
                prev_vol,
                pat_vol,
                prev_orn,
                env_t,
                ns,
                orns,
                sams,
                n_orns,
                n_sams,
                &mut skip[k],
                &mut pattern,
            );
            skip_ctr[k] = skip[k];
        }

        pattern.items[i].noise = *ns;
        i += 1;
    }
    pattern.length = i;
    pattern
}

#[allow(clippy::too_many_arguments)]
fn interpret_channel(
    data: &[u8],
    ch: usize,
    row: usize,
    ptr: &mut usize,
    c_delay: i32,
    env_en: &mut [bool; 3],
    ts_cnt: &mut [i16; 3],
    ts: &mut [i16; 3],
    volume_counter: &mut [i32; 3],
    vc_dop: &mut [i32; 3],
    prev_note: &mut [u8; 3],
    vol: &mut [i8; 3],
    prev_vol: &mut [i8; 3],
    pat_vol: &mut [i8; 3],
    prev_orn: &mut [u8; 3],
    env_t: &mut i32,
    ns: &mut u8,
    orns: &mut [i32; 32],
    sams: &mut [i32; 32],
    n_orns: &mut usize,
    n_sams: &mut usize,
    skip: &mut i8,
    pattern: &mut Pattern,
) {
    ts_cnt[ch] = 0;
    let mut init_sample_disabled = false;

    loop {
        if *ptr >= data.len() {
            break;
        }
        let b = data[*ptr];
        *ptr += 1;

        match b {
            0x00..=0x55 => {
                // Note
                prev_note[ch] = b;
                pattern.items[row].channel[ch].note = b as i8;
                if ts_cnt[ch] <= 0 { ts[ch] = 0; }
                if env_en[ch] {
                    pattern.items[row].channel[ch].envelope = *env_t as u8;
                    let ep = data.get(*ptr).copied().unwrap_or(0);
                    pattern.items[row].envelope = ep as u16;
                    pattern.items[row].channel[ch].ornament = prev_orn[ch];
                    *ptr += 1;
                }
                if !init_sample_disabled && vol[ch] != prev_vol[ch] {
                    pattern.items[row].channel[ch].volume = vol[ch] as u8;
                    pat_vol[ch] = vol[ch];
                    prev_vol[ch] = vol[ch];
                }
                // Update ts counters
                for _ in 0..c_delay {
                    if ts_cnt[ch] != 0 {
                        if ts_cnt[ch] > 0 { ts_cnt[ch] -= 1; }
                        ts[ch] = ts[ch].wrapping_sub(ts[ch]);
                    }
                }
                break;
            }
            0x56..=0x5D => {
                // Skip (no note)
                for _ in 0..c_delay {
                    if ts_cnt[ch] != 0 {
                        if ts_cnt[ch] > 0 { ts_cnt[ch] -= 1; }
                        ts[ch] = ts[ch].wrapping_sub(ts[ch]);
                    }
                }
                break;
            }
            0x5E => {
                // Note release (break sample loop — not realisable in PT3)
                pattern.items[row].channel[ch].note = NOTE_SOUND_OFF;
                for _ in 0..c_delay {
                    if ts_cnt[ch] != 0 {
                        if ts_cnt[ch] > 0 { ts_cnt[ch] -= 1; }
                        ts[ch] = ts[ch].wrapping_sub(ts[ch]);
                    }
                }
                break;
            }
            0x5F => {
                pattern.items[row].channel[ch].note = NOTE_SOUND_OFF;
                for _ in 0..c_delay {
                    if ts_cnt[ch] != 0 {
                        if ts_cnt[ch] > 0 { ts_cnt[ch] -= 1; }
                        ts[ch] = ts[ch].wrapping_sub(ts[ch]);
                    }
                }
                break;
            }
            0x60..=0x9F => {
                *skip = (b - 0x60) as i8;
            }
            0xA0..=0xBF => {
                // Sample select (ASC sample index a = b - 0xA0, 0-based)
                let a = (b - 0xA0) as usize;
                let mapped = sams[a];
                let mapped = if mapped < 0 {
                    if *n_sams < 31 {
                        *n_sams += 1;
                        sams[a] = *n_sams as i32;
                        *n_sams
                    } else {
                        0
                    }
                } else {
                    mapped as usize
                };
                pattern.items[row].channel[ch].sample = mapped as u8;
            }
            0xC0..=0xDF => {
                // Ornament select (ASC ornament index a = b - 0xC0, 0-based)
                let a = (b - 0xC0) as usize;
                let mapped = orns[a];
                let mapped = if mapped < 0 {
                    if *n_orns < 16 {
                        *n_orns += 1;
                        orns[a] = *n_orns as i32;
                        *n_orns
                    } else {
                        0
                    }
                } else {
                    mapped as usize
                };
                prev_orn[ch] = mapped as u8;
                pattern.items[row].channel[ch].ornament = mapped as u8;
                if pattern.items[row].channel[ch].envelope == 0 {
                    pattern.items[row].channel[ch].envelope = 15;
                }
            }
            0xE0 => {
                // Envelope enable, vol = 15
                if pat_vol[ch] != 15 {
                    pattern.items[row].channel[ch].volume = 15;
                    pat_vol[ch] = 15;
                }
                vol[ch] = 15;
                prev_vol[ch] = 15;
                env_en[ch] = true;
            }
            0xE1..=0xEF => {
                let i_vol = (b - 0xE0) as i8;
                if pat_vol[ch] != i_vol {
                    pattern.items[row].channel[ch].volume = i_vol as u8;
                    pat_vol[ch] = i_vol;
                }
                vol[ch] = i_vol;
                prev_vol[ch] = i_vol;
                if env_en[ch] {
                    pattern.items[row].channel[ch].envelope = 15;
                    pattern.items[row].channel[ch].ornament = prev_orn[ch];
                    env_en[ch] = false;
                }
            }
            0xF0 => {
                // Noise select
                let v = data.get(*ptr).copied().unwrap_or(0);
                *ptr += 1;
                *ns = v & 0x1F;
            }
            0xF1 => {
                init_sample_disabled = true;
            }
            0xF2 => {} // ornament-init-disabled (not realisable)
            0xF3 => {
                init_sample_disabled = true;
            }
            0xF4 => {
                // Noise mask command
                let v = data.get(*ptr).copied().unwrap_or(0);
                *ptr += 1;
                pattern.items[row].channel[ch].additional_command.number = 11;
                pattern.items[row].channel[ch].additional_command.parameter = v;
            }
            0xF5 => {
                // Portamento up
                let v = data.get(*ptr).copied().unwrap_or(0);
                *ptr += 1;
                pattern.items[row].channel[ch].additional_command.number = 2;
                pattern.items[row].channel[ch].additional_command.delay = 1;
                let ts_add = (v as i16) * 16;
                ts[ch] = ts[ch].wrapping_add(ts_add);
                ts_cnt[ch] = -1;
                pattern.items[row].channel[ch].additional_command.parameter = v;
            }
            0xF6 => {
                // Portamento down
                let v = data.get(*ptr).copied().unwrap_or(0);
                *ptr += 1;
                pattern.items[row].channel[ch].additional_command.number = 1;
                pattern.items[row].channel[ch].additional_command.delay = 1;
                let ts_add = -((v as i16) * 16);
                ts[ch] = ts[ch].wrapping_add(ts_add);
                ts_cnt[ch] = -1;
                pattern.items[row].channel[ch].additional_command.parameter = v;
            }
            0xF7 => {
                // Glissando (note slide) with sample-init-disabled
                init_sample_disabled = true;
                calc_slide(data, ptr, row, ch, ts_cnt, ts, prev_note, pattern);
            }
            0xF8 => { *env_t = 8; }
            0xF9 => {
                calc_slide(data, ptr, row, ch, ts_cnt, ts, prev_note, pattern);
            }
            0xFA => { *env_t = 10; }
            0xFB => {
                // Volume counter
                let v = data.get(*ptr).copied().unwrap_or(0);
                *ptr += 1;
                volume_counter[ch] = v as i32;
                if (v & 0x20) != 0 {
                    volume_counter[ch] = (v as i8 | (-128i8 | 64i8)) as i32;
                }
                vc_dop[ch] = 0;
            }
            0xFC => { *env_t = 12; }
            0xFE => { *env_t = 14; }
            _ => {} // 0xFD, 0xFF — unrecognised
        }
    }

    *skip = *skip; // no reset (Pascal: SkipCounter := Skip at end of PatternInterpreter)
}

/// Glissando slide calculation — mirrors `CalcSlide` in Pascal ASC2VTM.
#[allow(clippy::too_many_arguments)]
fn calc_slide(
    data: &[u8],
    ptr: &mut usize,
    row: usize,
    ch: usize,
    ts_cnt: &mut [i16; 3],
    ts: &mut [i16; 3],
    prev_note: &[u8; 3],
    pattern: &mut Pattern,
) {
    let speed = data.get(*ptr).copied().unwrap_or(1) as i32;
    let target_note = data.get(*ptr + 1).copied().unwrap_or(0) as usize;
    *ptr += 1;

    pattern.items[row].channel[ch].additional_command.number = 3;

    let delta_ton = if target_note < 0x56 {
        let from = PT3_NOTE_TABLE_ST[prev_note[ch] as usize] as i32;
        let to = PT3_NOTE_TABLE_ST[target_note] as i32;
        (from - to) * 16
    } else {
        0i32
    };
    // FeaturesLevel >= 1: add ts[ch]
    let delta_ton = delta_ton + ts[ch] as i32;
    let ts_add = if speed > 0 { delta_ton / speed } else { delta_ton };
    ts[ch] = (delta_ton - (if speed > 0 { delta_ton % speed } else { 0 })) as i16;
    ts_cnt[ch] = speed as i16;
    let delta_abs = (delta_ton / 16).abs();
    if delta_abs != 0 && speed > 0 {
        let i = delta_abs / speed;
        if i > 0 {
            pattern.items[row].channel[ch].additional_command.delay = 1;
            pattern.items[row].channel[ch].additional_command.parameter =
                i.min(255) as u8;
        } else {
            let d = speed / delta_abs;
            pattern.items[row].channel[ch].additional_command.delay =
                d.min(15) as u8;
            pattern.items[row].channel[ch].additional_command.parameter = 1;
        }
    } else {
        pattern.items[row].channel[ch].additional_command.delay = 15;
        pattern.items[row].channel[ch].additional_command.parameter = 1;
    }
    let _ = ts_add;
}

/// Find the "zero ornament" (a single-tick ornament with no cumulative offset).
/// Returns its VTM ornament index if found, 0 if none.
fn find_zero_ornament(orns: &[i32; 32], data: &[u8], orn_ptrs_base: usize) -> usize {
    for i in 0..32usize {
        let l = orns[i];
        if l <= 0 {
            continue;
        }
        let ptr_off = orn_ptrs_base + i * 2;
        if ptr_off + 1 >= data.len() {
            continue;
        }
        let j = (read_word(data, ptr_off) as usize).wrapping_add(orn_ptrs_base);
        // Simulate: is this a single tick with net delta = 0?
        let mut jl = j;
        let mut k = 0usize;
        let mut n = 0i32;
        let mut nb = 0i32;
        'outer: loop {
            let mut jj = jl;
            loop {
                let tmp = n;
                let delta = data.get(jj + 1).copied().unwrap_or(0) as i8 as i32;
                n = n.wrapping_add(delta);
                if n < -0x55 || n > 0x55 { break 'outer; }
                let flags = data.get(jj).copied().unwrap_or(0);
                if (flags as i8) < 0 {
                    nb = tmp;
                    jl = jj;
                }
                k += 1;
                jj += 2;
                if k >= MAX_ORN_LEN { break 'outer; }
                if (flags & 0x40) != 0 { break; }
            }
            if k >= MAX_ORN_LEN || n == nb || n < -0x55 || n > 0x55 { break; }
        }
        if k == 1 && n == 0 {
            return l as usize;
        }
    }
    0
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
