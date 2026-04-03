//! AY-3-8910 / YM2149F chip state and per-chip emulation logic.
//!
//! Ported from `TSoundChip` in `AY.pas` (c) 2000-2009 S.V.Bulba.

use vti_core::AyRegisters;

// ─── Amplitude tables (© Hacker KAY) ─────────────────────────────────────────

pub static AMPLITUDES_AY: [u16; 16] = [
    0, 836, 1212, 1773, 2619, 3875, 5397, 8823,
    10392, 16706, 23339, 29292, 36969, 46421, 55195, 65535,
];

pub static AMPLITUDES_YM: [u16; 32] = [
    0, 0, 0xF8, 0x1C2, 0x29E, 0x33A, 0x3F2, 0x4D7,
    0x610, 0x77F, 0x90A, 0xA42, 0xC3B, 0xEC2, 0x1137, 0x13A7,
    0x1750, 0x1BF9, 0x20DF, 0x2596, 0x2C9D, 0x3579, 0x3E55, 0x4768,
    0x54FF, 0x6624, 0x773B, 0x883F, 0xA1DA, 0xC0FC, 0xE094, 0xFFFF,
];

// ─── Chip type ────────────────────────────────────────────────────────────────

#[derive(Debug, Clone, Copy, PartialEq, Eq, Default)]
pub enum ChipType {
    #[default]
    None,
    AY,
    YM,
}

// ─── Envelope type handler ────────────────────────────────────────────────────

/// Which envelope shape is active (maps to the original `Case_EnvType` method pointer).
#[derive(Debug, Clone, Copy, PartialEq, Eq, Default)]
pub enum EnvShape {
    #[default]
    /// Types 0–3 and 9: hold-low (decay then silence).
    Hold0,
    /// Types 4–7 and 15: hold-high (attack then hold).
    Hold31,
    /// Type 8: sawtooth down (continuous decrement mod 32).
    Saw8,
    /// Type 10: triangle (down-up-down…).
    Triangle10,
    /// Type 11: decay-hold-low.
    DecayHold,
    /// Type 12: sawtooth up (continuous increment mod 32).
    Saw12,
    /// Type 13: attack-hold-high.
    AttackHold,
    /// Type 14: triangle (up-down-up…).
    Triangle14,
}

impl EnvShape {
    #[inline]
    pub fn from_register(v: u8) -> Self {
        match v {
            0..=3 | 9        => EnvShape::Hold0,
            4..=7 | 15       => EnvShape::Hold31,
            8                => EnvShape::Saw8,
            10               => EnvShape::Triangle10,
            11               => EnvShape::DecayHold,
            12               => EnvShape::Saw12,
            13               => EnvShape::AttackHold,
            14               => EnvShape::Triangle14,
            _                => EnvShape::Hold0,
        }
    }
}

// ─── Noise LFSR ───────────────────────────────────────────────────────────────

/// 17-bit Galois LFSR — port of the `NoiseGenerator` asm function in AY.pas.
#[inline]
pub fn noise_generator(seed: u32) -> u32 {
    let bit = ((seed >> 16) ^ (seed >> 19)) & 1;
    let s = ((seed << 1) & 0x1_FFFF) | 1;
    s ^ bit
}

// ─── SoundChip ────────────────────────────────────────────────────────────────

/// Full emulation state for one AY/YM chip instance.
///
/// Corresponds to `TSoundChip` (and the associated global variables that were
/// moved inside it when porting) in `AY.pas`.
#[derive(Debug, Clone)]
pub struct SoundChip {
    pub registers: AyRegisters,
    pub first_period: bool,
    pub ampl: i32,

    // Tone counters (split into lo:u16 / hi:u16 words for sub-sample accuracy)
    pub ton_counter_a: u32,
    pub ton_counter_b: u32,
    pub ton_counter_c: u32,
    pub noise_counter: u32,

    // Envelope counter is 64-bit (hi:u32 / lo:u32)
    pub envelope_counter: u64,

    // Current tone square-wave output (0 or 1)
    pub ton_a: i32,
    pub ton_b: i32,
    pub ton_c: i32,

    // Noise LFSR state
    pub noise_seed: u32,
    pub noise_val: u32,

    // Mixer enable flags (derived from mixer register)
    pub ton_en_a: bool,
    pub ton_en_b: bool,
    pub ton_en_c: bool,
    pub noise_en_a: bool,
    pub noise_en_b: bool,
    pub noise_en_c: bool,

    // Amplitude-uses-envelope flags
    pub envelope_en_a: bool,
    pub envelope_en_b: bool,
    pub envelope_en_c: bool,

    pub env_shape: EnvShape,

    // Accumulated stereo output (used between audio samples)
    pub left_chan: i32,
    pub right_chan: i32,
    pub tick_counter: u8,

    // Fixed-point tick accumulator
    pub tik: u32,
    pub delay_in_tiks: u32,
    pub current_tik: u32,
    pub number_of_tiks: u64,
    pub int_flag: bool,
    pub ay_tiks_in_interrupt: u32,
    pub sample_tiks_in_interrupt: u32,
}

impl Default for SoundChip {
    fn default() -> Self {
        Self {
            registers: AyRegisters::default(),
            first_period: false,
            ampl: 0,
            ton_counter_a: 0,
            ton_counter_b: 0,
            ton_counter_c: 0,
            noise_counter: 0,
            envelope_counter: 0,
            ton_a: 0,
            ton_b: 0,
            ton_c: 0,
            noise_seed: 0xFFFF,
            noise_val: 0,
            ton_en_a: false,
            ton_en_b: false,
            ton_en_c: false,
            noise_en_a: false,
            noise_en_b: false,
            noise_en_c: false,
            envelope_en_a: false,
            envelope_en_b: false,
            envelope_en_c: false,
            env_shape: EnvShape::default(),
            left_chan: 0,
            right_chan: 0,
            tick_counter: 0,
            tik: 0,
            delay_in_tiks: 0,
            current_tik: 0,
            number_of_tiks: 0,
            int_flag: false,
            ay_tiks_in_interrupt: 0,
            sample_tiks_in_interrupt: 0,
        }
    }
}

impl SoundChip {
    /// Reset all chip state (mirrors `ResetAYChipEmulation` in Pascal).
    pub fn reset(&mut self) {
        self.registers = AyRegisters::default();
        self.set_envelope_register(0);
        self.first_period = false;
        self.ampl = 0;
        self.set_mixer_register(0);
        self.set_ampl_a(0);
        self.set_ampl_b(0);
        self.set_ampl_c(0);
        self.int_flag = false;
        self.number_of_tiks = 0;
        self.current_tik = 0;
        self.envelope_counter = 0;
        self.ton_counter_a = 0;
        self.ton_counter_b = 0;
        self.ton_counter_c = 0;
        self.noise_counter = 0;
        self.ton_a = 0;
        self.ton_b = 0;
        self.ton_c = 0;
        self.left_chan = 0;
        self.right_chan = 0;
        self.tick_counter = 0;
        self.tik = self.delay_in_tiks;
        self.noise_seed = 0xFFFF;
        self.noise_val = 0;
    }

    // ─── Register setters ────────────────────────────────────────────────────

    #[inline]
    pub fn set_mixer_register(&mut self, value: u8) {
        self.registers.mixer = value;
        self.ton_en_a   = (value & 0x01) == 0;
        self.noise_en_a = (value & 0x08) == 0;
        self.ton_en_b   = (value & 0x02) == 0;
        self.noise_en_b = (value & 0x10) == 0;
        self.ton_en_c   = (value & 0x04) == 0;
        self.noise_en_c = (value & 0x20) == 0;
    }

    #[inline]
    pub fn set_envelope_register(&mut self, value: u8) {
        self.envelope_counter = 0;
        self.first_period = true;
        self.ampl = if (value & 4) == 0 { 32 } else { -1 };
        self.registers.env_type = value;
        self.env_shape = EnvShape::from_register(value);
    }

    #[inline]
    pub fn set_ampl_a(&mut self, value: u8) {
        self.registers.amplitude_a = value;
        self.envelope_en_a = (value & 0x10) != 0;
    }

    #[inline]
    pub fn set_ampl_b(&mut self, value: u8) {
        self.registers.amplitude_b = value;
        self.envelope_en_b = (value & 0x10) != 0;
    }

    #[inline]
    pub fn set_ampl_c(&mut self, value: u8) {
        self.registers.amplitude_c = value;
        self.envelope_en_c = (value & 0x10) != 0;
    }

    // ─── Envelope shape handlers ─────────────────────────────────────────────

    /// Advance envelope amplitude by one step according to the active shape.
    #[inline]
    pub fn step_envelope(&mut self) {
        match self.env_shape {
            EnvShape::Hold0 => {
                if self.first_period {
                    self.ampl -= 1;
                    if self.ampl == 0 { self.first_period = false; }
                }
            }
            EnvShape::Hold31 => {
                if self.first_period {
                    self.ampl += 1;
                    if self.ampl == 32 { self.first_period = false; self.ampl = 0; }
                }
            }
            EnvShape::Saw8 => {
                self.ampl = (self.ampl - 1) & 31;
            }
            EnvShape::Triangle10 => {
                if self.first_period {
                    self.ampl -= 1;
                    if self.ampl < 0 { self.first_period = false; self.ampl = 0; }
                } else {
                    self.ampl += 1;
                    if self.ampl == 32 { self.first_period = true; self.ampl = 31; }
                }
            }
            EnvShape::DecayHold => {
                if self.first_period {
                    self.ampl -= 1;
                    if self.ampl < 0 { self.first_period = false; self.ampl = 31; }
                }
            }
            EnvShape::Saw12 => {
                self.ampl = (self.ampl + 1) & 31;
            }
            EnvShape::AttackHold => {
                if self.first_period {
                    self.ampl += 1;
                    if self.ampl == 32 { self.first_period = false; self.ampl = 31; }
                }
            }
            EnvShape::Triangle14 => {
                if !self.first_period {
                    self.ampl -= 1;
                    if self.ampl < 0 { self.first_period = true; self.ampl = 0; }
                } else {
                    self.ampl += 1;
                    if self.ampl == 32 { self.first_period = false; self.ampl = 31; }
                }
            }
        }
    }

    // ─── Synthesizer logic — "quality" mode (integer clock) ──────────────────

    /// Advance all counters by one AY clock tick (quality mode).
    #[inline]
    pub fn synthesizer_logic_q(&mut self) {
        // Tone A
        let hi_a = (self.ton_counter_a >> 16) as u16;
        let hi_a = hi_a.wrapping_add(1);
        let ton_a_period = self.registers.ton_a;
        if hi_a >= ton_a_period {
            self.ton_counter_a = (hi_a.wrapping_sub(ton_a_period) as u32) << 16;
            self.ton_a ^= 1;
        } else {
            self.ton_counter_a = (hi_a as u32) << 16;
        }

        // Tone B
        let hi_b = (self.ton_counter_b >> 16) as u16;
        let hi_b = hi_b.wrapping_add(1);
        let ton_b_period = self.registers.ton_b;
        if hi_b >= ton_b_period {
            self.ton_counter_b = (hi_b.wrapping_sub(ton_b_period) as u32) << 16;
            self.ton_b ^= 1;
        } else {
            self.ton_counter_b = (hi_b as u32) << 16;
        }

        // Tone C
        let hi_c = (self.ton_counter_c >> 16) as u16;
        let hi_c = hi_c.wrapping_add(1);
        let ton_c_period = self.registers.ton_c;
        if hi_c >= ton_c_period {
            self.ton_counter_c = (hi_c.wrapping_sub(ton_c_period) as u32) << 16;
            self.ton_c ^= 1;
        } else {
            self.ton_counter_c = (hi_c as u32) << 16;
        }

        // Noise
        let hi_n = (self.noise_counter >> 16) as u16;
        let hi_n = hi_n.wrapping_add(1);
        if (hi_n & 1 == 0) && (hi_n >= (self.registers.noise as u16) << 1) {
            self.noise_counter = 0;
            self.noise_seed = noise_generator(self.noise_seed);
            self.noise_val = self.noise_seed & 1;
        } else {
            self.noise_counter = (hi_n as u32) << 16;
        }

        // Envelope
        let env_hi = (self.envelope_counter >> 32) as u32;
        if env_hi == 0 {
            self.step_envelope();
        }
        let env_hi = env_hi.wrapping_add(1);
        let env_period = self.registers.envelope as u32;
        if env_hi >= env_period {
            self.envelope_counter = 0;
        } else {
            self.envelope_counter = (env_hi as u64) << 32;
        }
    }

    /// Compute stereo mix contribution for quality mode, accumulate into `lev_l`/`lev_r`.
    #[inline]
    pub fn synthesizer_mixer_q(
        &self,
        level_al: &[i32; 32],
        level_ar: &[i32; 32],
        level_bl: &[i32; 32],
        level_br: &[i32; 32],
        level_cl: &[i32; 32],
        level_cr: &[i32; 32],
        lev_l: &mut i32,
        lev_r: &mut i32,
    ) {
        let ampl = self.ampl.clamp(0, 31) as usize;

        // Channel A
        let mut k = 1i32;
        if self.ton_en_a { k = self.ton_a; }
        if self.noise_en_a { k &= self.noise_val as i32; }
        if k != 0 {
            // envelope_en_a=false → fixed amplitude (bit 4 clear) → use register value
            // envelope_en_a=true  → envelope controls level     → use envelope counter
            let idx = if self.envelope_en_a {
                ampl
            } else {
                (self.registers.amplitude_a as usize * 2 + 1).min(31)
            };
            *lev_l += level_al[idx];
            *lev_r += level_ar[idx];
        }

        // Channel B
        let mut k = 1i32;
        if self.ton_en_b { k = self.ton_b; }
        if self.noise_en_b { k &= self.noise_val as i32; }
        if k != 0 {
            let idx = if self.envelope_en_b {
                ampl
            } else {
                (self.registers.amplitude_b as usize * 2 + 1).min(31)
            };
            *lev_l += level_bl[idx];
            *lev_r += level_br[idx];
        }

        // Channel C
        let mut k = 1i32;
        if self.ton_en_c { k = self.ton_c; }
        if self.noise_en_c { k &= self.noise_val as i32; }
        if k != 0 {
            let idx = if self.envelope_en_c {
                ampl
            } else {
                (self.registers.amplitude_c as usize * 2 + 1).min(31)
            };
            *lev_l += level_cl[idx];
            *lev_r += level_cr[idx];
        }
    }
}
