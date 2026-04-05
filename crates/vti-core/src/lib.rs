//! vti-core: core data types and tracker playback engine for Vortex Tracker II.
//!
//! This crate contains a faithful Rust port of the original Pascal units
//! `trfuncs.pas` (c) 2000-2009 S.V.Bulba.

pub mod editor;
pub mod formats;
pub mod note_tables;
pub mod playback;
pub mod types;
pub mod util;

pub use types::*;
