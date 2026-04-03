//! vti-ay: AY-3-8910 / YM2149F chip emulator.
//!
//! Faithful Rust port of `AY.pas` (c) 2000-2009 S.V.Bulba.

pub mod chip;
pub mod config;
pub mod synth;

pub use chip::{ChipType, SoundChip};
pub use config::AyConfig;
pub use synth::Synthesizer;
