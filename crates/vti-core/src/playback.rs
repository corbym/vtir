//! Tracker playback engine.
//!
//! Rust port of `Pattern_PlayCurrentLine`, `Module_PlayCurrentLine`,
//! `Pattern_PlayOnlyCurrentLine` and `GetRegisters` from `trfuncs.pas`
//! (c) 2000-2009 S.V.Bulba.
//!
//! The engine advances playback one interrupt tick at a time.  Each call to
//! [`Engine::module_play_current_line`] corresponds to one 50 Hz interrupt
//! period on the original ZX Spectrum hardware.

use crate::note_tables::{get_note_freq, PT3_VOL};
use crate::types::*;

/// Per-channel dynamic playback state.
#[derive(Debug, Clone, Default)]
pub struct ChanParams {
    pub sample_position: u8,
    pub ornament_position: u8,
    pub sound_enabled: bool,
    pub slide_to_note: u8,
    pub note: u8,
    pub ton_slide_delay: i8,
    pub ton_slide_count: i8,
    pub ton_slide_step: i16,
    pub ton_slide_delta: i16,
    pub ton_slide_type: i32,
    pub current_ton_sliding: i16,
    pub on_off_delay: i8,
    pub off_on_delay: i8,
    pub current_on_off: i8,
    pub ton: u16,
    pub ton_accumulator: u16,
    pub amplitude: u8,
    pub current_amplitude_sliding: i8,
    pub current_envelope_sliding: i8,
    pub current_noise_sliding: i8,
}

/// Per-chip playback variables (PlVars in Pascal).
#[derive(Debug, Clone, Default)]
pub struct PlayVars {
    pub current_position: usize,
    pub current_pattern: i32,
    pub current_line: usize,
    pub env_base: i16,
    pub params_of_chan: [ChanParams; 3],
    pub delay: i8,
    pub delay_counter: i8,
    pub cur_env_slide: i16,
    pub cur_env_delay: i8,
    pub env_delay: i8,
    pub env_slide_add: i16,
    pub add_to_env: i8,
    pub add_to_noise: u8,
    pub pt3_noise: u8,
    pub int_cnt: i32,
}

/// Return value of `pattern_play_current_line`.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum PlayResult {
    /// AY registers were updated (normal tick).
    Updated,
    /// Pattern has ended; advance to next position.
    PatternEnd,
    /// Module has looped back (reached loop position).
    ModuleLoop,
}

/// Playback engine for a single chip slot.
pub struct Engine<'a> {
    pub module: &'a mut Module,
    pub vars: &'a mut PlayVars,
}

impl<'a> Engine<'a> {
    /// Corresponds to `Pattern_PlayOnlyCurrentLine` in Pascal.
    ///
    /// Renders the current pattern row into `ay_regs` without advancing.
    /// Returns computed amplitude/tone/mixer values in place.
    pub fn pattern_play_only_current_line(
        &mut self,
        ay_regs: &mut AyRegisters,
    ) {
        let pat_idx = Module::pat_idx(self.vars.current_pattern);
        if self.module.patterns[pat_idx].is_none() {
            return;
        }

        let mut temp_mixer: u8 = 0;
        self.vars.add_to_env = 0;

        for ch in 0..3 {
            self.get_channel_registers(ch, &mut temp_mixer, ay_regs);
        }

        ay_regs.mixer = temp_mixer;
        ay_regs.ton_a = self.vars.params_of_chan[0].ton;
        ay_regs.ton_b = self.vars.params_of_chan[1].ton;
        ay_regs.ton_c = self.vars.params_of_chan[2].ton;
        ay_regs.amplitude_a = self.vars.params_of_chan[0].amplitude;
        ay_regs.amplitude_b = self.vars.params_of_chan[1].amplitude;
        ay_regs.amplitude_c = self.vars.params_of_chan[2].amplitude;
        ay_regs.noise = (self.vars.pt3_noise.wrapping_add(self.vars.add_to_noise)) & 31;
        ay_regs.envelope = (self.vars.add_to_env as i16 + self.vars.cur_env_slide + self.vars.env_base) as u16;
    }

    /// Corresponds to `Pattern_PlayCurrentLine` in Pascal.
    ///
    /// Interprets the current pattern row (effects, notes, …), advances the
    /// line pointer and calls `pattern_play_only_current_line`.
    pub fn pattern_play_current_line(
        &mut self,
        ay_regs: &mut AyRegisters,
    ) -> PlayResult {
        if self.vars.current_pattern == -1 {
            let pat_idx = Module::pat_idx(-1);
            if let Some(pat) = &self.module.patterns[pat_idx] {
                self.vars.add_to_noise = pat.items[self.vars.current_line].noise;
            }
            self.pattern_interpreter(0, ay_regs);
            self.pattern_play_only_current_line(ay_regs);
            return PlayResult::Updated;
        }

        self.vars.delay_counter -= 1;
        if self.vars.delay_counter > 0 {
            self.pattern_play_only_current_line(ay_regs);
            return PlayResult::Updated;
        }

        let pat_idx = Module::pat_idx(self.vars.current_pattern);
        let pat_len = self.module.patterns[pat_idx]
            .as_ref()
            .map(|p| p.length)
            .unwrap_or(0);

        if pat_len <= self.vars.current_line {
            self.vars.delay_counter = 1;
            self.pattern_play_only_current_line(ay_regs);
            return PlayResult::PatternEnd;
        }

        // Read noise/envelope from the pattern row
        if let Some(pat) = &self.module.patterns[pat_idx] {
            self.vars.add_to_noise = pat.items[self.vars.current_line].noise;
        }

        for ch in 0..3 {
            self.pattern_interpreter(ch, ay_regs);
        }

        self.vars.current_line += 1;
        self.vars.delay_counter = self.vars.delay;

        self.pattern_play_only_current_line(ay_regs);
        PlayResult::Updated
    }

    /// Corresponds to `Module_PlayCurrentLine` in Pascal.
    pub fn module_play_current_line(
        &mut self,
        ay_regs: &mut AyRegisters,
    ) -> PlayResult {
        if self.module.positions.length == 0 {
            return PlayResult::ModuleLoop;
        }

        let result = self.pattern_play_current_line(ay_regs);
        if result == PlayResult::PatternEnd {
            self.vars.current_position += 1;
            if self.vars.current_position >= self.module.positions.length {
                self.vars.current_position = self.module.positions.loop_pos;
                self.vars.current_pattern = self.module.positions.value[self.vars.current_position] as i32;
                self.vars.current_line = 0;
                self.pattern_play_current_line(ay_regs);
                return PlayResult::ModuleLoop;
            }
            self.vars.current_pattern = self.module.positions.value[self.vars.current_position] as i32;
            self.vars.current_line = 0;
            self.pattern_play_current_line(ay_regs);
        }
        PlayResult::Updated
    }

    // ─── Internal helpers ─────────────────────────────────────────────────

    fn get_channel_registers(&mut self, ch: usize, temp_mixer: &mut u8, _ay_regs: &mut AyRegisters) {
        let pat_idx = Module::pat_idx(self.vars.current_pattern);
        if self.module.patterns[pat_idx].is_none() {
            return;
        }

        let is_chans = self.module.is_chans[ch];
        let params = &mut self.vars.params_of_chan[ch];

        if !params.sound_enabled {
            params.amplitude = 0;
            // Channel is silent: no mixer bits needed.  The direct bit-placement
            // approach (used in the sound_enabled path) does not require any shift
            // or rotation here; simply setting amplitude=0 is sufficient because
            // level_al[0] == 0, so the channel contributes nothing to the output.
            // The previous code performed a right-rotation which was incorrect and
            // produced a corrupted mixer byte when any prior channel had set bits.
            return;
        }

        let sample_idx = is_chans.sample as usize;
        let ornament_idx = is_chans.ornament as usize;

        // Compute tone from sample
        if let Some(Some(sample)) = self.module.samples.get(sample_idx) {
            let sp = params.sample_position as usize;
            if sp < sample.length as usize {
                let tick = &sample.items[sp];
                params.ton = (params.ton_accumulator as i32 + tick.add_to_ton as i32) as u16;
                if tick.ton_accumulation {
                    params.ton_accumulator = params.ton;
                }
            }
        }

        // Apply ornament
        let ornament_offset: i8 = if let Some(Some(orn)) = self.module.ornaments.get(ornament_idx) {
            let op = params.ornament_position as usize;
            if op < orn.length { orn.items[op] } else { 0 }
        } else {
            0
        };

        let raw_note = (params.note as i16 + ornament_offset as i16).clamp(0, 95) as u8;
        let note_freq = get_note_freq(self.module.ton_table, raw_note);

        let ton_val = (params.ton as i32 + params.current_ton_sliding as i32 + note_freq as i32) & 0xFFF;
        params.ton = ton_val as u16;

        // Glissando update
        if params.ton_slide_count > 0 {
            params.ton_slide_count -= 1;
            if params.ton_slide_count == 0 {
                params.current_ton_sliding += params.ton_slide_step;
                params.ton_slide_count = params.ton_slide_delay;
                if params.ton_slide_type == 1 {
                    let step = params.ton_slide_step;
                    let delta = params.ton_slide_delta;
                    let cur = params.current_ton_sliding;
                    if (step < 0 && cur <= delta) || (step >= 0 && cur >= delta) {
                        params.note = params.slide_to_note;
                        params.ton_slide_count = 0;
                        params.current_ton_sliding = 0;
                    }
                }
            }
        }

        // Amplitude from sample
        if let Some(Some(sample)) = self.module.samples.get(sample_idx) {
            let sp = params.sample_position as usize;
            if sp < sample.length as usize {
                let tick = &sample.items[sp];
                params.amplitude = tick.amplitude;

                if tick.amplitude_sliding {
                    if tick.amplitude_slide_up {
                        if params.current_amplitude_sliding < 15 {
                            params.current_amplitude_sliding += 1;
                        }
                    } else if params.current_amplitude_sliding > -15 {
                        params.current_amplitude_sliding -= 1;
                    }
                }

                let amp = (params.amplitude as i16 + params.current_amplitude_sliding as i16)
                    .clamp(0, 15) as usize;
                let vol = is_chans.volume as usize;
                params.amplitude = PT3_VOL[vol][amp];

                if tick.envelope_enabled && is_chans.envelope_enabled {
                    params.amplitude |= 0x10;
                }

                // Envelope / noise accumulation
                if !tick.mixer_noise {
                    let env_add = params.current_envelope_sliding + tick.add_to_envelope_or_noise as i8;
                    if tick.envelope_or_noise_accumulation {
                        params.current_envelope_sliding = env_add;
                    }
                    self.vars.add_to_env += env_add;
                } else {
                    let noise = (params.current_noise_sliding as i16 + tick.add_to_envelope_or_noise as i16) as i8;
                    if tick.envelope_or_noise_accumulation {
                        params.current_noise_sliding = noise;
                    }
                    self.vars.pt3_noise = noise as u8;
                }

                // Update mixer bits
                if !tick.mixer_ton { *temp_mixer |= 1 << ch; }
                if !tick.mixer_noise { *temp_mixer |= 1 << (ch + 3); }

                // Advance sample position
                let new_sp = sp + 1;
                params.sample_position = if new_sp >= sample.length as usize {
                    sample.loop_pos
                } else {
                    new_sp as u8
                };
            } else {
                params.amplitude = 0;
            }
        }

        // Advance ornament position
        if let Some(Some(orn)) = self.module.ornaments.get(ornament_idx) {
            let op = params.ornament_position as usize + 1;
            params.ornament_position = if op >= orn.length { orn.loop_pos as u8 } else { op as u8 };
        }

        // On/off toggling
        if params.current_on_off > 0 {
            params.current_on_off -= 1;
            if params.current_on_off == 0 {
                params.sound_enabled = !params.sound_enabled;
                params.current_on_off = if params.sound_enabled {
                    params.on_off_delay
                } else {
                    params.off_on_delay
                };
            }
        }

        // Envelope slide
        if self.vars.cur_env_delay > 0 {
            self.vars.cur_env_delay -= 1;
            if self.vars.cur_env_delay == 0 {
                self.vars.cur_env_delay = self.vars.env_delay;
                self.vars.cur_env_slide += self.vars.env_slide_add;
            }
        }
    }

    fn pattern_interpreter(&mut self, ch: usize, ay_regs: &mut AyRegisters) {
        let pat_idx = Module::pat_idx(self.vars.current_pattern);
        let line = self.vars.current_line;

        let (cell, row_envelope) = if let Some(Some(pat)) = self.module.patterns.get(pat_idx) {
            (pat.items[line].channel[ch], pat.items[line].envelope)
        } else {
            return;
        };

        let ch_idx = if self.vars.current_pattern == -1 { 1 } else { ch }; // MidChan fallback
        let params = &mut self.vars.params_of_chan[ch_idx];

        let prev_note = params.note;
        let prev_ts = params.current_ton_sliding;

        match cell.note {
            -2 => { // NOTE_SOUND_OFF
                params.sound_enabled = false;
                params.current_envelope_sliding = 0;
                params.ton_slide_count = 0;
                params.sample_position = 0;
                params.ornament_position = 0;
                params.current_noise_sliding = 0;
                params.current_amplitude_sliding = 0;
                params.current_on_off = 0;
                params.current_ton_sliding = 0;
                params.ton_accumulator = 0;
            }
            n if n >= 0 => {
                params.sound_enabled = true;
                params.note = n as u8;
                params.current_envelope_sliding = 0;
                params.ton_slide_count = 0;
                params.sample_position = 0;
                params.ornament_position = 0;
                params.current_noise_sliding = 0;
                params.current_amplitude_sliding = 0;
                params.current_on_off = 0;
                params.current_ton_sliding = 0;
                params.ton_accumulator = 0;
            }
            _ => {} // NOTE_NONE — do nothing
        }

        if cell.note >= 0 && cell.sample != 0 {
            self.module.is_chans[ch_idx].sample = cell.sample;
        }

        let env = cell.envelope;
        if env > 0 && env < 15 {
            self.module.is_chans[ch_idx].envelope_enabled = true;
            // Env_Base = row-level envelope period (Delphi: PlVars.Env_Base := Patterns[Pat].Items[Line].Envelope)
            self.vars.env_base = row_envelope as i16;
            ay_regs.env_type = env;
            self.module.is_chans[ch_idx].ornament = cell.ornament;
            self.vars.params_of_chan[ch_idx].ornament_position = 0;
            self.vars.cur_env_slide = 0;
            self.vars.cur_env_delay = 0;
        } else if env == 15 {
            self.module.is_chans[ch_idx].envelope_enabled = false;
            self.module.is_chans[ch_idx].ornament = cell.ornament;
            self.vars.params_of_chan[ch_idx].ornament_position = 0;
        } else if cell.ornament != 0 {
            self.module.is_chans[ch_idx].ornament = cell.ornament;
            self.vars.params_of_chan[ch_idx].ornament_position = 0;
        }

        if cell.volume > 0 {
            self.module.is_chans[ch_idx].volume = cell.volume;
        }

        let cmd = cell.additional_command;
        let p = &mut self.vars.params_of_chan[ch_idx];
        match cmd.number {
            1 => {
                let gls = cmd.delay as i8;
                p.ton_slide_delay = gls;
                p.ton_slide_count = gls;
                p.ton_slide_step = cmd.parameter as i16;
                p.ton_slide_type = 0;
                p.current_on_off = 0;
            }
            2 => {
                let gls = cmd.delay as i8;
                p.ton_slide_delay = gls;
                p.ton_slide_count = gls;
                p.ton_slide_step = -(cmd.parameter as i16);
                p.ton_slide_type = 0;
                p.current_on_off = 0;
            }
            3 => {
                if cell.note >= 0 {
                    p.ton_slide_delay = cmd.delay as i8;
                    p.ton_slide_count = p.ton_slide_delay;
                    p.ton_slide_step = cmd.parameter as i16;
                    let target_freq = get_note_freq(self.module.ton_table, p.note) as i16;
                    let from_freq = get_note_freq(self.module.ton_table, prev_note) as i16;
                    p.ton_slide_delta = target_freq - from_freq;
                    p.slide_to_note = p.note;
                    p.note = prev_note;
                    p.current_ton_sliding = prev_ts;
                    if p.ton_slide_delta - p.current_ton_sliding < 0 {
                        p.ton_slide_step = -p.ton_slide_step;
                    }
                    p.ton_slide_type = 1;
                    p.current_on_off = 0;
                }
            }
            4 => { p.sample_position = cmd.parameter; }
            5 => { p.ornament_position = cmd.parameter; }
            6 => {
                p.off_on_delay = (cmd.parameter & 0x0F) as i8;
                p.on_off_delay = (cmd.parameter >> 4) as i8;
                p.current_on_off = p.on_off_delay;
                p.ton_slide_count = 0;
                p.current_ton_sliding = 0;
            }
            9 => {
                self.vars.env_delay = cmd.delay as i8;
                self.vars.cur_env_delay = self.vars.env_delay;
                self.vars.env_slide_add = cmd.parameter as i16;
            }
            10 => {
                self.vars.env_delay = cmd.delay as i8;
                self.vars.cur_env_delay = self.vars.env_delay;
                self.vars.env_slide_add = -(cmd.parameter as i16);
            }
            11 => {
                if cmd.parameter != 0 {
                    self.vars.delay = cmd.parameter as i8;
                }
            }
            _ => {}
        }
    }
}

/// Initialise playback variables for one chip slot.
pub fn init_tracker_parameters(module: &mut Module, vars: &mut PlayVars, all: bool) {
    vars.delay_counter = 1;
    vars.pt3_noise = 0;
    vars.env_base = 0;
    vars.int_cnt = 0;

    if all {
        for ch in 0..3 {
            module.is_chans[ch].sample = 1;
            module.is_chans[ch].envelope_enabled = false;
            module.is_chans[ch].ornament = 0;
            module.is_chans[ch].volume = 15;
        }
    }

    for ch in 0..3 {
        vars.params_of_chan[ch] = ChanParams::default();
    }
    vars.current_line = 0;
}
