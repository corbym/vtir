//! vti-audio: cross-platform audio output using cpal.
//!
//! Replaces the Windows-only `WaveOutAPI.pas` (c) 2000-2009 S.V.Bulba.
//! Drives the `vti-ay` synthesizer from a background thread and feeds the
//! resulting PCM samples to the platform audio device via `cpal`.

pub mod player;

pub use player::{AudioPlayer, PlayerCommand};
