//! ZXAY (*.ay) container format parser.
//!
//! The ZXAY container wraps one or more AY sub-songs identified by a 4-byte
//! magic `"ZXAY"` and a 4-byte TypeID.  Two TypeID variants are handled:
//!
//! - **ST11** (`b"ST11"`) — embeds a Sound Tracker 1 binary module.  The
//!   module data is converted to STC format via [`st1_to_stc`] and then parsed
//!   by [`super::stc::parse`].
//! - **AMAD** (`b"AMAD"`) — contains raw Z80 machine code plus a custom player
//!   routine.  Playback requires a Z80 emulator which is out of scope; metadata
//!   is extracted but an error is returned when song data is requested.
//!
//! Reference: `legacy/trfuncs.pas` (file-loading section ~lines 7310–7460)
//! and `ST12STC` (lines 4102–4394).

use crate::types::Module;
use anyhow::{bail, ensure, Result};

// ── ZXAY magic / TypeID constants ────────────────────────────────────────────

const ZXAY_MAGIC: &[u8; 4] = b"ZXAY";
const TYPE_ST11: &[u8; 4] = b"ST11";
const TYPE_AMAD: &[u8; 4] = b"AMAD";

// ── ZXAY header field offsets (all 2-byte offsets are big-endian signed) ─────
//
//   0: FileID          (4 bytes) = "ZXAY"
//   4: TypeID          (4 bytes) = "ST11" | "AMAD"
//   8: FileVersion     (1 byte)
//   9: PlayerVersion   (1 byte)
//  10: PSpecialPlayer  (i16 BE, relative from byte 10)
//  12: PAuthor         (i16 BE, relative from byte 12)
//  14: PMisc           (i16 BE, relative from byte 14)
//  16: NumOfSongs      (1 byte)
//  17: FirstSong       (1 byte, 0-based index of preferred first song)
//  18: PSongsStructure (i16 BE, relative from byte 18)

const OFF_FILE_ID: usize = 0;
const OFF_TYPE_ID: usize = 4;
const OFF_P_AUTHOR: usize = 12;
const OFF_NUM_SONGS: usize = 16;
const OFF_P_SONGS: usize = 18;
const HEADER_SIZE: usize = 20;

// ── ST1 binary layout (TSpeccyModule case 14) ────────────────────────────────
//
//   ST1_Smp   : array[1..15] of TST1Smp   @ 0       (15 × 130 = 1950 bytes)
//   ST1_Pos   : array[0..255] of TST1Pos  @ 1950    (256 × 2  = 512  bytes)
//   ST1_PosLen: byte                       @ 2462
//   ST1_Orn   : array[0..16] of TST1Orn   @ 2463    (17 × 32  = 544  bytes)
//   ST1_Del   : byte                       @ 3007
//   ST1_PatLen: byte                       @ 3008
//   ST1_Pat   : array[0..64] of TST1Pat   @ 3009    (65 × 576 bytes max)
//
// TST1Smp  = { Vl[32]: byte, Ns[32]: byte, Tn[32]: word, LPos: byte, LLen: byte } = 130 bytes
// TST1Pos  = { PNum: byte, PTrans: byte } = 2 bytes
// TST1Orn  = array[0..31] of i8 = 32 bytes
// TST11PatLn = [Nt, ESNum, EONum: byte] × 3 channels = 9 bytes per row
// TST1Pat  = array[0..63] of TST11PatLn = 576 bytes

const ST1_SMP_BASE: usize = 0;
const ST1_SMP_SIZE: usize = 130;
const ST1_SMP_VL: usize = 0; // offset of Vl[0] within a sample entry
const ST1_SMP_NS: usize = 32; // offset of Ns[0]
const ST1_SMP_TN: usize = 64; // offset of Tn[0] (u16 LE each)
const ST1_SMP_LPOS: usize = 128;
const ST1_SMP_LLEN: usize = 129;

const ST1_POS_BASE: usize = 1950;
const ST1_POS_ENTRY: usize = 2; // { PNum(1), PTrans(1) }
const ST1_POS_LEN: usize = 2462;

/// Semitones per octave, used when converting ST1 note encoding to VTM note index.
const SEMITONES_PER_OCTAVE: usize = 12;

const ST1_ORN_BASE: usize = 2463;
const ST1_ORN_SIZE: usize = 32;

const ST1_DEL: usize = 3007;
const ST1_PAT_LEN: usize = 3008;
const ST1_PAT_BASE: usize = 3009;
const ST1_PAT_SIZE: usize = 576; // 64 rows × 9 bytes per row
const ST1_ROW_SIZE: usize = 9; // 3 channels × 3 bytes
const ST1_CHAN_SIZE: usize = 3; // { Nt, ESNum, EONum }
const ST1_MAX_PAT: usize = 64; // patterns indexed 0..=64
const ST1_MIN_VALID: usize = ST1_PAT_BASE + ST1_PAT_SIZE; // 3585 bytes

/// Maps ST1 note-name index (1..7) → semitone offset within the octave.
/// Ported from Pascal: `st1nts: array[1..7] of integer = (9, 11, 0, 2, 4, 5, 7)`
/// Indices: 1=A, 2=B, 3=C, 4=D, 5=E, 6=F, 7=G.  Index 0 is a dummy.
const ST1_NTS: [u8; 8] = [0, 9, 11, 0, 2, 4, 5, 7];

// ── Public types ──────────────────────────────────────────────────────────────

/// Metadata for a single sub-song inside a ZXAY container.
#[derive(Debug, Clone)]
pub struct SongInfo {
    /// Display name of the sub-song read from the ZXAY string table.
    pub name: String,
    /// `true` if the sub-song uses the ST11 sub-format and can be parsed into
    /// a [`Module`].  `false` for AMAD sub-songs (raw Z80 player).
    pub is_supported: bool,
}

// ── Public API ────────────────────────────────────────────────────────────────

/// Return metadata for every sub-song in a ZXAY container without parsing the
/// song data itself.
pub fn list_songs(data: &[u8]) -> Result<Vec<SongInfo>> {
    let (type_id, _author, songs_base, num_songs) = parse_header(data)?;
    let is_amad = type_id == *TYPE_AMAD;
    let mut songs = Vec::with_capacity(num_songs);
    for i in 0..num_songs {
        let song_struct_off = songs_base + i * 4;
        let name = read_song_name(data, song_struct_off).unwrap_or_default();
        songs.push(SongInfo {
            name,
            is_supported: !is_amad,
        });
    }
    Ok(songs)
}

/// Parse a ZXAY file and return the [`Module`] for sub-song `song_index`
/// (0-based).
///
/// Use [`list_songs`] to discover how many sub-songs are present and to get
/// their display names before choosing an index.
pub fn parse(data: &[u8], song_index: usize) -> Result<Module> {
    let (type_id, author, songs_base, num_songs) = parse_header(data)?;

    ensure!(
        song_index < num_songs,
        "AY: song index {} out of range (file has {} sub-song(s))",
        song_index,
        num_songs
    );

    let song_struct_off = songs_base + song_index * 4;
    let song_name = read_song_name(data, song_struct_off).unwrap_or_default();

    if type_id == *TYPE_AMAD {
        bail!(
            "AY: sub-song {:?} uses the AMAD sub-format (raw Z80 player) \
             which requires Z80 emulation — import is not supported",
            song_name
        );
    }

    // PSongData is the second field (offset +2) of each TSongStructure entry.
    // It holds a big-endian relative offset from its own position in the file.
    let song_data_field = song_struct_off + 2;
    let song_data_abs = resolve_offset(data, song_data_field)?;

    // ST11: the raw ST1 binary starts 8 bytes into the TSongData block.
    // The first 8 bytes (ChanA, ChanB, ChanC, Noise, SongLength, FadeLength)
    // are player configuration used only by the AMAD player; they are skipped.
    let st1_start = song_data_abs.saturating_add(8);
    ensure!(
        st1_start <= data.len(),
        "AY: ST11 song data offset {} is beyond file end",
        st1_start
    );

    let raw_st1 = &data[st1_start..];

    // Trim to exact multiple of pattern size (megamix1.ay has 1 extra byte).
    if raw_st1.len() < ST1_MIN_VALID {
        bail!(
            "AY: ST11 song data too small ({} bytes, minimum {})",
            raw_st1.len(),
            ST1_MIN_VALID
        );
    }
    let excess = raw_st1.len().saturating_sub(ST1_PAT_BASE);
    let st1_len = ST1_PAT_BASE + (excess / ST1_PAT_SIZE) * ST1_PAT_SIZE;
    let st1_data = &raw_st1[..st1_len];

    let stc_data = st1_to_stc(st1_data)
        .map_err(|e| anyhow::anyhow!("AY: ST1→STC conversion failed: {e}"))?;

    let mut module = super::stc::parse(&stc_data)
        .map_err(|e| anyhow::anyhow!("AY: STC parse failed after conversion: {e}"))?;

    // Override title and author from ZXAY metadata; the ST1 binary carries
    // only a generic compiled-in name ("SONG BY ST COMPILE").
    if !song_name.is_empty() {
        module.title = song_name;
    }
    if !author.is_empty() {
        module.author = author;
    }

    Ok(module)
}

// ── Internal helpers ──────────────────────────────────────────────────────────

/// Parse the ZXAY header.  Returns `(type_id, author, songs_base, num_songs)`.
fn parse_header(data: &[u8]) -> Result<([u8; 4], String, usize, usize)> {
    ensure!(
        data.len() >= HEADER_SIZE,
        "AY: file too small to be a ZXAY container ({} bytes)",
        data.len()
    );
    ensure!(
        &data[OFF_FILE_ID..OFF_FILE_ID + 4] == ZXAY_MAGIC,
        "AY: not a ZXAY file (expected magic {:?}, got {:?})",
        ZXAY_MAGIC,
        &data[OFF_FILE_ID..OFF_FILE_ID + 4]
    );

    let type_id: [u8; 4] = data[OFF_TYPE_ID..OFF_TYPE_ID + 4].try_into().unwrap();
    ensure!(
        &type_id == TYPE_ST11 || &type_id == TYPE_AMAD,
        "AY: unsupported ZXAY sub-format \"{}\"",
        String::from_utf8_lossy(&type_id)
    );

    let author_off = resolve_offset(data, OFF_P_AUTHOR).unwrap_or(0);
    let author = if author_off < data.len() {
        truncate_str(read_cstring(data, author_off), 32)
    } else {
        String::new()
    };

    let num_songs = data[OFF_NUM_SONGS] as usize;
    ensure!(num_songs > 0, "AY: file contains no sub-songs");

    let songs_base = resolve_offset(data, OFF_P_SONGS)?;

    Ok((type_id, author, songs_base, num_songs))
}

/// Read the display name of the sub-song whose `TSongStructure` starts at
/// `song_struct_off`.
fn read_song_name(data: &[u8], song_struct_off: usize) -> Result<String> {
    ensure!(
        song_struct_off + 4 <= data.len(),
        "AY: song structure at offset {} is out of bounds",
        song_struct_off
    );
    // PSongName is the first 2-byte field of TSongStructure.
    let name_abs = resolve_offset(data, song_struct_off)?;
    let name = if name_abs < data.len() {
        truncate_str(read_cstring(data, name_abs), 32)
    } else {
        String::new()
    };
    Ok(name)
}

/// Resolve a ZXAY relative offset.
///
/// The 2 bytes at `field_pos` in `data` encode a big-endian signed 16-bit
/// integer that is added to `field_pos` to give an absolute file offset.
fn resolve_offset(data: &[u8], field_pos: usize) -> Result<usize> {
    ensure!(
        field_pos + 2 <= data.len(),
        "AY: relative-offset field at {} is past end of file",
        field_pos
    );
    let rel = i16::from_be_bytes([data[field_pos], data[field_pos + 1]]) as i64;
    let abs = field_pos as i64 + rel;
    ensure!(
        abs >= 0 && (abs as usize) <= data.len(),
        "AY: resolved offset {} is out of file bounds",
        abs
    );
    Ok(abs as usize)
}

/// Read a null-terminated Latin-1 string from `data` starting at `off`,
/// trimming leading/trailing ASCII whitespace.
fn read_cstring(data: &[u8], off: usize) -> String {
    if off >= data.len() {
        return String::new();
    }
    let slice = &data[off..];
    let len = slice.iter().position(|&b| b == 0).unwrap_or(slice.len());
    String::from_utf8_lossy(&slice[..len]).trim().to_string()
}

fn truncate_str(mut s: String, max: usize) -> String {
    s.truncate(max);
    s
}

// ── ST1 → STC conversion ──────────────────────────────────────────────────────

/// Convert a Sound Tracker 1 (ST1) binary blob into a Sound Tracker Compiled
/// (STC) binary suitable for [`super::stc::parse`].
///
/// Ported from `ST12STC` in `legacy/trfuncs.pas` (lines 4102–4394).
fn st1_to_stc(data: &[u8]) -> Result<Vec<u8>> {
    // ── Validate basic size constraints ───────────────────────────────────────
    ensure!(data.len() > ST1_PAT_BASE, "ST1: data too small");
    ensure!(
        (data.len() - ST1_PAT_BASE) % ST1_PAT_SIZE == 0,
        "ST1: size {} not aligned to pattern stride {}",
        data.len(),
        ST1_PAT_SIZE
    );

    // n_phys: number of physical pattern slots in the file (1-based count)
    let n_phys = (data.len() - ST1_PAT_BASE) / ST1_PAT_SIZE;
    ensure!(n_phys >= 1, "ST1: no physical patterns in file");
    // Pascal: NPats = (msize - 3009) / 576 - 1  →  highest valid pattern slot index
    let n_pats_max = n_phys - 1;
    ensure!(
        n_pats_max <= ST1_MAX_PAT,
        "ST1: pattern count {} exceeds maximum {}",
        n_pats_max,
        ST1_MAX_PAT
    );

    let pat_len = data[ST1_PAT_LEN] as usize;
    ensure!(
        (1..=64).contains(&pat_len),
        "ST1: pattern length {} is out of range [1..64]",
        pat_len
    );

    let delay = data[ST1_DEL];
    let pos_len = data[ST1_POS_LEN] as usize; // 0-based last valid position index

    // ── Scan the position table ───────────────────────────────────────────────
    // Every entry (even those beyond pos_len) must have PNum != 0 because the
    // format always fills all 256 slots.
    let mut pat_used = [false; ST1_MAX_PAT + 1];
    let mut pat_exists = [false; ST1_MAX_PAT + 1];
    let mut n_pats_u = 0usize; // number of patterns actually referenced
    let mut n_pats_e = 0usize; // number of distinct patterns that exist

    for i in 0..=255usize {
        let pnum_off = ST1_POS_BASE + i * ST1_POS_ENTRY;
        ensure!(
            pnum_off + 1 < data.len(),
            "ST1: position table truncated at entry {}",
            i
        );
        let pnum = data[pnum_off] as usize;
        ensure!(pnum != 0, "ST1: position {} has PNum=0 (invalid)", i);
        let n = pnum - 1; // convert 1-based to 0-based index
        ensure!(
            n <= ST1_MAX_PAT,
            "ST1: pattern index {} at position {} exceeds maximum",
            n,
            i
        );

        if !pat_used[n] && i <= pos_len {
            n_pats_u += 1;
            pat_used[n] = true;
        }
        if !pat_exists[n] {
            n_pats_e += 1;
            pat_exists[n] = true;
        }
    }

    ensure!(n_pats_u > 0, "ST1: no patterns are used by the position list");

    // Trim unused patterns beyond the last used one (fixes broken modules).
    for i in (0..=ST1_MAX_PAT).rev() {
        if pat_used[i] {
            break;
        }
        if pat_exists[i] {
            pat_exists[i] = false;
            n_pats_e -= 1;
        }
    }

    ensure!(
        n_pats_e == 0 || n_pats_e - 1 <= n_pats_max,
        "ST1: {} referenced patterns exceed the {} physical slots",
        n_pats_e,
        n_pats_max + 1
    );

    // ── Build STC channel bytecode for each used pattern ──────────────────────
    // chan_ofs: (logical_pat_index, [offset_ch0, offset_ch1, offset_ch2])
    //          where offsets are byte positions within `pats_bytecodes`.
    let mut pats_bytecodes: Vec<u8> = Vec::new();
    let mut chan_ofs: Vec<(usize, [usize; 3])> = Vec::new();

    let mut smp_used = [false; 16]; // indices 1..=15
    let mut orn_used = [false; 16]; // indices 0..=15
    orn_used[0] = true; // ornament 0 ("no ornament") is always present

    let mut ir = 0usize; // physical ST1 pattern slot index (contiguous from 0)
    for i in 0..=ST1_MAX_PAT {
        if !pat_exists[i] {
            continue;
        }
        if pat_used[i] {
            let mut ofs = [0usize; 3];
            for c in 0..3usize {
                let bytecode = build_channel_bytecode(
                    data, ir, c, pat_len, &mut smp_used, &mut orn_used,
                )?;
                ofs[c] = pats_bytecodes.len();
                pats_bytecodes.extend_from_slice(&bytecode);
            }
            chan_ofs.push((i, ofs));
        }
        ir += 1;
    }

    // ── Assemble the STC output buffer ────────────────────────────────────────
    //
    // STC layout (from stc.rs):
    //   [0]     ST_Delay
    //   [1-2]   ST_PositionsPointer (u16 LE, absolute offset)
    //   [3-4]   ST_OrnamentsPointer (u16 LE, absolute offset)
    //   [5-6]   ST_PatternsPointer  (u16 LE, absolute offset)
    //   [7-24]  ST_Name             (18 bytes)
    //   [25-26] ST_Size             (u16 LE)
    //   [27+]   samples (sequentially, used only), then positions, ornaments,
    //           pattern table, channel bytecodes.

    let mut stc: Vec<u8> = Vec::with_capacity(512);
    stc.resize(27, 0u8); // header placeholder
    stc[0] = delay;
    stc[7..25].copy_from_slice(b"SONG BY ST COMPILE");

    // ── Samples ───────────────────────────────────────────────────────────────
    for i in 1..=15usize {
        if !smp_used[i] {
            continue;
        }
        let sbase = ST1_SMP_BASE + (i - 1) * ST1_SMP_SIZE;
        stc.push(i as u8); // STC sample index (stc::parse adds 1 to get VTM idx)
        for j in 0..32usize {
            let vl = data[sbase + ST1_SMP_VL + j];
            let ns = data[sbase + ST1_SMP_NS + j];
            let tn_lo = data[sbase + ST1_SMP_TN + j * 2];
            let tn_hi = data[sbase + ST1_SMP_TN + j * 2 + 1];
            let tn = u16::from_le_bytes([tn_lo, tn_hi]);
            // b0 = amplitude(Vl & 0xF) | Tn[11:8] packed into bits 7:4
            let b0 = (vl & 0x0F) | (((tn & 0x0F00) >> 4) as u8);
            // b1 = (Ns & ~bit5) | Tn[12] shifted to bit 5 (= tone direction)
            let b1 = (ns & 0xDF) | (((tn & 0x1000) >> 7) as u8);
            // b2 = Tn low byte
            let b2 = (tn & 0xFF) as u8;
            stc.push(b0);
            stc.push(b1);
            stc.push(b2);
        }
        stc.push(data[sbase + ST1_SMP_LPOS]);
        stc.push(data[sbase + ST1_SMP_LLEN]);
    }

    // Ensure the buffer is large enough for stc::parse's MIN_FILE_SIZE check
    // (SAMPLES_BASE=27 + SAMPLE_ENTRY_SIZE=99 = 126).  Zero-pad as needed;
    // the padding lands in unused sample slots that the parser will skip.
    while stc.len() < 126 {
        stc.push(0u8);
    }

    // ── Positions ─────────────────────────────────────────────────────────────
    let pos_ptr = stc.len() as u16;
    stc.push(pos_len as u8); // count byte = index of last position
    for i in 0..=(pos_len) {
        let off = ST1_POS_BASE + i * ST1_POS_ENTRY;
        stc.push(*data.get(off).unwrap_or(&0)); // PNum
        stc.push(*data.get(off + 1).unwrap_or(&0)); // PTrans
    }

    // ── Ornaments ─────────────────────────────────────────────────────────────
    let orn_ptr = stc.len() as u16;
    for i in 0..=15usize {
        if !orn_used[i] {
            continue;
        }
        stc.push(i as u8);
        let obase = ST1_ORN_BASE + i * ST1_ORN_SIZE;
        for j in 0..32usize {
            stc.push(*data.get(obase + j).unwrap_or(&0));
        }
    }

    // ── Pattern table ─────────────────────────────────────────────────────────
    let pat_ptr = stc.len() as u16;
    // Bytecode region starts right after: pattern table entries (7 bytes each)
    // plus the $FF terminator.
    let bytecode_start = stc.len() + chan_ofs.len() * 7 + 1;

    for (pat_i, ofs) in &chan_ofs {
        stc.push((*pat_i + 1) as u8); // 1-indexed pattern number
        for c in 0..3usize {
            let abs_ofs = (bytecode_start + ofs[c]) as u16;
            stc.push(abs_ofs as u8);
            stc.push((abs_ofs >> 8) as u8);
        }
    }
    stc.push(0xFF); // pattern table terminator

    // ── Channel bytecodes ─────────────────────────────────────────────────────
    stc.extend_from_slice(&pats_bytecodes);

    // ── Back-fill header pointers ─────────────────────────────────────────────
    let stc_size = stc.len() as u16;
    stc[1] = pos_ptr as u8;
    stc[2] = (pos_ptr >> 8) as u8;
    stc[3] = orn_ptr as u8;
    stc[4] = (orn_ptr >> 8) as u8;
    stc[5] = pat_ptr as u8;
    stc[6] = (pat_ptr >> 8) as u8;
    stc[25] = stc_size as u8;
    stc[26] = (stc_size >> 8) as u8;

    Ok(stc)
}

/// Build STC channel bytecode for channel `c` of physical pattern slot `ir`.
///
/// Ported from the inner loop of `ST12STC` in `trfuncs.pas`.
///
/// The ST1 pattern row encoding:
/// - `Nt` byte: `note_name = Nt >> 4`, `octave = Nt & 7`, `sharp = (Nt & 8) != 0`
///   - `note_name == 0`  → empty (no note)
///   - `note_name 1..7`  → note A..G  (via [`ST1_NTS`] lookup)
///   - `note_name & 8`   → sound off
/// - `ESNum` byte: `sample = ESNum >> 4`, `env_or_orn = ESNum & 0xF`
/// - `EONum` byte: envelope period or ornament index
fn build_channel_bytecode(
    data: &[u8],
    ir: usize,
    c: usize,
    pat_len: usize,
    smp_used: &mut [bool; 16],
    orn_used: &mut [bool; 16],
) -> Result<Vec<u8>> {
    let mut pat: Vec<u8> = Vec::new();
    let mut empty: i32 = -1; // -1 = "no skip byte emitted yet"
    let mut cur_sam: i32 = -1;
    let mut cur_orn: i32 = -1;
    let mut cur_et: i32 = -1; // current envelope type
    let mut cur_ep: i32 = -1; // current envelope period

    let mut j = 0usize;
    while j < pat_len {
        let nt = st1_nt(data, ir, j, c);
        let note_name = (nt >> 4) as usize; // high nibble

        // Count consecutive empty rows *after* row j (for the STC skip byte).
        let new_empty = count_empty_after(data, ir, j, c, pat_len);
        if new_empty as i32 != empty {
            empty = new_empty as i32;
            pat.push(0xA1u8 + new_empty); // $A1 + N = "skip N rows after this one"
        }

        if note_name == 0 {
            // Empty row
            pat.push(0x81); // end-of-row (no note change)
        } else {
            // Non-empty row: emit sample / envelope-or-ornament / note
            let esnum = st1_esnum(data, ir, j, c);
            let eonum = st1_eonum(data, ir, j, c);

            // Sample select (high nibble of ESNum, 1..15)
            let sn = (esnum >> 4) as usize;
            if (1..=15).contains(&sn) && sn as i32 != cur_sam {
                cur_sam = sn as i32;
                pat.push(0x60 + sn as u8); // $61..$6F
                smp_used[sn] = true;
            }

            // Envelope type (ESNum low nibble 7..14) or ornament (1 or 15)
            let en = (esnum & 0x0F) as usize;
            if (7..=14).contains(&en) {
                if en as i32 != cur_et || eonum as i32 != cur_ep {
                    cur_orn = -1;
                    cur_et = en as i32;
                    cur_ep = eonum as i32;
                    pat.push(0x80 + en as u8); // $87..$8E → cl.envelope = 7..14
                    pat.push(eonum); // envelope period (1 byte)
                }
            } else if en == 1 || en == 15 {
                let o = if en == 1 { 0usize } else { (eonum & 0x0F) as usize };
                if o as i32 != cur_orn {
                    cur_et = -1;
                    cur_ep = -1;
                    cur_orn = o as i32;
                    orn_used[o] = true;
                    if en == 1 && o == 0 {
                        pat.push(0x82); // clear ornament
                    } else {
                        pat.push(0x70 + o as u8); // $70..$7F
                    }
                }
            }
            // en == 0,2..6: no ornament/envelope change

            // Note byte
            if note_name & 8 == 0 {
                // Regular note: decode and range-check
                let octave = (nt & 7) as usize;
                let sharp: usize = if (nt & 8) != 0 { 1 } else { 0 };
                ensure!(
                    !(note_name == 2 && sharp == 1) && !(note_name == 5 && sharp == 1),
                    "ST1: invalid note (B# or E#) at pattern {}, row {}, ch {}",
                    ir,
                    j,
                    c
                );
                let vtm_note = ST1_NTS[note_name] as usize + octave * SEMITONES_PER_OCTAVE + sharp;
                ensure!(
                    vtm_note <= 0x5F,
                    "ST1: note value {} out of range at pattern {}, row {}, ch {}",
                    vtm_note,
                    ir,
                    j,
                    c
                );
                pat.push(vtm_note as u8);
            } else {
                pat.push(0x80); // sound off
            }
        }

        j += empty as usize; // advance over any trailing empty rows
        j += 1;
    }
    pat.push(0xFF); // end-of-pattern marker
    Ok(pat)
}

/// Count the number of empty rows immediately after row `j` for channel `c`
/// in physical pattern slot `ir`.
///
/// A row is "empty" when `(Nt & 0xF0) == 0` (note-name nibble is zero).
/// Ported from the `CalcEmpty` nested function in `ST12STC`.
fn count_empty_after(data: &[u8], ir: usize, j: usize, c: usize, pat_len: usize) -> u8 {
    let mut count = 0u8;
    let mut n = j + 1;
    while n < pat_len {
        if st1_nt(data, ir, n, c) & 0xF0 == 0 {
            count += 1;
            n += 1;
        } else {
            break;
        }
    }
    count
}

// ── ST1 binary accessors ──────────────────────────────────────────────────────

#[inline]
fn st1_nt(data: &[u8], ir: usize, row: usize, ch: usize) -> u8 {
    let off = ST1_PAT_BASE + ir * ST1_PAT_SIZE + row * ST1_ROW_SIZE + ch * ST1_CHAN_SIZE;
    *data.get(off).unwrap_or(&0)
}

#[inline]
fn st1_esnum(data: &[u8], ir: usize, row: usize, ch: usize) -> u8 {
    let off = ST1_PAT_BASE + ir * ST1_PAT_SIZE + row * ST1_ROW_SIZE + ch * ST1_CHAN_SIZE + 1;
    *data.get(off).unwrap_or(&0)
}

#[inline]
fn st1_eonum(data: &[u8], ir: usize, row: usize, ch: usize) -> u8 {
    let off = ST1_PAT_BASE + ir * ST1_PAT_SIZE + row * ST1_ROW_SIZE + ch * ST1_CHAN_SIZE + 2;
    *data.get(off).unwrap_or(&0)
}

// ── Tests ─────────────────────────────────────────────────────────────────────

#[cfg(test)]
mod tests {
    use super::*;

    /// Build a minimal but fully valid ZXAY+ST11 binary (3635 bytes).
    ///
    /// Layout:
    ///   offset  0: ZXAY header (20 bytes)
    ///   offset 20: padding (2 bytes)
    ///   offset 22: author string "Tst\0" (4 bytes)
    ///   offset 26: padding (4 bytes)
    ///   offset 30: TSongStructure for song 0 (4 bytes)
    ///   offset 34: padding (4 bytes)
    ///   offset 38: song name string "Tst\0" (4 bytes)
    ///   offset 42: TSongData header (8 zero bytes, skipped)
    ///   offset 50: ST1 binary (3585 bytes = 3009 header + 576 pattern)
    fn build_minimal_ay() -> Vec<u8> {
        let mut data = vec![0u8; 3635];

        // ── ZXAY header ──────────────────────────────────────────────────────
        data[0..4].copy_from_slice(b"ZXAY");
        data[4..8].copy_from_slice(b"ST11");
        // data[8]  = FileVersion   = 0
        // data[9]  = PlayerVersion = 0
        // data[10..12] = PSpecialPlayer = 0 (unused)
        // PAuthor (field at 12): relative offset 10 → author at 12+10 = 22
        data[12..14].copy_from_slice(&[0x00, 0x0A]);
        // data[14..16] = PMisc = 0 (unused)
        data[16] = 1; // NumOfSongs
        data[17] = 0; // FirstSong
        // PSongsStructure (field at 18): relative offset 12 → songs at 18+12 = 30
        data[18..20].copy_from_slice(&[0x00, 0x0C]);

        // ── Author string at offset 22 ───────────────────────────────────────
        data[22..26].copy_from_slice(b"Tst\0");

        // ── TSongStructure for song 0 at offset 30 ───────────────────────────
        // PSongName (field at 30): relative offset 8 → name at 30+8 = 38
        data[30..32].copy_from_slice(&[0x00, 0x08]);
        // PSongData (field at 32): relative offset 10 → data at 32+10 = 42
        data[32..34].copy_from_slice(&[0x00, 0x0A]);

        // ── Song name string at offset 38 ────────────────────────────────────
        data[38..42].copy_from_slice(b"Tst\0");

        // TSongData header at offset 42 (8 zero bytes that ST11 parsing skips)
        // ST1 binary starts at offset 50

        // ── ST1 binary ───────────────────────────────────────────────────────
        // Samples (offsets 50..1999): all zeros (no samples used)
        // Positions (offsets 2000..2511): PNum=1, PTrans=0 for all 256 entries
        for i in 0..256usize {
            data[2000 + i * 2] = 1; // PNum = 1 (references pattern index 0)
            data[2001 + i * 2] = 0; // PTrans = 0
        }
        // ST1_PosLen at offset 2512 = 0 (1 position: index 0)
        data[2512] = 0;
        // Ornaments (offsets 2513..3056): all zeros
        // ST1_Del at offset 3057 = 6
        data[3057] = 6;
        // ST1_PatLen at offset 3058 = 1 (one row per pattern)
        data[3058] = 1;
        // ST1_Pat[0] at offsets 3059..3634: all zeros (empty rows)

        data
    }

    // ── Header / magic tests ──────────────────────────────────────────────────

    #[test]
    fn reject_wrong_magic() {
        let mut data = build_minimal_ay();
        data[0..4].copy_from_slice(b"NOPE");
        assert!(parse(&data, 0).is_err());
    }

    #[test]
    fn reject_too_short() {
        let data = vec![0u8; 10];
        assert!(parse(&data, 0).is_err());
    }

    #[test]
    fn reject_song_index_out_of_range() {
        let data = build_minimal_ay();
        assert!(parse(&data, 1).is_err());
    }

    // ── AMAD sub-format ───────────────────────────────────────────────────────

    #[test]
    fn amad_parse_returns_error() {
        let mut data = build_minimal_ay();
        data[4..8].copy_from_slice(b"AMAD");
        assert!(parse(&data, 0).is_err());
    }

    #[test]
    fn amad_list_songs_marks_unsupported() {
        let mut data = build_minimal_ay();
        data[4..8].copy_from_slice(b"AMAD");
        let songs = list_songs(&data).unwrap();
        assert_eq!(songs.len(), 1);
        assert!(!songs[0].is_supported);
        assert_eq!(songs[0].name, "Tst");
    }

    // ── ST11 round-trip ───────────────────────────────────────────────────────

    #[test]
    fn st11_parse_succeeds() {
        let data = build_minimal_ay();
        let module = parse(&data, 0).unwrap();
        assert_eq!(module.title, "Tst");
        assert_eq!(module.author, "Tst");
        assert_eq!(module.initial_delay, 6);
        assert_eq!(module.positions.length, 1);
    }

    #[test]
    fn st11_list_songs_returns_metadata() {
        let data = build_minimal_ay();
        let songs = list_songs(&data).unwrap();
        assert_eq!(songs.len(), 1);
        assert_eq!(songs[0].name, "Tst");
        assert!(songs[0].is_supported);
    }

    #[test]
    fn st11_pattern_has_one_empty_row() {
        let data = build_minimal_ay();
        let module = parse(&data, 0).unwrap();
        let pat = module.patterns[0].as_deref().expect("pattern 0 should exist");
        assert_eq!(pat.length, 1, "pattern should have 1 row (PatLen=1)");
        // All channels should have no note (NOTE_NONE)
        for ch in 0..3 {
            assert_eq!(
                pat.items[0].channel[ch].note,
                crate::types::NOTE_NONE,
                "channel {ch} row 0 should be NOTE_NONE"
            );
        }
    }

    // ── st1_to_stc unit tests ─────────────────────────────────────────────────

    #[test]
    fn st1_to_stc_minimal() {
        let data = build_minimal_ay();
        let st1 = &data[50..]; // ST1 binary starts at offset 50
        let stc = st1_to_stc(st1).expect("st1_to_stc should not fail on minimal data");
        // STC buffer must be at least 126 bytes (stc::parse MIN_FILE_SIZE)
        assert!(stc.len() >= 126, "stc output too short: {} bytes", stc.len());
        // Verify the STC can be parsed
        super::super::stc::parse(&stc).expect("stc::parse should succeed");
    }

    #[test]
    fn st1_too_small_is_rejected() {
        let data = vec![0u8; 100];
        assert!(st1_to_stc(&data).is_err());
    }

    #[test]
    fn st1_unaligned_size_is_rejected() {
        let mut data = vec![0u8; ST1_MIN_VALID + 1]; // off by 1
        // Fill all positions with PNum=1
        for i in 0..256 {
            data[ST1_POS_BASE + i * 2] = 1;
        }
        data[ST1_PAT_LEN] = 1;
        assert!(st1_to_stc(&data).is_err());
    }
}
