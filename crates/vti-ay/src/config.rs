//! AY/YM chip emulator configuration.

pub const AY_FREQ_DEF: u32 = 1_750_000;
pub const INTERRUPT_FREQ_DEF: u32 = 48_828;
pub const NUMBER_OF_CHANNELS_DEF: u8 = 2;
pub const SAMPLE_RATE_DEF: u32 = 44_100;
pub const SAMPLE_BIT_DEF: u8 = 16;

// Default channel-to-stereo panning indices (0..=255 per side).
pub const INDEX_AL_DEF: u8 = 255;
pub const INDEX_AR_DEF: u8 = 13;
pub const INDEX_BL_DEF: u8 = 170;
pub const INDEX_BR_DEF: u8 = 170;
pub const INDEX_CL_DEF: u8 = 13;
pub const INDEX_CR_DEF: u8 = 255;

pub const STD_CHANNELS_ALLOCATION_DEF: u8 = 1;
pub const FILT_N_KOEFS: usize = 32;

/// Global audio / emulation configuration.
#[derive(Debug, Clone)]
pub struct AyConfig {
    pub sample_rate: u32,
    pub ay_freq: u32,
    pub interrupt_freq: u32,
    pub sample_bit: u8,
    pub num_channels: u8,
    pub index_al: u8,
    pub index_ar: u8,
    pub index_bl: u8,
    pub index_br: u8,
    pub index_cl: u8,
    pub index_cr: u8,
    pub std_channels_allocation: u8,
    pub optimization_for_quality: bool,
    pub is_filt: bool,
    pub filt_m: usize,
    pub global_volume: f64,
    pub global_volume_max: f64,
}

impl Default for AyConfig {
    fn default() -> Self {
        Self {
            sample_rate: SAMPLE_RATE_DEF,
            ay_freq: AY_FREQ_DEF,
            interrupt_freq: INTERRUPT_FREQ_DEF,
            sample_bit: SAMPLE_BIT_DEF,
            num_channels: NUMBER_OF_CHANNELS_DEF,
            index_al: INDEX_AL_DEF,
            index_ar: INDEX_AR_DEF,
            index_bl: INDEX_BL_DEF,
            index_br: INDEX_BR_DEF,
            index_cl: INDEX_CL_DEF,
            index_cr: INDEX_CR_DEF,
            std_channels_allocation: STD_CHANNELS_ALLOCATION_DEF,
            optimization_for_quality: true,
            is_filt: true,
            filt_m: FILT_N_KOEFS,
            global_volume: 1.0,
            global_volume_max: 1.0,
        }
    }
}

impl AyConfig {
    /// How many AY clock ticks fit in one interrupt period.
    #[inline]
    pub fn ay_tiks_in_interrupt(&self) -> u32 {
        (self.ay_freq as f64 / (self.interrupt_freq as f64 / 1000.0 * 8.0)).round() as u32
    }

    /// How many audio samples fit in one interrupt period.
    #[inline]
    pub fn sample_tiks_in_interrupt(&self) -> u32 {
        (self.sample_rate as f64 / self.interrupt_freq as f64 * 1000.0).round() as u32
    }

    /// Fixed-point AY ticks per audio sample (× 8192).
    #[inline]
    pub fn delay_in_tiks(&self) -> u32 {
        (8192.0 / self.sample_rate as f64 * self.ay_freq as f64).round() as u32
    }

    /// Audio buffer length in samples.
    #[inline]
    pub fn buffer_length(&self, buf_len_ms: u32) -> u32 {
        (buf_len_ms as f64 * self.sample_rate as f64 / 1000.0).round() as u32
    }
}
