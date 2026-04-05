//! ZX Spectrum export — ported from `ExportZX.pas` / `main.pas`
//! (`SaveforZXMenuClick`), with an added compactness improvement:
//! the PT3 binary is written with deduplicated sample/ornament data
//! (see `pt3::write()`).
//!
//! # Supported output formats
//!
//! | Variant | Extension | Description |
//! |---------|-----------|-------------|
//! | `HobetaCode` | `.$C` | Hobeta code block, includes player |
//! | `HobetaMem`  | `.$M` | Hobeta memory block, data only |
//! | `AyFile`     | `.ay`  | ZXAY/EMUL AY file (emulator-compatible) |
//! | `Scl`        | `.scl` | Sinclair disc image (2-file container) |
//! | `Tap`        | `.tap` | ZX Spectrum tape image (2-block pair) |
//!
//! The ZX player binaries are embedded at compile time from
//! `src/formats/assets/ZXAY.bin` and `src/formats/assets/ZXTS.bin`.
//! These were extracted from the original `ZXAYHOBETA/ZX.RES` resource file.
//!
//! # Player binary layout (both ZXAY.bin and ZXTS.bin)
//!
//! ```text
//! Offset 0      : zxplsz  (LE u16) — player code size in bytes
//! Offset 2      : zxdtsz  (LE u16) — variables area size (comes after player in ZX RAM)
//! Offset 4      : player code (zxplsz bytes, compiled for org 0x0000)
//! Offset 4+plsz : relocation tables — three sections terminated by sentinel:
//!   • Word patches  : 2-byte offsets where out[off] += load_addr (16-bit LE)
//!   • Byte-lo patch : 2-byte offsets where out[off] += lo(load_addr)
//!   • Hi-byte patch : (offset, base) pairs where out[off] = (base + load_addr) >> 8
//! ```

use crate::{formats::pt3, types::Module};
use anyhow::{bail, Result};

// ── Embedded player binaries ─────────────────────────────────────────────────

/// Single-chip AY player binary (VTII PT3 player r.7, origin 0x0000).
static ZXAY_BIN: &[u8] = include_bytes!("assets/ZXAY.bin");

/// Turbo-Sound (dual-chip) player binary.
#[allow(dead_code)]
static ZXTS_BIN: &[u8] = include_bytes!("assets/ZXTS.bin");

// ── Public types ─────────────────────────────────────────────────────────────

/// Output format for the ZX Spectrum export.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Default)]
pub enum ZxFormat {
    /// Hobeta code block (`.$C`) — includes the ZX player.
    #[default]
    HobetaCode,
    /// Hobeta memory block (`.$M`) — module data only, no player.
    HobetaMem,
    /// ZXAY/EMUL AY file (`.ay`) — emulator-compatible with header.
    AyFile,
    /// Sinclair disc image (`.scl`) — two-file container.
    Scl,
    /// ZX Spectrum tape image (`.tap`) — two-block pair.
    Tap,
}

impl ZxFormat {
    /// Default file extension for this format (without leading dot).
    pub fn extension(self) -> &'static str {
        match self {
            ZxFormat::HobetaCode => "$c",
            ZxFormat::HobetaMem => "$m",
            ZxFormat::AyFile => "ay",
            ZxFormat::Scl => "scl",
            ZxFormat::Tap => "tap",
        }
    }

    /// Human-readable label used in the save dialog.
    pub fn label(self) -> &'static str {
        match self {
            ZxFormat::HobetaCode => "Hobeta code block ($C)",
            ZxFormat::HobetaMem => "Hobeta memory block ($M)",
            ZxFormat::AyFile => "AY emulator file (*.ay)",
            ZxFormat::Scl => "Sinclair disc image (*.scl)",
            ZxFormat::Tap => "ZX Spectrum tape (*.tap)",
        }
    }
}

/// Options that control the ZX Spectrum export.
#[derive(Debug, Clone)]
pub struct ZxExportOptions {
    /// ZX Spectrum RAM address where the block is loaded (default: `0xC000`).
    pub load_addr: u16,
    /// Output format.
    pub format: ZxFormat,
    /// Whether the module should loop (sets bit 0 of the player's SETUP byte).
    pub looping: bool,
    /// Short name written into Hobeta / SCL / TAP headers (≤8 chars).
    pub name: String,
    /// Module title (used in `.ay` files).
    pub title: String,
    /// Module author (used in `.ay` files).
    pub author: String,
}

impl Default for ZxExportOptions {
    fn default() -> Self {
        ZxExportOptions {
            load_addr: 0xC000,
            format: ZxFormat::default(),
            looping: false,
            name: "module".to_string(),
            title: String::new(),
            author: String::new(),
        }
    }
}

// ── Public entry point ────────────────────────────────────────────────────────

/// Export `module` as a ZX Spectrum binary in the format specified by `opts`.
///
/// The PT3 data is serialised with the compactness improvement (deduplicated
/// sample/ornament data blocks).  The ZX player binary is relocated to
/// `opts.load_addr`.
///
/// Returns a `Vec<u8>` ready to write to disk.
pub fn export_zx(module: &Module, opts: &ZxExportOptions) -> Result<Vec<u8>> {
    // Serialise the module to PT3 (with deduplication applied by pt3::write).
    let pt3_bytes = pt3::write(module)?;
    let mod_size = pt3_bytes.len();

    let player_raw = ZXAY_BIN;
    let zxplsz = u16::from_le_bytes([player_raw[0], player_raw[1]]) as usize;
    let zxdtsz = u16::from_le_bytes([player_raw[2], player_raw[3]]) as usize;

    match opts.format {
        ZxFormat::HobetaMem => build_hobeta_mem(&pt3_bytes, mod_size, opts),
        ZxFormat::HobetaCode => {
            check_fits(zxplsz, zxdtsz, mod_size, 0)?;
            let player = apply_relocations(player_raw, opts.load_addr, opts.looping)?;
            build_hobeta_code(&player, &pt3_bytes, zxdtsz, opts)
        }
        ZxFormat::AyFile => {
            check_fits(zxplsz, zxdtsz, mod_size, 0)?;
            let player = apply_relocations(player_raw, opts.load_addr, opts.looping)?;
            build_ay_file(&player, &pt3_bytes, zxplsz, zxdtsz, opts)
        }
        ZxFormat::Scl => {
            check_fits(zxplsz, zxdtsz, mod_size, 0)?;
            let player = apply_relocations(player_raw, opts.load_addr, opts.looping)?;
            build_scl(&player, &pt3_bytes, zxplsz, zxdtsz, opts)
        }
        ZxFormat::Tap => {
            check_fits(zxplsz, zxdtsz, mod_size, 0)?;
            let player = apply_relocations(player_raw, opts.load_addr, opts.looping)?;
            build_tap(&player, &pt3_bytes, zxplsz, zxdtsz, opts)
        }
    }
}

// ── Relocation engine ─────────────────────────────────────────────────────────

/// Apply the three-section relocation table from the player binary and return
/// the relocated player code ready to load at `load_addr`.
///
/// When `looping` is true, bit 0 of the SETUP byte (player[10]) is set — this
/// matches the original Pascal `LoopChk.Checked` option.
fn apply_relocations(raw: &[u8], load_addr: u16, looping: bool) -> Result<Vec<u8>> {
    let zxplsz = u16::from_le_bytes([raw[0], raw[1]]) as usize;
    if raw.len() < 4 + zxplsz {
        bail!("ZX player binary is truncated");
    }
    let mut pl: Vec<u8> = raw[4..4 + zxplsz].to_vec();

    // Relocation tables start right after the player code.
    let mut p = 4 + zxplsz;
    let sentinel_word = |raw: &[u8], p: usize| -> u16 {
        if p + 1 < raw.len() {
            u16::from_le_bytes([raw[p], raw[p + 1]])
        } else {
            0xFFFF
        }
    };

    // ── Section 1: word patches ───────────────────────────────────────────────
    // Each entry is a 2-byte LE offset where the 16-bit LE word in `pl` is
    // incremented by `load_addr`.  Terminated by an entry >= (zxplsz - 1).
    loop {
        let off = sentinel_word(raw, p) as usize;
        if off >= zxplsz.saturating_sub(1) {
            break;
        }
        p += 2;
        let old = u16::from_le_bytes([pl[off], pl[off + 1]]);
        let new = old.wrapping_add(load_addr);
        pl[off] = new as u8;
        pl[off + 1] = (new >> 8) as u8;
    }
    p += 2; // skip terminator

    // ── Section 2: low-byte patches ──────────────────────────────────────────
    // Each entry is an offset where `pl[off] += lo(load_addr)`.
    loop {
        let off = sentinel_word(raw, p) as usize;
        if off >= zxplsz {
            break;
        }
        p += 2;
        pl[off] = pl[off].wrapping_add(load_addr as u8);
    }
    p += 2; // skip terminator

    // ── Section 3: high-byte patches ─────────────────────────────────────────
    // Each entry is a pair (offset, base): pl[offset] = (base + load_addr) >> 8.
    loop {
        if p + 3 >= raw.len() {
            break;
        }
        let off = sentinel_word(raw, p) as usize;
        if off >= zxplsz {
            break;
        }
        p += 2;
        let base = sentinel_word(raw, p);
        p += 2;
        pl[off] = ((base as u32 + load_addr as u32) >> 8) as u8;
    }

    // Apply loop flag (SETUP byte at offset 10, bit 0 = disable-loop when set).
    // Pascal: `if ExpDlg.LoopChk.Checked then pl[10] := pl[10] or 1`
    if looping {
        if pl.len() > 10 {
            pl[10] |= 1;
        }
    }

    Ok(pl)
}

// ── Format builders ───────────────────────────────────────────────────────────

/// Verify the combined block fits within 64 KiB of ZX RAM.
fn check_fits(zxplsz: usize, zxdtsz: usize, mod_size: usize, extra: usize) -> Result<()> {
    let total = zxplsz + zxdtsz + mod_size + extra;
    if total > 65536 {
        bail!(
            "Size of module with player ({} bytes) exceeds 65536 ZX RAM limit.",
            total
        );
    }
    Ok(())
}

/// Compute the Hobeta checksum.
///
/// The 17-byte Hobeta header has its checksum in the last 2 bytes.  The value
/// is: `(sum_of_bytes_0_to_14) * 257 + 105`.
fn hobeta_checksum(hdr: &[u8; 17]) -> u16 {
    let k: u32 = hdr[..15].iter().map(|&b| b as u32).sum();
    (k * 257 + 105) as u16
}

/// Build a 17-byte Hobeta header.
fn make_hobeta_hdr(
    name: &str,
    typ: u8,
    start: u16,
    len: usize,
) -> [u8; 17] {
    let mut hdr = [0u8; 17];
    // Name: 8 bytes, space-padded
    let name_bytes = name.as_bytes();
    let name_len = name_bytes.len().min(8);
    hdr[..name_len].copy_from_slice(&name_bytes[..name_len]);
    hdr[name_len..8].fill(b' ');
    // Type character
    hdr[8] = typ;
    // Start address (LE)
    hdr[9] = start as u8;
    hdr[10] = (start >> 8) as u8;
    // Length (LE)
    hdr[11] = len as u8;
    hdr[12] = (len >> 8) as u8;
    // Sector-rounded length (LE): rounds up to next 256-byte sector
    let sect_len = ((len + 255) & !255) as u16;
    hdr[13] = sect_len as u8;
    hdr[14] = (sect_len >> 8) as u8;
    // Checksum
    let cs = hobeta_checksum(&hdr);
    hdr[15] = cs as u8;
    hdr[16] = (cs >> 8) as u8;
    hdr
}

// ── Hobeta $C (code block with player) ───────────────────────────────────────

fn build_hobeta_code(
    player: &[u8],
    pt3: &[u8],
    zxdtsz: usize,
    opts: &ZxExportOptions,
) -> Result<Vec<u8>> {
    let total = player.len() + zxdtsz + pt3.len();
    let hdr = make_hobeta_hdr(&opts.name, b'C', opts.load_addr, total);
    let sect_len = ((total + 255) & !255) as usize;

    let mut out = Vec::with_capacity(17 + sect_len);
    out.extend_from_slice(&hdr);
    out.extend_from_slice(player);
    out.resize(out.len() + zxdtsz, 0); // zero-fill variables area
    out.extend_from_slice(pt3);
    // Pad to sector boundary
    out.resize(17 + sect_len, 0);
    Ok(out)
}

// ── Hobeta $M (memory dump, no player) ───────────────────────────────────────

fn build_hobeta_mem(
    pt3: &[u8],
    mod_size: usize,
    opts: &ZxExportOptions,
) -> Result<Vec<u8>> {
    let hdr = make_hobeta_hdr(&opts.name, b'm', opts.load_addr, mod_size);
    let sect_len = ((mod_size + 255) & !255) as usize;

    let mut out = Vec::with_capacity(17 + sect_len);
    out.extend_from_slice(&hdr);
    out.extend_from_slice(pt3);
    out.resize(17 + sect_len, 0);
    Ok(out)
}

// ── .ay (AY emulator file) ────────────────────────────────────────────────────

/// Big-endian u16 helper — AY file format uses big-endian relative offsets.
#[inline]
fn be16(v: u16) -> [u8; 2] {
    v.to_be_bytes()
}

fn build_ay_file(
    player: &[u8],
    pt3: &[u8],
    zxplsz: usize,
    zxdtsz: usize,
    opts: &ZxExportOptions,
) -> Result<Vec<u8>> {
    // String table that follows TPoints.
    let title = opts.title.as_bytes();
    let author = opts.author.as_bytes();
    let misc = b"Vortex Tracker II v1.0";

    // All AY relative pointers use: actual_pos = field_pos + field_BE_value.
    //
    // File layout after the TPoints block (file offset 38+20=58):
    //   title  (len+1), author (len+1), misc (len+1), player code, pt3 data.
    // The zxdtsz variables area is NOT in the file; the emulator maps each
    // block to its ZX address independently (see TPoints Adr1/Adr2).
    let strings_len = title.len() + 1 + author.len() + 1 + misc.len() + 1;

    // ── TAYFileHeader (20 bytes at offset 0) ─────────────────────────────────
    let mut out: Vec<u8> = Vec::new();

    // FileID = "ZXAY" (0x5A58_4159 LE → bytes 59 41 58 5A)
    out.extend_from_slice(b"ZXAY");
    // TypeID = "EMUL" (bytes 45 4D 55 4C)
    out.extend_from_slice(b"EMUL");
    // FileVersion, PlayerVersion
    out.push(0u8); // FileVersion
    out.push(0u8); // PlayerVersion
    // PSpecialPlayer (BE signed, 0 = no special player)
    out.extend_from_slice(&be16(0));
    // PAuthor: from field position 12, offset to author string
    //   author string is at: 58 + title.len()+1
    //   PAuthor field is at offset 12
    //   relative offset = (58 + title.len() + 1) - 12
    let p_author = (58usize + title.len() + 1).wrapping_sub(12) as u16;
    out.extend_from_slice(&be16(p_author));
    // PMisc: from field position 14
    //   misc string at: 58 + title.len()+1 + author.len()+1
    //   relative = that - 14
    let misc_pos = 58 + title.len() + 1 + author.len() + 1;
    let p_misc = misc_pos.wrapping_sub(14) as u16;
    out.extend_from_slice(&be16(p_misc));
    // NumOfSongs (0 = 1 song, 0-based max), FirstSong
    out.push(0u8);
    out.push(0u8);
    // PSongsStructure: from offset 18, SongStructure is at offset 20 → relative = 2
    out.extend_from_slice(&be16(2));
    // total header: 20 bytes ✓

    // ── TSongStructure (4 bytes at offset 20) ────────────────────────────────
    // PSongName: from offset 20, title at offset 58 → relative = 38
    let p_song_name = (58usize - 20) as u16;
    out.extend_from_slice(&be16(p_song_name));
    // PSongData: from offset 22, SongData at offset 24 → relative = 2
    out.extend_from_slice(&be16(2));
    // total SongStructure: 4 bytes ✓

    // ── TSongData (14 bytes at offset 24) ────────────────────────────────────
    out.push(0u8); // ChanA
    out.push(1u8); // ChanB
    out.push(2u8); // ChanC
    out.push(3u8); // Noise
    // SongLength (BE) — use 0 to let AY emulators loop indefinitely
    out.extend_from_slice(&be16(0));
    // FadeLength
    out.extend_from_slice(&be16(0));
    // HiReg, LoReg (second module address for TS; 0 for single chip)
    out.push(0u8);
    out.push(0u8);
    // PPoints: from offset 34, TPoints at offset 38 → relative = 4
    out.extend_from_slice(&be16(4));
    // PAddresses: from offset 36, TPoints.Adr1 is at offset 38+6=44 → relative = 8
    out.extend_from_slice(&be16(8));
    // total SongData: 14 bytes ✓

    // ── TPoints (20 bytes at offset 38) ──────────────────────────────────────
    // Player code starts at: 58 + strings_len
    let player_file_pos = 58 + strings_len;

    // Stek = Init = load_addr (big-endian absolute)
    out.extend_from_slice(&be16(opts.load_addr));         // Stek
    out.extend_from_slice(&be16(opts.load_addr));         // Init
    out.extend_from_slice(&be16(opts.load_addr + 5));     // Inter (play entry = START+5)
    // Adr1: load address for player block
    out.extend_from_slice(&be16(opts.load_addr));         // Adr1
    out.extend_from_slice(&be16(zxplsz as u16));          // Len1
    // Offs1 (at file offset 48): relative to 48 → player_file_pos
    let offs1 = (player_file_pos - 48) as u16;
    out.extend_from_slice(&be16(offs1));                  // Offs1
    // Adr2: load address for PT3 data (after player + variables)
    let adr2 = opts.load_addr as usize + zxplsz + zxdtsz;
    out.extend_from_slice(&be16(adr2 as u16));            // Adr2
    out.extend_from_slice(&be16(pt3.len() as u16));       // Len2
    // Offs2 (at file offset 54): relative to 54 → pt3 file position.
    // In the AY file the variables area (zxdtsz bytes) is NOT written to the
    // file — the AY emulator loads each TPoints block at its stated ZX address,
    // so the gap between Adr1+Len1 and Adr2 is already zeroed ZX RAM.
    let pt3_file_pos = player_file_pos + zxplsz;
    let offs2 = (pt3_file_pos - 54) as u16;
    out.extend_from_slice(&be16(offs2));                  // Offs2
    out.extend_from_slice(&be16(0));                      // Zero (terminator)
    // total TPoints: 20 bytes ✓

    // ── String table ─────────────────────────────────────────────────────────
    out.extend_from_slice(title);
    out.push(0);
    out.extend_from_slice(author);
    out.push(0);
    out.extend_from_slice(misc);
    out.push(0);

    // ── Player code ──────────────────────────────────────────────────────────
    out.extend_from_slice(player);
    // NOTE: no zxdtsz zero-fill here — the AY emulator loads each TPoints
    // block at its stated ZX RAM address (Adr1/Adr2).  The gap between
    // Adr1+Len1 and Adr2 (the player variables area) is already zero'd ZX RAM;
    // it must NOT be stored in the file.

    // ── PT3 data ─────────────────────────────────────────────────────────────
    out.extend_from_slice(pt3);
    Ok(out)
}

// ── .scl (Sinclair disc image) ────────────────────────────────────────────────

fn build_scl(
    player: &[u8],
    pt3: &[u8],
    zxplsz: usize,
    zxdtsz: usize,
    opts: &ZxExportOptions,
) -> Result<Vec<u8>> {
    let player_name = if opts.name.is_empty() { "vtplayer" } else { &opts.name };
    let data_start = opts.load_addr as usize + zxplsz + zxdtsz;

    // Player sectors (rounded up to 256-byte boundary)
    let pl_sectors = ((zxplsz + 255) / 256) as u8;
    // Data sectors
    let data_sectors = ((pt3.len() + 255) / 256) as u8;

    // ── SCL header (37 bytes) ─────────────────────────────────────────────────
    // Format: "SINCLAIR" (8) + NBlk (1) + entry1 (17) + entry2 (17) = 43 bytes
    // Each entry: Name[8] + Typ (1) + Start LE u16 + Leng LE u16 + Sect (1) = 14 bytes
    // Wait: looking at Pascal's SCLHdr:
    //   SCL[8], NBlk, Name1[8], Typ1, Start1 (u16), Leng1 (u16), Sect1,
    //   Name2[8], Typ2, Start2 (u16), Leng2 (u16), Sect2  = 37 bytes

    let mut hdr = [0u8; 37];
    hdr[..8].copy_from_slice(b"SINCLAIR");
    hdr[8] = 2; // two directory entries
    // Entry 1: player
    let pl_name = b"vtplayer";
    hdr[9..17].copy_from_slice(pl_name);
    hdr[17] = b'C';
    hdr[18] = opts.load_addr as u8;
    hdr[19] = (opts.load_addr >> 8) as u8;
    hdr[20] = zxplsz as u8;
    hdr[21] = (zxplsz >> 8) as u8;
    hdr[22] = pl_sectors;
    // Entry 2: PT3 data
    let data_name_bytes = player_name.as_bytes();
    let dlen = data_name_bytes.len().min(8);
    hdr[23..23 + dlen].copy_from_slice(&data_name_bytes[..dlen]);
    hdr[23 + dlen..31].fill(b' ');
    hdr[31] = b'C';
    hdr[32] = data_start as u8;
    hdr[33] = (data_start >> 8) as u8;
    hdr[34] = pt3.len() as u8;
    hdr[35] = (pt3.len() >> 8) as u8;
    hdr[36] = data_sectors;

    // ── Running checksum (32-bit sum of all bytes) ────────────────────────────
    let mut checksum: u32 = hdr.iter().map(|&b| b as u32).sum();

    let mut out: Vec<u8> = Vec::new();
    out.extend_from_slice(&hdr);

    // Player code (sector-padded)
    let pl_padded_len = pl_sectors as usize * 256;
    out.extend_from_slice(player);
    out.resize(out.len() + (pl_padded_len - zxplsz), 0);
    for &b in player {
        checksum = checksum.wrapping_add(b as u32);
    }

    // PT3 data (sector-padded)
    let data_padded_len = data_sectors as usize * 256;
    out.extend_from_slice(pt3);
    out.resize(out.len() + (data_padded_len - pt3.len()), 0);
    for &b in pt3 {
        checksum = checksum.wrapping_add(b as u32);
    }

    // Append 32-bit checksum (LE)
    out.extend_from_slice(&checksum.to_le_bytes());
    Ok(out)
}

// ── .tap (ZX Spectrum tape) ───────────────────────────────────────────────────

/// Compute the XOR parity byte used in TAP blocks (flag byte XOR all data bytes).
fn tap_checksum(flag: u8, data: &[u8]) -> u8 {
    let mut k = flag;
    for &b in data {
        k ^= b;
    }
    k
}

/// Write a TAP block: 2-byte length (LE) + flag byte + data + checksum byte.
fn write_tap_block(out: &mut Vec<u8>, flag: u8, data: &[u8]) {
    let block_len = 1 + data.len() + 1; // flag + data + checksum
    out.push(block_len as u8);
    out.push((block_len >> 8) as u8);
    out.push(flag);
    out.extend_from_slice(data);
    out.push(tap_checksum(flag, data));
}

fn build_tap(
    player: &[u8],
    pt3: &[u8],
    zxplsz: usize,
    zxdtsz: usize,
    opts: &ZxExportOptions,
) -> Result<Vec<u8>> {
    let data_start = opts.load_addr as usize + zxplsz + zxdtsz;
    // ── TAP header spec: 19 bytes ──────────────────────────────────────────
    // type(1) + name[10] + length(2) + start(2) + param2(2) = 17 bytes of data
    // wrapped in a header TAP block (flag=0x00).

    let make_hdr_block = |name: &str, start: u16, length: u16| -> Vec<u8> {
        let mut hdr = [0u8; 17];
        hdr[0] = 3; // file type: CODE
        let nb = name.as_bytes();
        let nl = nb.len().min(10);
        hdr[1..1 + nl].copy_from_slice(&nb[..nl]);
        hdr[1 + nl..11].fill(b' ');
        hdr[11] = length as u8;
        hdr[12] = (length >> 8) as u8;
        hdr[13] = start as u8;
        hdr[14] = (start >> 8) as u8;
        hdr[15] = 0x00; // param2 lo (unused for CODE)
        hdr[16] = 0x80; // param2 hi (0x8000 = no autostart)
        hdr.to_vec()
    };

    let player_name = "vtplayer";
    let data_name = if opts.name.is_empty() { "module    " } else { &opts.name };

    let mut out: Vec<u8> = Vec::new();

    // Block 1: header for player
    let pl_hdr = make_hdr_block(player_name, opts.load_addr, zxplsz as u16);
    write_tap_block(&mut out, 0x00, &pl_hdr);

    // Block 2: player data
    write_tap_block(&mut out, 0xFF, player);

    // Block 3: header for PT3 data
    let data_hdr = make_hdr_block(data_name, data_start as u16, pt3.len() as u16);
    write_tap_block(&mut out, 0x00, &data_hdr);

    // Block 4: PT3 data
    write_tap_block(&mut out, 0xFF, pt3);

    Ok(out)
}
