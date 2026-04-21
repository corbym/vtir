//! High-level synthesizer: drives N chips, produces stereo-16 PCM samples.
//!
//! Ported from `Synthesizer_Stereo16`, `MakeBuffer`, `Get_Registers`,
//! `Calculate_Level_Tables` etc. in `AY.pas` (c) 2000-2009 S.V.Bulba.

use crate::chip::{ChipType, SoundChip, AMPLITUDES_AY, AMPLITUDES_YM};
use crate::config::AyConfig;
use vti_core::AyRegisters;

/// Output sample format produced by the synthesizer.
#[derive(Debug, Clone, Copy, Default)]
pub struct StereoSample {
    pub left: i16,
    pub right: i16,
}

/// Per-channel panning / level tables (32 entries each).
#[derive(Debug, Clone)]
pub struct LevelTables {
    pub al: [i32; 32],
    pub ar: [i32; 32],
    pub bl: [i32; 32],
    pub br: [i32; 32],
    pub cl: [i32; 32],
    pub cr: [i32; 32],
}

impl Default for LevelTables {
    fn default() -> Self {
        Self {
            al: [0; 32],
            ar: [0; 32],
            bl: [0; 32],
            br: [0; 32],
            cl: [0; 32],
            cr: [0; 32],
        }
    }
}

/// Build amplitude→level tables from panning indices and chip type.
///
/// Direct port of `Calculate_Level_Tables` in `digsoundbuf.pas`.
///
/// ## Stereo vs mono
///
/// Pascal computes `l` as `max(sum_L, sum_R) * 2` (stereo) or
/// `(sum_combined) * 2` (mono).  The `* 2` was previously missing,
/// causing every level table entry to be 2× too large (potential
/// clipping on loud passages).
///
/// In stereo mode the per-channel index used in the formula equals
/// the left-panning index (`Index_AL/BL/CL`) for the left table and
/// the raw right-panning index (`Index_AR/BR/CR`) for the right table.
/// In mono mode the left tables use the combined `Index_AL + Index_AR`
/// (and likewise for B and C), while the right tables still use the raw
/// right-panning index — faithfully matching the Pascal original.
///
/// ## Formula
///
/// Pascal: `trunc(Index / l * Amplitudes[i] / 65535 * r * k + 0.5)`
///
/// One single floating-point rounding (trunc + 0.5 = round-half-up).
/// The previous Rust code used an intermediate integer `scale` and two
/// `round()` calls, introducing small quantisation errors.
pub fn calculate_level_tables(cfg: &AyConfig, chip_type: ChipType) -> LevelTables {
    let mut t = LevelTables::default();

    let ia   = cfg.index_al as i32;
    let ia_r = cfg.index_ar as i32;
    let ib   = cfg.index_bl as i32;
    let ib_r = cfg.index_br as i32;
    let ic   = cfg.index_cl as i32;
    let ic_r = cfg.index_cr as i32;

    // Pascal stereo:  Index_A = Index_AL; l = max(sum_L, sum_R) * 2
    // Pascal mono:    Index_A = Index_AL + Index_AR; l = sum_combined * 2
    let (index_a, index_b, index_c, mut l) = if cfg.num_channels == 2 {
        let l_left  = (ia   + ib   + ic)   * 2;
        let l_right = (ia_r + ib_r + ic_r) * 2;
        (ia, ib, ic, l_left.max(l_right))
    } else {
        let index_a = ia   + ia_r;
        let index_b = ib   + ib_r;
        let index_c = ic   + ic_r;
        let l       = (index_a + index_b + index_c) * 2;
        (index_a, index_b, index_c, l)
    };
    if l == 0 { l = 1; }

    let max_out = if cfg.sample_bit == 8 { 127i32 } else { 32767i32 };

    let k = (cfg.global_volume * 2_f64.ln() / cfg.global_volume_max).exp() - 1.0;

    // Pascal: b := trunc(Index / l * Amplitudes[i] / 65535 * r * k + 0.5)
    // Single rounding step; no intermediate integer scale.
    let fill = |idx: i32, amp: f64| -> i32 {
        (idx as f64 / l as f64 * amp / 65535.0 * max_out as f64 * k + 0.5).trunc() as i32
    };

    match chip_type {
        ChipType::AY => {
            for i in 0..16usize {
                let amp = AMPLITUDES_AY[i] as f64;
                let v = fill(index_a, amp); t.al[i * 2] = v; t.al[i * 2 + 1] = v;
                let v = fill(ia_r,    amp); t.ar[i * 2] = v; t.ar[i * 2 + 1] = v;
                let v = fill(index_b, amp); t.bl[i * 2] = v; t.bl[i * 2 + 1] = v;
                let v = fill(ib_r,    amp); t.br[i * 2] = v; t.br[i * 2 + 1] = v;
                let v = fill(index_c, amp); t.cl[i * 2] = v; t.cl[i * 2 + 1] = v;
                let v = fill(ic_r,    amp); t.cr[i * 2] = v; t.cr[i * 2 + 1] = v;
            }
        }
        ChipType::YM => {
            for i in 0..32usize {
                let amp = AMPLITUDES_YM[i] as f64;
                t.al[i] = fill(index_a, amp);
                t.ar[i] = fill(ia_r,    amp);
                t.bl[i] = fill(index_b, amp);
                t.br[i] = fill(ib_r,    amp);
                t.cl[i] = fill(index_c, amp);
                t.cr[i] = fill(ic_r,    amp);
            }
        }
        ChipType::None => {}
    }

    t
}

/// Linear interpolation between two i16 samples.
///
/// Direct port of `Interpolator16` in `digsoundbuf.pas`:
/// ```pascal
/// function Interpolator16(l1, l0, ofs: integer): integer;
/// begin
///   Result := (l1 - l0) * ofs div 65536 + l0;
/// ```
/// `ofs` is in the range `[0, 65536]`:
/// * `ofs = 65536` selects `l1` (current value, exact trigger point).
/// * `ofs < 65536` blends towards `l0` (previous value) when the output sample
///   falls between AY clock ticks.
///
/// In the Bresenham upsampler the caller guarantees `filt_tick_counter >= filt_tik`
/// before computing `i = filt_tik − filt_tick_counter + 65536`, which means
/// `filt_tik − filt_tick_counter ∈ (−65536, 0]` (at most one AY tick of overshoot),
/// so `i ∈ (0, 65536]`.  The result is clamped to `i16` range.
#[inline]
fn interpolate16(l1: i32, l0: i32, ofs: i32) -> i16 {
    let result = (l1 - l0) * ofs / 65536 + l0;
    result.clamp(-32768, 32767) as i16
}

/// Drives up to [`MAX_CHIPS`] AY chips and renders PCM audio.
pub const MAX_CHIPS: usize = 2;

pub struct Synthesizer {
    pub chips: [SoundChip; MAX_CHIPS],
    pub num_chips: usize,
    pub levels: LevelTables,
    pub cfg: AyConfig,

    // Current AY register snapshots per chip (set by the tracker engine each interrupt)
    pub pending_regs: [Option<AyRegisters>; MAX_CHIPS],

    /// Buffered audio samples not yet handed to cpal.
    pub output_buf: Vec<StereoSample>,

    // FIR filter state (quality mode)
    filt_x_l: Vec<i32>,
    filt_x_r: Vec<i32>,
    filt_k:   Vec<i32>,
    filt_i:   usize,

    // Bresenham upsampler state for quality mode (persists across frames)
    // Matches Pascal's Tick_Counter.Re / Tik.Re fields in TBufferMaker.
    filt_tick_counter: i32, // AY ticks accumulated × 65536 (reset to 0 after each output batch)
    filt_tik:          i32, // next output trigger point (starts at delay_in_tiks, +delay each sample)
    filt_last_l:       i32, // current FIR-filtered left value (updated each AY tick)
    filt_last_r:       i32, // current FIR-filtered right value
    filt_prev_l:       i32, // previous FIR-filtered left value (one AY tick earlier)
    filt_prev_r:       i32, // previous FIR-filtered right value (one AY tick earlier)
}

impl Synthesizer {
    pub fn new(cfg: AyConfig, num_chips: usize, chip_type: ChipType) -> Self {
        let levels = calculate_level_tables(&cfg, chip_type);
        let filt_m = cfg.filt_m;
        let mut s = Self {
            chips: std::array::from_fn(|_| SoundChip::default()),
            num_chips: num_chips.min(MAX_CHIPS),
            levels,
            cfg: cfg.clone(),
            pending_regs: std::array::from_fn(|_| None),
            output_buf: Vec::new(),
            filt_x_l: vec![0; filt_m + 1],
            filt_x_r: vec![0; filt_m + 1],
            filt_k: vec![0; filt_m + 1],
            filt_i: 0,
            filt_tick_counter: 0,
            filt_tik: 0, // overwritten below after delay is computed
            filt_last_l: 0,
            filt_last_r: 0,
            filt_prev_l: 0,
            filt_prev_r: 0,
        };
        let delay = s.cfg.delay_in_tiks();
        for chip in &mut s.chips {
            chip.delay_in_tiks = delay;
            chip.ay_tiks_in_interrupt = s.cfg.ay_tiks_in_interrupt();
            chip.sample_tiks_in_interrupt = s.cfg.sample_tiks_in_interrupt();
        }
        s.filt_tik = delay as i32; // Tik.Re starts at Delay_In_Tiks
        s.calc_fir_coefficients();
        s
    }

    /// Apply pending register writes to a chip.
    pub fn apply_registers(&mut self, chip_idx: usize, regs: &AyRegisters) {
        let chip = &mut self.chips[chip_idx];
        chip.set_mixer_register(regs.mixer);
        chip.registers.ton_a = regs.ton_a;
        chip.registers.ton_b = regs.ton_b;
        chip.registers.ton_c = regs.ton_c;
        chip.set_ampl_a(regs.amplitude_a);
        chip.set_ampl_b(regs.amplitude_b);
        chip.set_ampl_c(regs.amplitude_c);
        chip.registers.noise = regs.noise;
        chip.registers.envelope = regs.envelope;
        if regs.env_type != chip.registers.env_type {
            chip.set_envelope_register(regs.env_type);
        }
    }

    // ─── Performance-mode render loop ────────────────────────────────────────

    /// Render `n_samples` audio samples in **performance** (audio-rate) mode.
    ///
    /// Each call advances the AY chip exactly `n_samples` counter-clock ticks and
    /// pushes `n_samples` stereo samples to `output_buf`.  This is intentionally
    /// simpler than quality mode: the chip runs at audio sample rate rather than
    /// at the correct AY clock rate, which means tones are at the wrong pitch.
    ///
    /// Use [`render_frame_quality`](Synthesizer::render_frame_quality) for correct
    /// audio output.  This method exists for unit tests and the future
    /// performance-mode path.
    pub fn render_frame(&mut self, n_samples: u32) {
        // Copy level tables locally so the borrow checker allows &mut self
        // calls to apply_filter within the same loop body.
        let al = self.levels.al;
        let ar = self.levels.ar;
        let bl = self.levels.bl;
        let br = self.levels.br;
        let cl = self.levels.cl;
        let cr = self.levels.cr;

        let mono = self.cfg.num_channels == 1;

        for _ in 0..n_samples {
            let mut lev_l = 0i32;
            let mut lev_r = 0i32;

            for c in 0..self.num_chips {
                self.chips[c].synthesizer_logic_q();
                if mono {
                    self.chips[c].synthesizer_mixer_q_mono(&al, &bl, &cl, &mut lev_l);
                } else {
                    self.chips[c].synthesizer_mixer_q(
                        &al, &ar, &bl, &br, &cl, &cr,
                        &mut lev_l, &mut lev_r,
                    );
                }
            }

            // FIR low-pass filter (quality mode)
            if self.cfg.is_filt {
                lev_l = self.apply_filter(lev_l, true);
                if !mono {
                    lev_r = self.apply_filter(lev_r, false);
                }
            }

            if mono { lev_r = lev_l; }

            self.output_buf.push(StereoSample {
                left:  lev_l.clamp(-32768, 32767) as i16,
                right: lev_r.clamp(-32768, 32767) as i16,
            });
        }
    }

    /// Drain up to `max` samples from the output buffer.
    #[inline]
    pub fn drain(&mut self, max: usize) -> Vec<StereoSample> {
        let n = max.min(self.output_buf.len());
        self.output_buf.drain(..n).collect()
    }

    // ─── Quality-mode render loop ─────────────────────────────────────────────

    /// Render one interrupt frame in **quality** mode.
    ///
    /// Faithfully ports `TBufferMaker.Synthesizer_Stereo16` from `digsoundbuf.pas`:
    ///
    /// * Runs the AY chip at the correct clock rate (`ay_tiks_in_interrupt` ≈ 4434
    ///   counter-clock ticks per 50 Hz frame at 1.77 MHz).
    /// * Uses a Bresenham integer upsampler (`Tick_Counter` / `Tik` mechanism) to
    ///   decimate the AY-rate output to audio sample rate, producing approximately
    ///   `sample_tiks_in_interrupt` ≈ 960 samples @ 48 kHz.
    /// * Upsampler state (`filt_tick_counter`, `filt_tik`) persists across calls so
    ///   phase is preserved across interrupt boundaries.
    ///
    /// When the FIR filter is active, each output sample is **linearly interpolated**
    /// between the previous and current filtered values at the exact sub-tick trigger
    /// point, matching Pascal's `Interpolator16(Left_Chan, PrevLeft, i)` call where
    /// `i = Tik.Re - Tick_Counter.Re + 65536`.  This eliminates the timing jitter
    /// that the previous "use last sample" approach produced.
    ///
    /// Compare with [`render_frame`] which runs at audio rate and is used for tests
    /// and the (unimplemented) performance mode.
    pub fn render_frame_quality(&mut self) {
        let al = self.levels.al;
        let ar = self.levels.ar;
        let bl = self.levels.bl;
        let br = self.levels.br;
        let cl = self.levels.cl;
        let cr = self.levels.cr;

        let mono = self.cfg.num_channels == 1;

        let n_ay = self.chips[0].ay_tiks_in_interrupt;
        let delay = self.cfg.delay_in_tiks() as i32; // Delay_In_Tiks = 302460

        for _ in 0..n_ay {
            // ── Bresenham upsampler: output audio sample(s) when due ─────────
            // Pascal: if Tick_Counter.Re >= Tik.Re then begin
            //           repeat output; Inc(Tik.Re, Delay); until Tick_Counter.Re < Tik.Re;
            //           Dec(Tik.Re, Tick_Counter.Re); Tick_Counter.Re := 0; end;
            if self.filt_tick_counter >= self.filt_tik {
                loop {
                    // Pascal: i := Tik.Re - Tick_Counter.Re + 65536
                    // When filter is active: Interpolator16(Left_Chan, PrevLeft, i)
                    // = PrevLeft + (Left_Chan - PrevLeft) * i / 65536
                    // i = 65536 when the sample falls exactly on the AY tick boundary,
                    // < 65536 when it falls between ticks (blend towards prev value).
                    let left;
                    let right;
                    if self.cfg.is_filt {
                        let i = self.filt_tik - self.filt_tick_counter + 65536;
                        left  = interpolate16(self.filt_last_l, self.filt_prev_l, i);
                        right = interpolate16(self.filt_last_r, self.filt_prev_r, i);
                    } else {
                        left  = self.filt_last_l.clamp(-32768, 32767) as i16;
                        right = self.filt_last_r.clamp(-32768, 32767) as i16;
                    }
                    self.output_buf.push(StereoSample { left, right });
                    self.filt_tik += delay;
                    if self.filt_tick_counter < self.filt_tik { break; }
                }
                // Pascal: Dec(Tik.Re, Tick_Counter.Re); Tick_Counter.Re := 0;
                self.filt_tik -= self.filt_tick_counter;
                self.filt_tick_counter = 0;
            }

            // ── Advance all chips one AY counter-clock tick ──────────────────
            let mut lev_l = 0i32;
            let mut lev_r = 0i32;
            for c in 0..self.num_chips {
                self.chips[c].synthesizer_logic_q();
                if mono {
                    self.chips[c].synthesizer_mixer_q_mono(&al, &bl, &cl, &mut lev_l);
                } else {
                    self.chips[c].synthesizer_mixer_q(
                        &al, &ar, &bl, &br, &cl, &cr,
                        &mut lev_l, &mut lev_r,
                    );
                }
            }

            // ── FIR anti-aliasing filter (runs at AY clock rate) ─────────────
            if self.cfg.is_filt {
                lev_l = self.apply_filter(lev_l, true);
                if !mono {
                    lev_r = self.apply_filter(lev_r, false);
                }
            }

            if mono { lev_r = lev_l; }

            // Pascal: PrevLeft := Left_Chan; Left_Chan := LevelL;
            // Shift current → prev before storing new current.
            self.filt_prev_l = self.filt_last_l;
            self.filt_prev_r = self.filt_last_r;
            self.filt_last_l = lev_l;
            self.filt_last_r = lev_r;

            // Pascal: Inc(Tick_Counter.Hi) → adds 65536 to the 32-bit Tick_Counter
            self.filt_tick_counter = self.filt_tick_counter.wrapping_add(65536);
        }
    }


    /// Compute windowed-sinc FIR coefficients (Hanning window, cutoff ~0.45 Nyquist).
    fn calc_fir_coefficients(&mut self) {
        let m = self.cfg.filt_m;
        self.filt_k.resize(m + 1, 0);
        let fc = 0.45_f64;
        for i in 0..=m {
            let x = std::f64::consts::PI * (i as f64 - m as f64 / 2.0);
            let sinc = if x == 0.0 { 1.0 } else { (2.0 * fc * x).sin() / x };
            let window = 0.5 * (1.0 - (2.0 * std::f64::consts::PI * i as f64 / m as f64).cos());
            self.filt_k[i] = (sinc * window * (1 << 24) as f64).round() as i32;
        }
    }

    /// Apply the FIR filter to one sample value.
    fn apply_filter(&mut self, lev: i32, is_left: bool) -> i32 {
        let m = self.cfg.filt_m;
        let x_buf = if is_left { &mut self.filt_x_l } else { &mut self.filt_x_r };
        x_buf[self.filt_i] = lev;

        let mut acc = 0i64;
        let mut ki = self.filt_i;
        for j in 0..=m {
            acc += self.filt_k[j] as i64 * x_buf[ki] as i64;
            if ki == 0 { ki = m } else { ki -= 1; }
        }
        if is_left {
            self.filt_i = if self.filt_i == m { 0 } else { self.filt_i + 1 };
        }
        // Round and shift by 24
        let rounded = if acc < 0 { acc + 0x00FF_FFFF } else { acc };
        (rounded >> 24) as i32
    }
}
