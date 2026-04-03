//! VTM text-format serialiser and parser.
//!
//! Ports `VTM2TextFile` and `LoadModuleFromText` from `trfuncs.pas`.
//!
//! # File structure
//!
//! ```text
//! [Module]
//! VortexTrackerII=1
//! Version=3.6
//! Title=…
//! Author=…
//! NoteTable=0
//! ChipFreq=1750000
//! Speed=3
//! PlayOrder=L0,1,2
//!
//! [Ornament1]
//! L0,2,-1
//!
//! [Sample1]
//! TNe +000_ +00_ 0_ L
//!
//! [Pattern0]
//! ....|..|--- .... ....|--- .... ....|--- .... ....
//! ```

use crate::types::*;
use anyhow::{bail, ensure, Context, Result};

// ─── Write helpers ────────────────────────────────────────────────────────────

/// Pascal `Int1DToStr`: 0 → '.', 1–9 → '1'–'9', 10–15 → 'A'–'F'.
fn int1d(i: u8) -> char {
    match i {
        0 => '.',
        1..=9 => char::from_digit(i as u32, 16).unwrap(),
        10..=15 => (b'A' + i - 10) as char,
        _ => '.',
    }
}

/// Pascal `Int2DToStr`: 0 → "..", 1–15 → ".X", 16–255 → "XX".
fn int2d(i: u8) -> String {
    if i == 0 {
        "..".to_string()
    } else if i < 16 {
        format!(".{:X}", i)
    } else {
        format!("{:02X}", i)
    }
}

/// Pascal `Int4DToStr` for u16: 0 → "....", …
fn int4d(i: u16) -> String {
    if i == 0 {
        "....".to_string()
    } else if i < 0x10 {
        format!("...{:X}", i)
    } else if i < 0x100 {
        format!("..{:02X}", i)
    } else if i < 0x1000 {
        format!(".{:03X}", i)
    } else {
        format!("{:04X}", i)
    }
}

/// Pascal `SampToStr`: 0 → '.', 1–15 → hex, 16–31 → 'G'–'V'.
fn samp(i: u8) -> char {
    match i {
        0 => '.',
        1..=9 => (b'0' + i) as char,
        10..=15 => (b'A' + i - 10) as char,
        16..=31 => (b'G' + i - 16) as char,
        _ => '.',
    }
}

/// Pascal `NoteToStr`.
fn note_str(note: i8) -> &'static str {
    const NAMES: [&str; 96] = [
        "C-1", "C#1", "D-1", "D#1", "E-1", "F-1", "F#1", "G-1", "G#1", "A-1", "A#1", "B-1",
        "C-2", "C#2", "D-2", "D#2", "E-2", "F-2", "F#2", "G-2", "G#2", "A-2", "A#2", "B-2",
        "C-3", "C#3", "D-3", "D#3", "E-3", "F-3", "F#3", "G-3", "G#3", "A-3", "A#3", "B-3",
        "C-4", "C#4", "D-4", "D#4", "E-4", "F-4", "F#4", "G-4", "G#4", "A-4", "A#4", "B-4",
        "C-5", "C#5", "D-5", "D#5", "E-5", "F-5", "F#5", "G-5", "G#5", "A-5", "A#5", "B-5",
        "C-6", "C#6", "D-6", "D#6", "E-6", "F-6", "F#6", "G-6", "G#6", "A-6", "A#6", "B-6",
        "C-7", "C#7", "D-7", "D#7", "E-7", "F-7", "F#7", "G-7", "G#7", "A-7", "A#7", "B-7",
        "C-8", "C#8", "D-8", "D#8", "E-8", "F-8", "F#8", "G-8", "G#8", "A-8", "A#8", "B-8",
    ];
    if note == NOTE_SOUND_OFF {
        return "R--";
    }
    if note < 0 || note as usize >= NAMES.len() {
        return "---";
    }
    NAMES[note as usize]
}

/// Serialise one `SampleTick` line (Pascal `GetSampleString`).
fn write_sample_tick(tick: &SampleTick) -> String {
    let t = if tick.mixer_ton { 'T' } else { 't' };
    let n = if tick.mixer_noise { 'N' } else { 'n' };
    let e = if tick.envelope_enabled { 'E' } else { 'e' };

    let ton = if tick.add_to_ton >= 0 {
        format!("+{:03X}", tick.add_to_ton)
    } else {
        format!("-{:03X}", (-tick.add_to_ton) as u16)
    };
    let ton_acc = if tick.ton_accumulation { '^' } else { '_' };

    let env = if tick.add_to_envelope_or_noise >= 0 {
        format!("+{:02X}", tick.add_to_envelope_or_noise)
    } else {
        format!("-{:02X}", (-(tick.add_to_envelope_or_noise as i16)) as u8)
    };
    let env_acc = if tick.envelope_or_noise_accumulation { '^' } else { '_' };

    let amp = format!("{:X}", tick.amplitude & 0x0F);
    let slide = if !tick.amplitude_sliding {
        '_'
    } else if tick.amplitude_slide_up {
        '+'
    } else {
        '-'
    };

    format!("{}{}{} {}{} {}{} {}{}", t, n, e, ton, ton_acc, env, env_acc, amp, slide)
}

/// Serialise one pattern row (Pascal `GetPatternLineString` minus the "XX|" prefix,
/// i.e. exactly what `SavePattern` writes).
fn write_pattern_row(row: &PatternRow) -> String {
    let mut s = String::with_capacity(49);
    s.push_str(&int4d(row.envelope));
    s.push('|');
    s.push_str(&int2d(row.noise));

    for ch in &row.channel {
        s.push('|');
        s.push_str(note_str(ch.note));
        s.push(' ');
        s.push(samp(ch.sample));
        s.push(int1d(ch.envelope));
        s.push(int1d(ch.ornament));
        s.push(int1d(ch.volume));
        s.push(' ');
        s.push(int1d(ch.additional_command.number));
        s.push(int1d(ch.additional_command.delay));
        s.push_str(&int2d(ch.additional_command.parameter));
    }
    s
}

// ─── Public write entry point ─────────────────────────────────────────────────

/// Serialise a [`Module`] to a VTM text string (Pascal `VTM2TextFile`).
///
/// The returned string uses `\n` line endings; callers may replace them with
/// `\r\n` if required.
pub fn write(module: &Module) -> String {
    let mut out = String::new();

    out.push_str("[Module]\n");
    out.push_str(if module.vortex_module_header { "VortexTrackerII=1\n" } else { "VortexTrackerII=0\n" });
    let ver = match module.features_level {
        FeaturesLevel::Pt35 => "3.5",
        FeaturesLevel::Vt2 => "3.6",
        FeaturesLevel::Pt37 => "3.7",
    };
    out.push_str(&format!("Version={}\n", ver));
    out.push_str(&format!("Title={}\n", module.title));
    out.push_str(&format!("Author={}\n", module.author));
    out.push_str(&format!("NoteTable={}\n", module.ton_table));
    out.push_str("ChipFreq=1750000\n");
    out.push_str(&format!("Speed={}\n", module.initial_delay));

    // Position / play order
    out.push_str("PlayOrder=");
    for i in 0..module.positions.length {
        if i == module.positions.loop_pos {
            out.push('L');
        }
        out.push_str(&module.positions.value[i].to_string());
        if i + 1 < module.positions.length {
            out.push(',');
        }
    }
    out.push('\n');
    out.push('\n');

    // Ornaments 1–15
    for n in 1..=15usize {
        out.push_str(&format!("[Ornament{}]\n", n));
        if let Some(orn) = &module.ornaments[n] {
            let l = orn.length;
            for i in 0..l {
                if i == orn.loop_pos {
                    out.push('L');
                }
                out.push_str(&orn.items[i].to_string());
                if i + 1 < l {
                    out.push(',');
                }
            }
            out.push('\n');
        } else {
            out.push_str("L0\n");
        }
        out.push('\n');
    }

    // Samples 1–31
    for n in 1..=31usize {
        out.push_str(&format!("[Sample{}]\n", n));
        if let Some(sam) = &module.samples[n] {
            let l = sam.length as usize;
            for i in 0..l {
                out.push_str(&write_sample_tick(&sam.items[i]));
                if i == sam.loop_pos as usize {
                    out.push_str(" L");
                }
                out.push('\n');
            }
        } else {
            out.push_str("tne +000_ +00_ 0_ L\n");
        }
        out.push('\n');
    }

    // Patterns (only those that exist)
    for n in 0..MAX_PAT_NUM {
        if let Some(pat) = &module.patterns[n] {
            out.push_str(&format!("[Pattern{}]\n", n));
            for i in 0..pat.length {
                out.push_str(&write_pattern_row(&pat.items[i]));
                out.push('\n');
            }
            out.push('\n');
        }
    }

    out
}

// ─── Parse helpers ────────────────────────────────────────────────────────────

/// Pascal `SGetNumber`: parse one or two custom-base characters into a `u16`.
/// Characters: '.' → 0, '0'–'9', 'A'–'V' (= 10–31), '.' treated as '0'.
fn sget_number(s: &str, max: u16) -> Option<u16> {
    let mut res: u32 = 0;
    for ch in s.chars() {
        let ch = if ch == '.' { '0' } else { ch.to_ascii_uppercase() };
        let digit = match ch {
            '0'..='9' => ch as u32 - '0' as u32,
            'A'..='V' => ch as u32 - 'A' as u32 + 10,
            _ => return None,
        };
        res = res * 16 + digit;
    }
    if res > max as u32 {
        return None;
    }
    Some(res as u16)
}

/// Parse a note string ("C-4", "---", "R--") into a note index.
fn parse_note(s: &str) -> Option<i8> {
    let s = s.to_uppercase();
    if s == "R--" {
        return Some(NOTE_SOUND_OFF);
    }
    if s == "---" {
        return Some(NOTE_NONE);
    }
    if s.len() != 3 {
        return None;
    }
    let bytes = s.as_bytes();
    let d = if bytes[1] == b'#' { 1i8 } else if bytes[1] == b'-' { 0 } else { return None };
    let octave = (bytes[2] as i8) - b'1' as i8;
    if !(0..=7).contains(&octave) {
        return None;
    }
    let base = match bytes[0] {
        b'C' => 0i8,
        b'D' => 2,
        b'E' => 4,
        b'F' => 5,
        b'G' => 7,
        b'A' => 9,
        b'B' => 11,
        _ => return None,
    };
    let note = base + d + octave * 12;
    if note > 95 {
        return None;
    }
    Some(note)
}

/// Parse one VTM sample-tick text line (Pascal `RecognizeSampleString`).
fn parse_sample_tick(s: &str) -> Result<SampleTick> {
    let s = s.trim();
    let mut tick = SampleTick::default();
    let bytes = s.as_bytes();
    let len = bytes.len();
    let mut i = 0usize;

    // Find 'T' or 't'
    while i < len && bytes[i] != b'T' && bytes[i] != b't' {
        i += 1;
    }
    ensure!(i < len, "missing T/t");
    tick.mixer_ton = bytes[i] == b'T';
    i += 1;

    // Find 'N' or 'n'
    while i < len && bytes[i] != b'N' && bytes[i] != b'n' {
        i += 1;
    }
    ensure!(i < len, "missing N/n");
    tick.mixer_noise = bytes[i] == b'N';
    i += 1;

    // Find 'E' or 'e'
    while i < len && bytes[i] != b'E' && bytes[i] != b'e' {
        i += 1;
    }
    ensure!(i < len, "missing E/e");
    tick.envelope_enabled = bytes[i] == b'E';
    i += 1;

    // add_to_ton: sign + hex digits
    while i < len && !matches!(bytes[i], b'+' | b'-' | b'0'..=b'9' | b'A'..=b'F' | b'a'..=b'f') {
        i += 1;
    }
    ensure!(i < len, "missing add_to_ton");
    let sign_ton = if bytes[i] == b'-' { -1i16 } else { 1 };
    if bytes[i] == b'+' || bytes[i] == b'-' {
        i += 1;
    }
    let start = i;
    while i < len && matches!(bytes[i], b'0'..=b'9' | b'A'..=b'F' | b'a'..=b'f') {
        i += 1;
    }
    let hex = &s[start..i];
    let val = i16::from_str_radix(hex, 16).context("add_to_ton")?;
    tick.add_to_ton = sign_ton * val;

    // ton_accumulation: '^' or '_'
    while i < len && bytes[i] != b'^' && bytes[i] != b'_' {
        i += 1;
    }
    ensure!(i < len, "missing ton_acc");
    tick.ton_accumulation = bytes[i] == b'^';
    i += 1;

    // add_to_envelope_or_noise: sign + hex digits
    while i < len && !matches!(bytes[i], b'+' | b'-' | b'0'..=b'9' | b'A'..=b'F' | b'a'..=b'f') {
        i += 1;
    }
    ensure!(i < len, "missing add_to_env");
    let sign_env = if bytes[i] == b'-' { -1i8 } else { 1 };
    if bytes[i] == b'+' || bytes[i] == b'-' {
        i += 1;
    }
    let start = i;
    while i < len && matches!(bytes[i], b'0'..=b'9' | b'A'..=b'F' | b'a'..=b'f') {
        i += 1;
    }
    let hex = &s[start..i];
    let val = u8::from_str_radix(hex, 16).context("add_to_env")?;
    // mask to 5 bits and sign-extend (Pascal: nm and $1F, sign-extend from bit 4)
    let masked = val & 0x1F;
    let extended: i8 = if masked & 0x10 != 0 {
        (masked | 0xE0) as i8 // sign extend: set upper 3 bits
    } else {
        masked as i8
    };
    tick.add_to_envelope_or_noise = sign_env * extended;

    // envelope_or_noise_accumulation: '^' or '_'
    while i < len && bytes[i] != b'^' && bytes[i] != b'_' {
        i += 1;
    }
    ensure!(i < len, "missing env_acc");
    tick.envelope_or_noise_accumulation = bytes[i] == b'^';
    i += 1;

    // amplitude: hex digit
    while i < len && !matches!(bytes[i], b'0'..=b'9' | b'A'..=b'F' | b'a'..=b'f') {
        i += 1;
    }
    ensure!(i < len, "missing amplitude");
    let hex = char::from(bytes[i]).to_digit(16).context("amplitude hex")? as u8;
    tick.amplitude = hex & 0x0F;
    i += 1;

    // amplitude sliding: '+', '-', or '_'
    while i < len && !matches!(bytes[i], b'+' | b'-' | b'_') {
        i += 1;
    }
    if i < len {
        match bytes[i] {
            b'+' => { tick.amplitude_sliding = true; tick.amplitude_slide_up = true; }
            b'-' => { tick.amplitude_sliding = true; tick.amplitude_slide_up = false; }
            _ => { tick.amplitude_sliding = false; }
        }
    }

    Ok(tick)
}

/// Parse one ornament text line (Pascal `RecognizeOrnamentString`).
fn parse_ornament_line(s: &str) -> Result<Ornament> {
    let mut orn = Ornament::default();
    let mut loop_pos = 0usize;
    let mut length = 0usize;
    let mut chars = s.chars().peekable();

    loop {
        // Skip non-significant characters
        while let Some(&c) = chars.peek() {
            if c.is_ascii_digit() || c == '-' || c == '+' || c == 'L' || c == 'l' {
                break;
            }
            chars.next();
        }
        let Some(&c) = chars.peek() else { break };

        if c == 'L' || c == 'l' {
            chars.next();
            loop_pos = length;
            continue;
        }

        // Read a signed integer
        let mut neg = false;
        if c == '+' { chars.next(); }
        else if c == '-' { neg = true; chars.next(); }

        let mut digits = String::new();
        while let Some(&d) = chars.peek() {
            if d.is_ascii_digit() {
                digits.push(d);
                chars.next();
            } else {
                break;
            }
        }
        if digits.is_empty() { break; }
        let val: i8 = digits.parse::<i8>().unwrap_or(0);
        ensure!(length < MAX_ORN_LEN, "ornament too long");
        orn.items[length] = if neg { -val } else { val };
        length += 1;
        if length >= MAX_ORN_LEN { break; }
    }

    ensure!(length > 0, "empty ornament");
    orn.length = length;
    orn.loop_pos = loop_pos;
    Ok(orn)
}

/// Parse one VTM pattern row string (49 chars, Pascal `RecognizePatternString`).
fn parse_pattern_row(s: &str) -> Result<PatternRow> {
    let mut row = PatternRow::default();

    // The line must be exactly 48 or 49 chars long.
    // After SavePattern strips the "XX|" prefix, the line has 49 chars.
    ensure!(s.len() >= 48, "pattern row too short ({}): {:?}", s.len(), s);

    // Columns are 1-indexed in Pascal; here we use 0-indexed.
    // ENV: chars 0-3 (4 chars)
    // '|': char 4
    // NOISE: chars 5-6 (2 chars)
    // '|': char 7
    // Per channel (0–2): starts at 8 + channel*14
    //   note:  +0..+2  (3 chars)
    //   ' ':   +3
    //   samp:  +4      (1 char)
    //   env:   +5      (1 char)
    //   orn:   +6      (1 char)
    //   vol:   +7      (1 char)
    //   ' ':   +8
    //   cmd_n: +9      (1 char)
    //   cmd_d: +10     (1 char)
    //   cmd_p: +11..+12 (2 chars)
    //   '|' or end: +13

    // --- Envelope (Pascal positions 1–4, index 0–3) ---
    let env_str = &s[0..4];
    row.envelope = sget_number(env_str, 65535).unwrap_or(0);

    // --- Noise (Pascal positions 6–7, index 5–6) ---
    if s.len() > 6 && &s[4..5] == "|" {
        let noise_str = &s[5..7];
        row.noise = sget_number(noise_str, 31).unwrap_or(0) as u8;
    }

    // --- Three channels ---
    for ch_idx in 0..3usize {
        let base = 8 + ch_idx * 14; // 0-indexed
        if base + 13 > s.len() {
            break;
        }

        // Verify the leading '|'
        if &s[base - 1..base] != "|" {
            continue;
        }

        let ch = &mut row.channel[ch_idx];

        // note
        let note_s = &s[base..base + 3];
        ch.note = parse_note(note_s).unwrap_or(NOTE_NONE);

        // sample (base+4)
        if base + 4 < s.len() {
            ch.sample = sget_number(&s[base + 4..base + 5], 31).unwrap_or(0) as u8;
        }
        // envelope type (base+5)
        if base + 5 < s.len() {
            ch.envelope = sget_number(&s[base + 5..base + 6], 15).unwrap_or(0) as u8;
        }
        // ornament (base+6)
        if base + 6 < s.len() {
            ch.ornament = sget_number(&s[base + 6..base + 7], 15).unwrap_or(0) as u8;
        }
        // volume (base+7)
        if base + 7 < s.len() {
            ch.volume = sget_number(&s[base + 7..base + 8], 15).unwrap_or(0) as u8;
        }
        // cmd_number (base+9)
        if base + 9 < s.len() {
            ch.additional_command.number = sget_number(&s[base + 9..base + 10], 15).unwrap_or(0) as u8;
        }
        // cmd_delay (base+10)
        if base + 10 < s.len() {
            ch.additional_command.delay = sget_number(&s[base + 10..base + 11], 15).unwrap_or(0) as u8;
        }
        // cmd_param (base+11..base+12)
        if base + 13 <= s.len() {
            ch.additional_command.parameter = sget_number(&s[base + 11..base + 13], 255).unwrap_or(0) as u8;
        }
    }

    Ok(row)
}

// ─── Public parse entry point ─────────────────────────────────────────────────

/// Parse a VTM text string into a [`Module`] (Pascal `LoadModuleFromText`).
pub fn parse(text: &str) -> Result<Module> {
    let mut module = Module::default();

    let mut lines = text.lines().peekable();

    // Expect "[Module]" header
    loop {
        match lines.next() {
            None => bail!("VTM: missing [Module] section"),
            Some(l) if l.trim().eq_ignore_ascii_case("[Module]") => break,
            Some(_) => {}
        }
    }

    // Parse [Module] key=value pairs until we hit a '[' section
    let mut current_section = String::new();
    let mut section_lines: Vec<String> = Vec::new();

    // Read module fields
    loop {
        let line = match lines.next() {
            None => break,
            Some(l) => l.trim().to_string(),
        };
        if line.starts_with('[') {
            current_section = line;
            break;
        }
        if line.is_empty() {
            continue;
        }
        let eq = line.find('=').unwrap_or(0);
        if eq == 0 {
            continue;
        }
        let key = line[..eq].trim().to_uppercase();
        let val = line[eq + 1..].trim();
        match key.as_str() {
            "VORTEXTRACKERII" => module.vortex_module_header = val != "0",
            "VERSION" => {
                module.features_level = match val {
                    "3.5" => FeaturesLevel::Pt35,
                    "3.7" => FeaturesLevel::Pt37,
                    _ => FeaturesLevel::Vt2,
                };
            }
            "TITLE" => module.title = val.to_string(),
            "AUTHOR" => module.author = val.to_string(),
            "NOTETABLE" => {
                module.ton_table = val.parse::<u8>().unwrap_or(0).min(4);
            }
            "SPEED" => {
                let d = val.parse::<u8>().unwrap_or(3);
                module.initial_delay = d;
            }
            "PLAYORDER" => {
                parse_play_order(val, &mut module)?;
            }
            _ => {}
        }
    }

    // Parse remaining sections
    loop {
        if current_section.is_empty() {
            break;
        }
        section_lines.clear();
        loop {
            match lines.peek() {
                None => break,
                Some(l) if l.trim().starts_with('[') => break,
                Some(_) => {
                    section_lines.push(lines.next().unwrap().to_string());
                }
            }
        }

        let sec = current_section.trim().to_uppercase();
        if sec.starts_with("[ORNAMENT") {
            let idx_str = sec
                .trim_start_matches('[')
                .trim_start_matches("ORNAMENT")
                .trim_end_matches(']');
            if let Ok(idx) = idx_str.trim().parse::<usize>() {
                if (1..=15).contains(&idx) {
                    // The ornament data is all on one line (non-empty lines)
                    let data: Vec<&str> = section_lines.iter()
                        .map(|l| l.trim())
                        .filter(|l| !l.is_empty())
                        .collect();
                    if !data.is_empty() {
                        match parse_ornament_line(data[0]) {
                            Ok(orn) => module.ornaments[idx] = Some(Box::new(orn)),
                            Err(_) => {} // keep default
                        }
                    }
                }
            }
        } else if sec.starts_with("[SAMPLE") {
            let idx_str = sec
                .trim_start_matches('[')
                .trim_start_matches("SAMPLE")
                .trim_end_matches(']');
            if let Ok(idx) = idx_str.trim().parse::<usize>() {
                if (1..=31).contains(&idx) {
                    match parse_sample_section(&section_lines) {
                        Ok(sam) => module.samples[idx] = Some(Box::new(sam)),
                        Err(_) => {} // keep None
                    }
                }
            }
        } else if sec.starts_with("[PATTERN") {
            let idx_str = sec
                .trim_start_matches('[')
                .trim_start_matches("PATTERN")
                .trim_end_matches(']');
            if let Ok(idx) = idx_str.trim().parse::<usize>() {
                if idx < MAX_NUM_OF_PATS {
                    match parse_pattern_section(&section_lines) {
                        Ok(pat) => module.patterns[idx] = Some(Box::new(pat)),
                        Err(_) => {} // keep None
                    }
                }
            }
        }

        current_section = match lines.next() {
            Some(l) => l.trim().to_string(),
            None => break,
        };
        // Skip blank lines between sections
        while current_section.is_empty() {
            current_section = match lines.next() {
                Some(l) => l.trim().to_string(),
                None => break,
            };
        }
    }

    Ok(module)
}

fn parse_play_order(val: &str, module: &mut Module) -> Result<()> {
    if val.is_empty() {
        return Ok(());
    }
    module.positions.length = 0;
    module.positions.loop_pos = 0;
    for part in val.split(',') {
        let part = part.trim();
        if part.is_empty() {
            continue;
        }
        let (lp, num_str) = if part.starts_with('L') || part.starts_with('l') {
            (true, &part[1..])
        } else {
            (false, part)
        };
        let n: usize = num_str.trim().parse().context("invalid PlayOrder entry")?;
        ensure!(n <= MAX_PAT_NUM, "PlayOrder index out of range: {}", n);
        ensure!(module.positions.length < 256, "too many positions");
        if lp {
            module.positions.loop_pos = module.positions.length;
        }
        module.positions.value[module.positions.length] = n;
        module.positions.length += 1;
    }
    Ok(())
}

fn parse_sample_section(lines: &[String]) -> Result<Sample> {
    let mut sam = Sample::default();
    let mut length = 0usize;
    let mut loop_pos = 0usize;

    for line in lines {
        let l = line.trim();
        if l.is_empty() || l.starts_with('[') {
            break;
        }
        ensure!(length < MAX_SAM_LEN, "sample too long");
        let tick = parse_sample_tick(l)?;
        sam.items[length] = tick;
        // Check for loop marker: 'L' somewhere after the tick data
        if l.to_uppercase().contains(" L") || l.ends_with('L') || l.ends_with('l') {
            loop_pos = length;
        }
        length += 1;
    }
    ensure!(length > 0, "empty sample");
    sam.length = length as u8;
    sam.loop_pos = loop_pos as u8;
    Ok(sam)
}

fn parse_pattern_section(lines: &[String]) -> Result<Pattern> {
    let mut pat = Pattern::default();
    let mut length = 0usize;

    for line in lines {
        let l = line.trim();
        if l.is_empty() || l.starts_with('[') {
            break;
        }
        ensure!(length < MAX_PAT_LEN, "pattern too long");
        pat.items[length] = parse_pattern_row(l)?;
        length += 1;
    }
    ensure!(length > 0, "empty pattern");
    pat.length = length;
    Ok(pat)
}

// ─── Tests ────────────────────────────────────────────────────────────────────

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn int1d_values() {
        assert_eq!(int1d(0), '.');
        assert_eq!(int1d(9), '9');
        assert_eq!(int1d(10), 'A');
        assert_eq!(int1d(15), 'F');
    }

    #[test]
    fn int2d_values() {
        assert_eq!(int2d(0), "..");
        assert_eq!(int2d(1), ".1");
        assert_eq!(int2d(15), ".F");
        assert_eq!(int2d(16), "10");
        assert_eq!(int2d(31), "1F");
    }

    #[test]
    fn int4d_values() {
        assert_eq!(int4d(0), "....");
        assert_eq!(int4d(1), "...1");
        assert_eq!(int4d(255), "..FF");
        assert_eq!(int4d(0xFFFF), "FFFF");
    }

    #[test]
    fn samp_values() {
        assert_eq!(samp(0), '.');
        assert_eq!(samp(9), '9');
        assert_eq!(samp(10), 'A');
        assert_eq!(samp(15), 'F');
        assert_eq!(samp(16), 'G');
        assert_eq!(samp(31), 'V');
    }

    #[test]
    fn note_str_values() {
        assert_eq!(note_str(NOTE_NONE), "---");
        assert_eq!(note_str(NOTE_SOUND_OFF), "R--");
        assert_eq!(note_str(0), "C-1");
        assert_eq!(note_str(36), "C-4");
        assert_eq!(note_str(95), "B-8");
    }

    #[test]
    fn sample_tick_round_trip() {
        let tick = SampleTick {
            mixer_ton: true,
            mixer_noise: false,
            envelope_enabled: false,
            add_to_ton: 5,
            ton_accumulation: false,
            add_to_envelope_or_noise: -3,
            envelope_or_noise_accumulation: true,
            amplitude: 12,
            amplitude_sliding: true,
            amplitude_slide_up: true,
        };
        let s = write_sample_tick(&tick);
        let parsed = parse_sample_tick(&s).expect("parse tick");
        assert_eq!(parsed.mixer_ton, tick.mixer_ton);
        assert_eq!(parsed.mixer_noise, tick.mixer_noise);
        assert_eq!(parsed.add_to_ton, tick.add_to_ton);
        assert_eq!(parsed.amplitude, tick.amplitude);
    }

    #[test]
    fn ornament_round_trip() {
        let s = "L0,2,-1,3";
        let orn = parse_ornament_line(s).expect("parse ornament");
        assert_eq!(orn.length, 4);
        assert_eq!(orn.loop_pos, 0);
        assert_eq!(orn.items[0], 0);
        assert_eq!(orn.items[1], 2);
        assert_eq!(orn.items[2], -1);
        assert_eq!(orn.items[3], 3);
    }

    #[test]
    fn pattern_row_round_trip() {
        let row = PatternRow {
            envelope: 0x1234,
            noise: 5,
            channel: [
                ChannelLine { note: 36, sample: 1, ornament: 2, volume: 15, envelope: 0, additional_command: AdditionalCommand::default() },
                ChannelLine { note: NOTE_NONE, sample: 0, ornament: 0, volume: 0, envelope: 0, additional_command: AdditionalCommand::default() },
                ChannelLine { note: NOTE_SOUND_OFF, sample: 3, ornament: 0, volume: 0, envelope: 0, additional_command: AdditionalCommand { number: 1, delay: 2, parameter: 15 } },
            ],
        };
        let s = write_pattern_row(&row);
        assert_eq!(s.len(), 49, "row string is exactly 49 chars: {:?}", s);
        let parsed = parse_pattern_row(&s).expect("parse row");
        assert_eq!(parsed.envelope, row.envelope);
        assert_eq!(parsed.noise, row.noise);
        assert_eq!(parsed.channel[0].note, row.channel[0].note);
        assert_eq!(parsed.channel[0].sample, row.channel[0].sample);
        assert_eq!(parsed.channel[0].volume, row.channel[0].volume);
        assert_eq!(parsed.channel[2].note, row.channel[2].note);
        assert_eq!(parsed.channel[2].additional_command.number, 1);
        assert_eq!(parsed.channel[2].additional_command.delay, 2);
        assert_eq!(parsed.channel[2].additional_command.parameter, 15);
    }
}
