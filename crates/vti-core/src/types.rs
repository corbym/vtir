//! Core data types for the Vortex Tracker II module format.
//!
//! Direct Rust port of the Pascal record definitions in `trfuncs.pas`
//! (c) 2000-2009 S.V.Bulba.

use serde::{Deserialize, Serialize};
use serde_big_array::BigArray;

// ─── Constants ───────────────────────────────────────────────────────────────

pub const MAX_PAT_LEN: usize = 256;
pub const DEF_PAT_LEN: usize = 64;
pub const MAX_PAT_NUM: usize = 84;
pub const MAX_NUM_OF_PATS: usize = MAX_PAT_NUM + 1;
pub const MAX_ORN_LEN: usize = 255;
pub const MAX_SAM_LEN: usize = 64;
pub const MAX_NUMBER_OF_SOUND_CHIPS: usize = 2;
/// Number of AY channels per pattern row.
pub const NUM_CHANNELS: usize = 3;

// ─── Note / note-off sentinels ────────────────────────────────────────────────

/// Silence ("R--" in the pattern grid).
pub const NOTE_SOUND_OFF: i8 = -2;
/// No note in this cell ("---").
pub const NOTE_NONE: i8 = -1;

// ─── Features level ──────────────────────────────────────────────────────────

/// 0 = PT 3.5 and older;  1 = VT II / PT 3.6;  2 = PT 3.7+
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[repr(u8)]
pub enum FeaturesLevel {
    Pt35 = 0,
    Vt2 = 1,
    Pt37 = 2,
}

impl Default for FeaturesLevel {
    fn default() -> Self {
        FeaturesLevel::Vt2
    }
}

// ─── Chip / module file type ──────────────────────────────────────────────────

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum FileType {
    Unknown,
    Stc,
    Asc,
    Asc0,
    Stp,
    Psc,
    Fls,
    Ftc,
    Pt1,
    Pt2,
    Pt3,
    Sqt,
    Gtr,
    Fxm,
    Psm,
}

// ─── AY registers snapshot ───────────────────────────────────────────────────

/// Mirror of the 14 AY-3-8910 hardware registers.
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct AyRegisters {
    pub ton_a: u16,
    pub ton_b: u16,
    pub ton_c: u16,
    pub noise: u8,
    pub mixer: u8,
    pub amplitude_a: u8,
    pub amplitude_b: u8,
    pub amplitude_c: u8,
    pub envelope: u16,
    pub env_type: u8,
}

// ─── Sample tick ─────────────────────────────────────────────────────────────

/// One step in a sample ("instrument") definition.
#[derive(Debug, Clone, Copy, Serialize, Deserialize)]
pub struct SampleTick {
    pub add_to_ton: i16,
    pub ton_accumulation: bool,
    pub amplitude: u8,
    pub amplitude_sliding: bool,
    pub amplitude_slide_up: bool,
    pub envelope_enabled: bool,
    pub envelope_or_noise_accumulation: bool,
    pub add_to_envelope_or_noise: i8,
    /// false = tone channel enabled in sample
    pub mixer_ton: bool,
    /// false = noise channel enabled in sample
    pub mixer_noise: bool,
}

impl Default for SampleTick {
    fn default() -> Self {
        Self {
            add_to_ton: 0,
            ton_accumulation: false,
            amplitude: 0,
            amplitude_sliding: false,
            amplitude_slide_up: false,
            envelope_enabled: false,
            envelope_or_noise_accumulation: false,
            add_to_envelope_or_noise: 0,
            mixer_ton: false,
            mixer_noise: false,
        }
    }
}

// ─── Sample ──────────────────────────────────────────────────────────────────

/// A PT3 "sample" (synthesizer instrument program).
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Sample {
    pub length: u8,
    pub loop_pos: u8,
    pub enabled: bool,
    #[serde(with = "BigArray")]
    pub items: [SampleTick; MAX_SAM_LEN],
}

impl Default for Sample {
    fn default() -> Self {
        Self {
            length: 1,
            loop_pos: 0,
            enabled: true,
            items: [SampleTick::default(); MAX_SAM_LEN],
        }
    }
}

// ─── Ornament ────────────────────────────────────────────────────────────────

/// A PT3 "ornament" (arpeggio/vibrato sequence of semitone offsets).
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Ornament {
    pub length: usize,
    pub loop_pos: usize,
    #[serde(with = "BigArray")]
    pub items: [i8; MAX_ORN_LEN],
}

impl Default for Ornament {
    fn default() -> Self {
        Self {
            length: 1,
            loop_pos: 0,
            items: [0; MAX_ORN_LEN],
        }
    }
}

// ─── Additional command ───────────────────────────────────────────────────────

/// Effect command in a pattern cell (glissando, arpeggio, on/off, etc.).
#[derive(Debug, Clone, Copy, Default, Serialize, Deserialize)]
pub struct AdditionalCommand {
    pub number: u8,
    pub delay: u8,
    pub parameter: u8,
}

// ─── Channel line ────────────────────────────────────────────────────────────

/// One cell in a pattern for a single channel.
#[derive(Debug, Clone, Copy, Serialize, Deserialize)]
pub struct ChannelLine {
    /// 0..95 = note,  NOTE_NONE = no note, NOTE_SOUND_OFF = silence
    pub note: i8,
    /// 0..31 sample index (0 = keep previous)
    pub sample: u8,
    /// 0..15 ornament index
    pub ornament: u8,
    /// 0 = keep previous, 1..15 = set volume
    pub volume: u8,
    /// 0 = keep, 1..14 = envelope type, 15 = off
    pub envelope: u8,
    pub additional_command: AdditionalCommand,
}

impl Default for ChannelLine {
    fn default() -> Self {
        Self {
            note: NOTE_NONE,
            sample: 0,
            ornament: 0,
            volume: 0,
            envelope: 0,
            additional_command: AdditionalCommand::default(),
        }
    }
}

// ─── Pattern row ─────────────────────────────────────────────────────────────

/// One row of a pattern (all three channels + noise/envelope).
#[derive(Debug, Clone, Copy, Default, Serialize, Deserialize)]
pub struct PatternRow {
    pub noise: u8,
    pub envelope: u16,
    pub channel: [ChannelLine; 3],
}

// ─── Pattern ─────────────────────────────────────────────────────────────────

/// A complete pattern (sequence of rows).
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Pattern {
    pub length: usize,
    #[serde(with = "BigArray")]
    pub items: [PatternRow; MAX_PAT_LEN],
}

impl Default for Pattern {
    fn default() -> Self {
        Self {
            length: DEF_PAT_LEN,
            items: [PatternRow::default(); MAX_PAT_LEN],
        }
    }
}

// ─── Position list ───────────────────────────────────────────────────────────

/// The module's position (song order) list.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PositionList {
    /// Pattern indices for each position.
    #[serde(with = "BigArray")]
    pub value: [usize; 256],
    pub length: usize,
    pub loop_pos: usize,
}

impl Default for PositionList {
    fn default() -> Self {
        Self {
            value: [0; 256],
            length: 0,
            loop_pos: 0,
        }
    }
}

// ─── Channel state (IsChans) ─────────────────────────────────────────────────

/// Persistent per-channel playing state (mirrors VTM.IsChans).
#[derive(Debug, Clone, Copy, Default, Serialize, Deserialize)]
pub struct ChannelState {
    pub global_ton: bool,
    pub global_noise: bool,
    pub global_envelope: bool,
    pub envelope_enabled: bool,
    pub ornament: u8,
    pub sample: u8,
    pub volume: u8,
}

// ─── Module ───────────────────────────────────────────────────────────────────

/// A complete Vortex Tracker II module (song).
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Module {
    pub title: String,
    pub author: String,
    /// Tone-table index (0..4).
    pub ton_table: u8,
    /// Initial tick delay (e.g. 3).
    pub initial_delay: u8,
    pub positions: PositionList,
    /// 31 samples (indices 1..=31; index 0 unused).
    pub samples: [Option<Box<Sample>>; 32],
    /// 16 ornaments (indices 0..=15).
    pub ornaments: [Option<Box<Ornament>>; 16],
    /// Up to MAX_PAT_NUM + 1 patterns; index -1 is a special "blank" pattern
    /// stored at index MAX_NUM_OF_PATS.
    pub patterns: Vec<Option<Box<Pattern>>>,
    pub features_level: FeaturesLevel,
    pub vortex_module_header: bool,
    pub is_chans: [ChannelState; 3],
}

impl Default for Module {
    fn default() -> Self {
        let mut m = Self {
            title: String::new(),
            author: String::new(),
            ton_table: 0,
            initial_delay: 3,
            positions: PositionList::default(),
            samples: std::array::from_fn(|_| None),
            ornaments: std::array::from_fn(|_| None),
            // capacity: MAX_NUM_OF_PATS patterns + one "blank" at end
            patterns: vec![None; MAX_NUM_OF_PATS + 1],
            features_level: FeaturesLevel::default(),
            vortex_module_header: true,
            // global_ton / global_noise / global_envelope default to true to
            // match Pascal's VTM initialisation (trfuncs.pas lines 8555–8557).
            // When false they would unconditionally silence the channel, which is
            // the opposite of the "all channels enabled" start-up state.
            is_chans: [ChannelState {
                sample: 1,
                volume: 15,
                global_ton: true,
                global_noise: true,
                global_envelope: true,
                ..Default::default()
            }; 3],
        };
        // Install a default ornament 0 (silence/zero offsets)
        m.ornaments[0] = Some(Box::new(Ornament::default()));
        m
    }
}

impl Module {
    /// Return the "blank" pattern at logical index -1.
    pub fn blank_pattern(&self) -> Option<&Pattern> {
        self.patterns[MAX_NUM_OF_PATS].as_deref()
    }

    pub fn blank_pattern_mut(&mut self) -> &mut Option<Box<Pattern>> {
        &mut self.patterns[MAX_NUM_OF_PATS]
    }

    /// Map a logical pattern index (0..=MAX_PAT_NUM) to a storage index.
    pub fn pat_idx(n: i32) -> usize {
        if n < 0 {
            MAX_NUM_OF_PATS
        } else {
            n as usize
        }
    }

    pub fn pattern(&self, n: i32) -> Option<&Pattern> {
        self.patterns[Self::pat_idx(n)].as_deref()
    }

    pub fn pattern_mut(&mut self, n: i32) -> &mut Option<Box<Pattern>> {
        &mut self.patterns[Self::pat_idx(n)]
    }
}
