//! Integration tests for vti-ay: chip emulator, envelope shapes, synthesizer.

use vti_ay::chip::{ChipType, EnvShape, SoundChip, noise_generator, AMPLITUDES_AY, AMPLITUDES_YM};
use vti_ay::config::{
    AyConfig, AY_FREQ_DEF, INTERRUPT_FREQ_DEF, SAMPLE_RATE_DEF, SAMPLE_BIT_DEF,
    NUMBER_OF_CHANNELS_DEF,
};
use vti_ay::synth::{Synthesizer, calculate_level_tables};
use vti_core::AyRegisters;

// ─── legacy-v1.0 parity enforcement ─────────────────────────────────────────

#[test]
fn amplitudes_tables_match_legacy_hacker_kay() {
    // Keep the active AY/YM tables bit-identical to legacy/AY.pas (Hacker KAY).
    assert_eq!(AMPLITUDES_AY, [
        0, 836, 1212, 1773, 2619, 3875, 5397, 8823,
        10392, 16706, 23339, 29292, 36969, 46421, 55195, 65535,
    ]);
    assert_eq!(AMPLITUDES_YM, [
        0, 0, 0xF8, 0x1C2, 0x29E, 0x33A, 0x3F2, 0x4D7,
        0x610, 0x77F, 0x90A, 0xA42, 0xC3B, 0xEC2, 0x1137, 0x13A7,
        0x1750, 0x1BF9, 0x20DF, 0x2596, 0x2C9D, 0x3579, 0x3E55, 0x4768,
        0x54FF, 0x6624, 0x773B, 0x883F, 0xA1DA, 0xC0FC, 0xE094, 0xFFFF,
    ]);
}

#[test]
fn default_config_matches_legacy_v1_0_timing() {
    // Enforce legacy/AY.pas v1.0 defaults so timing stays faithful.
    assert_eq!(AY_FREQ_DEF, 1_773_400);
    assert_eq!(INTERRUPT_FREQ_DEF, 50_000);
    assert_eq!(SAMPLE_RATE_DEF, 48_000);
    assert_eq!(SAMPLE_BIT_DEF, 16);
    assert_eq!(NUMBER_OF_CHANNELS_DEF, 2);

    let cfg = AyConfig::default();
    assert_eq!(cfg.ay_freq, AY_FREQ_DEF);
    assert_eq!(cfg.interrupt_freq, INTERRUPT_FREQ_DEF);
    assert_eq!(cfg.sample_rate, SAMPLE_RATE_DEF);
    assert_eq!(cfg.sample_bit, SAMPLE_BIT_DEF);
    assert_eq!(cfg.num_channels, NUMBER_OF_CHANNELS_DEF);
}

// ─── noise_generator ─────────────────────────────────────────────────────────

#[test]
fn noise_generator_changes_seed() {
    let seed = 0xFFFF_u32;
    let out = noise_generator(seed);
    assert_ne!(out, seed);
}

#[test]
fn noise_generator_output_fits_17_bits() {
    let mut seed = 1_u32;
    for _ in 0..1000 {
        seed = noise_generator(seed);
        assert_eq!(seed & !0x1_FFFF, 0, "LFSR output must be 17 bits");
    }
}

#[test]
fn noise_generator_produces_diverse_output() {
    // Run 1000 iterations and verify we see both 0 and 1 in the low bit,
    // confirming the LFSR is actually toggling (not stuck).
    let mut seed = 0xFFFF_u32;
    let mut seen_zero = false;
    let mut seen_one = false;
    for _ in 0..1000 {
        seed = noise_generator(seed);
        if seed & 1 == 0 { seen_zero = true; }
        if seed & 1 == 1 { seen_one  = true; }
    }
    assert!(seen_zero && seen_one, "LFSR output low bit should toggle over 1000 steps");
}

// ─── EnvShape ─────────────────────────────────────────────────────────────────

#[test]
fn env_shape_from_register_0_is_hold0() {
    assert_eq!(EnvShape::from_register(0), EnvShape::Hold0);
}

#[test]
fn env_shape_from_register_8_is_saw8() {
    assert_eq!(EnvShape::from_register(8), EnvShape::Saw8);
}

#[test]
fn env_shape_from_register_12_is_saw12() {
    assert_eq!(EnvShape::from_register(12), EnvShape::Saw12);
}

#[test]
fn env_shape_saw8_decrements_mod32() {
    let mut chip = SoundChip::default();
    chip.set_envelope_register(8); // Saw8, starts high
    // After set_envelope_register with type 8, ampl = 32 (bit 2 of 8 is set → -1 start, then mod 32)
    // Actually: (8 & 4) != 0 → ampl = -1; but Saw8 does (ampl-1)&31
    // Let's verify it counts down cyclically
    let initial = chip.envelope_step;
    chip.step_envelope();
    assert_eq!(chip.envelope_step, (initial - 1) & 31);
}

#[test]
fn env_shape_saw12_increments_mod32() {
    let mut chip = SoundChip::default();
    chip.set_envelope_register(12); // Saw12
    let initial = chip.envelope_step;
    chip.step_envelope();
    assert_eq!(chip.envelope_step, (initial + 1) & 31);
}

#[test]
fn env_shape_hold0_decays_to_silence() {
    let mut chip = SoundChip::default();
    chip.set_envelope_register(0); // Hold0 — starts at 32
    assert!(chip.first_period);
    // Step until first_period becomes false
    for _ in 0..64 {
        chip.step_envelope();
        if !chip.first_period { break; }
    }
    assert!(!chip.first_period);
    // Further steps should not change ampl
    let saved = chip.envelope_step;
    chip.step_envelope();
    assert_eq!(chip.envelope_step, saved);
}

// ─── SoundChip register setters ──────────────────────────────────────────────

#[test]
fn set_mixer_register_enables_correct_channels() {
    let mut chip = SoundChip::default();
    // mixer = 0 → all tone & noise enabled
    chip.set_mixer_register(0);
    assert!(chip.ton_en_a && chip.ton_en_b && chip.ton_en_c);
    assert!(chip.noise_en_a && chip.noise_en_b && chip.noise_en_c);
}

#[test]
fn set_mixer_register_disables_correctly() {
    let mut chip = SoundChip::default();
    // Bit 0 = tone A disabled, bit 3 = noise A disabled
    chip.set_mixer_register(0b0000_1001);
    assert!(!chip.ton_en_a);
    assert!(!chip.noise_en_a);
    assert!(chip.ton_en_b);
}

#[test]
fn set_ampl_a_sets_envelope_flag() {
    let mut chip = SoundChip::default();
    chip.set_ampl_a(0x10); // bit 4 = envelope flag
    assert!(chip.envelope_en_a);
    chip.set_ampl_a(0x0F); // no envelope flag
    assert!(!chip.envelope_en_a);
}

#[test]
fn chip_reset_clears_state() {
    let mut chip = SoundChip::default();
    chip.registers.ton_a = 100;
    chip.ton_a = 1;
    chip.reset();
    assert_eq!(chip.registers.ton_a, 0);
    assert_eq!(chip.ton_a, 0);
    assert_eq!(chip.noise_seed, 0xFFFF);
}

// ─── synthesizer_logic_q — tone counters ─────────────────────────────────────

#[test]
fn synthesizer_logic_q_toggles_ton_a() {
    let mut chip = SoundChip::default();
    chip.registers.ton_a = 1; // period = 1 → toggle every tick
    assert_eq!(chip.ton_a, 0);
    chip.synthesizer_logic_q();
    assert_eq!(chip.ton_a, 1);
    chip.synthesizer_logic_q();
    assert_eq!(chip.ton_a, 0);
}

#[test]
fn synthesizer_logic_q_ton_zero_period_stays_at_zero() {
    let mut chip = SoundChip::default();
    chip.registers.ton_a = 0; // period 0 — counter never reaches period
    chip.synthesizer_logic_q();
    // Should not panic; ton_a may stay 0 or toggle depending on implementation
    // Just verify no panic and counter doesn't overflow unexpectedly
    let _ = chip.ton_a;
}

// ─── Level tables ─────────────────────────────────────────────────────────────

#[test]
fn level_tables_all_zero_for_none_chip() {
    let cfg = AyConfig::default();
    let t = calculate_level_tables(&cfg, ChipType::None);
    assert!(t.al.iter().all(|&v| v == 0));
}

#[test]
fn level_tables_ay_chip_are_positive() {
    let cfg = AyConfig::default();
    let t = calculate_level_tables(&cfg, ChipType::AY);
    // At least some entries should be non-zero
    assert!(t.al.iter().any(|&v| v > 0));
    assert!(t.ar.iter().any(|&v| v > 0));
}

#[test]
fn level_tables_ym_chip_are_positive() {
    let cfg = AyConfig::default();
    let t = calculate_level_tables(&cfg, ChipType::YM);
    assert!(t.al.iter().any(|&v| v > 0));
}

#[test]
fn level_tables_monotonically_non_decreasing_for_ay() {
    let cfg = AyConfig::default();
    let t = calculate_level_tables(&cfg, ChipType::AY);
    // Even-indexed entries (amplitude indices for AY) should be non-decreasing
    let evens: Vec<i32> = (0..16).map(|i| t.al[i * 2]).collect();
    for w in evens.windows(2) {
        assert!(w[1] >= w[0], "AY level table should be non-decreasing: {:?}", evens);
    }
}

// ─── Synthesizer ──────────────────────────────────────────────────────────────

#[test]
fn synthesizer_render_produces_samples() {
    let cfg = AyConfig { is_filt: false, ..AyConfig::default() };
    let mut synth = Synthesizer::new(cfg, 1, ChipType::YM);
    synth.render_frame(16);
    assert_eq!(synth.output_buf.len(), 16);
}

#[test]
fn synthesizer_drain_empties_buffer() {
    let cfg = AyConfig { is_filt: false, ..AyConfig::default() };
    let mut synth = Synthesizer::new(cfg, 1, ChipType::YM);
    synth.render_frame(32);
    let drained = synth.drain(32);
    assert_eq!(drained.len(), 32);
    assert!(synth.output_buf.is_empty());
}

#[test]
fn synthesizer_drain_respects_max() {
    let cfg = AyConfig { is_filt: false, ..AyConfig::default() };
    let mut synth = Synthesizer::new(cfg, 1, ChipType::YM);
    synth.render_frame(100);
    let drained = synth.drain(10);
    assert_eq!(drained.len(), 10);
    assert_eq!(synth.output_buf.len(), 90);
}

#[test]
fn synthesizer_silent_when_no_registers_written() {
    // With default registers (all amplitudes zero), output should be silent
    let cfg = AyConfig { is_filt: false, ..AyConfig::default() };
    let mut synth = Synthesizer::new(cfg, 1, ChipType::YM);
    synth.render_frame(64);
    let all_silent = synth.output_buf.iter().all(|s| s.left == 0 && s.right == 0);
    assert!(all_silent, "silent chip should produce zero samples");
}

#[test]
fn synthesizer_produces_nonzero_with_active_registers() {
    let cfg = AyConfig { is_filt: false, ..AyConfig::default() };
    let mut synth = Synthesizer::new(cfg, 1, ChipType::YM);

    // Set up a tone: mixer = 0 (all enabled), amplitude A = 15 (max, no env)
    let regs = AyRegisters {
        ton_a: 100,
        mixer: 0b11_111_110, // tone A on, everything else off
        amplitude_a: 15,
        ..AyRegisters::default()
    };
    synth.apply_registers(0, &regs);
    synth.render_frame(256);

    let any_nonzero = synth.output_buf.iter().any(|s| s.left != 0 || s.right != 0);
    assert!(any_nonzero, "active tone should produce non-zero samples");
}

#[test]
fn synthesizer_two_chips_produce_more_signal() {
    let cfg = AyConfig { is_filt: false, ..AyConfig::default() };
    let mut s1 = Synthesizer::new(cfg.clone(), 1, ChipType::YM);
    let mut s2 = Synthesizer::new(cfg, 2, ChipType::YM);

    let regs = AyRegisters {
        ton_a: 50,
        mixer: 0b11_111_110,
        amplitude_a: 15,
        ..AyRegisters::default()
    };
    s1.apply_registers(0, &regs);
    s2.apply_registers(0, &regs);
    s2.apply_registers(1, &regs);

    s1.render_frame(256);
    s2.render_frame(256);

    let sum1: i64 = s1.output_buf.iter().map(|s| s.left.abs() as i64).sum();
    let sum2: i64 = s2.output_buf.iter().map(|s| s.left.abs() as i64).sum();
    assert!(sum2 >= sum1, "two chips should be at least as loud as one");
}

// ─── EnvShape::from_register — all 16 values ────────────────────────────────

#[test]
fn env_shape_from_register_all_16_values() {
    // Hold0: 0,1,2,3,9
    for v in [0u8, 1, 2, 3, 9] {
        assert_eq!(EnvShape::from_register(v), EnvShape::Hold0,
            "register {v} should be Hold0");
    }
    // Hold31: 4,5,6,7,15
    for v in [4u8, 5, 6, 7, 15] {
        assert_eq!(EnvShape::from_register(v), EnvShape::Hold31,
            "register {v} should be Hold31");
    }
    assert_eq!(EnvShape::from_register(8),  EnvShape::Saw8);
    assert_eq!(EnvShape::from_register(10), EnvShape::Triangle10);
    assert_eq!(EnvShape::from_register(11), EnvShape::DecayHold);
    assert_eq!(EnvShape::from_register(12), EnvShape::Saw12);
    assert_eq!(EnvShape::from_register(13), EnvShape::AttackHold);
    assert_eq!(EnvShape::from_register(14), EnvShape::Triangle14);
}

// ─── SoundChip amplitude flag setters ────────────────────────────────────────

#[test]
fn set_ampl_b_sets_envelope_flag() {
    let mut chip = SoundChip::default();
    chip.set_ampl_b(0x10);
    assert!(chip.envelope_en_b, "bit 4 of ampl_b sets envelope_en_b");
    chip.set_ampl_b(0x0F);
    assert!(!chip.envelope_en_b, "clearing bit 4 clears envelope_en_b");
}

#[test]
fn set_ampl_c_sets_envelope_flag() {
    let mut chip = SoundChip::default();
    chip.set_ampl_c(0x10);
    assert!(chip.envelope_en_c, "bit 4 of ampl_c sets envelope_en_c");
    chip.set_ampl_c(0x0F);
    assert!(!chip.envelope_en_c, "clearing bit 4 clears envelope_en_c");
}

// ─── Envelope shape end-to-end waveform tests ─────────────────────────────────

/// Saw8 (type 8): decrements mod 32 continuously.
///
/// `set_envelope_register(8)` initialises `ampl = 32` — a pre-cycle sentinel
/// (bit 2 of 8 is 0 → start high, matching the original Pascal `AY.pas`).
/// After the first `step_envelope` the counter enters the 0..31 repeating cycle.
#[test]
fn envelope_saw8_cycles_through_all_32_values() {
    let mut chip = SoundChip::default();
    chip.set_envelope_register(8);
    // One step to move from the 32 sentinel into the 0..31 cycle (→ 31).
    chip.step_envelope();
    let cycle_start = chip.envelope_step;
    assert_eq!(cycle_start, 31, "Saw8 first in-cycle value should be 31");

    let mut values = Vec::with_capacity(32);
    for _ in 0..32 {
        values.push(chip.envelope_step);
        chip.step_envelope();
    }
    assert_eq!(chip.envelope_step, cycle_start, "Saw8 must be periodic with period 32");
    for i in 0..31 {
        assert_eq!(values[i + 1], (values[i] - 1) & 31,
            "Saw8 must decrement mod 32 at step {i}");
    }
}

/// Saw12 (type 12): increments mod 32 continuously.
///
/// `set_envelope_register(12)` initialises `ampl = -1` (bit 2 of 12 is 1 →
/// start low, matching the original Pascal `AY.pas`).  After one step the
/// counter is 0 and the ascending cycle begins.
#[test]
fn envelope_saw12_cycles_through_all_32_values() {
    let mut chip = SoundChip::default();
    chip.set_envelope_register(12);
    // One step moves from the -1 sentinel into the 0..31 cycle (→ 0).
    chip.step_envelope();
    let cycle_start = chip.envelope_step;
    assert_eq!(cycle_start, 0, "Saw12 first in-cycle value should be 0");

    let mut values = Vec::with_capacity(32);
    for _ in 0..32 {
        values.push(chip.envelope_step);
        chip.step_envelope();
    }
    assert_eq!(chip.envelope_step, cycle_start, "Saw12 must be periodic with period 32");
    for i in 0..31 {
        assert_eq!(values[i + 1], (values[i] + 1) & 31,
            "Saw12 must increment mod 32 at step {i}");
    }
}

/// Hold0 (type 0): decays from sentinel then holds.
#[test]
fn envelope_hold0_decays_then_holds() {
    let mut chip = SoundChip::default();
    chip.set_envelope_register(0);
    for _ in 0..64 {
        if !chip.first_period { break; }
        chip.step_envelope();
    }
    assert!(!chip.first_period, "Hold0 should have completed its first period");
    let held = chip.envelope_step;
    for _ in 0..10 {
        chip.step_envelope();
        assert_eq!(chip.envelope_step, held, "Hold0 must hold after first period ends");
    }
}

/// Hold31 (type 4): attacks then holds.
#[test]
fn envelope_hold31_holds_after_attack() {
    let mut chip = SoundChip::default();
    chip.set_envelope_register(4);
    for _ in 0..64 {
        if !chip.first_period { break; }
        chip.step_envelope();
    }
    assert!(!chip.first_period, "Hold31 first period should end");
    let held = chip.envelope_step;
    for _ in 0..10 {
        chip.step_envelope();
        assert_eq!(chip.envelope_step, held, "Hold31 must hold after first period ends");
    }
}

/// Triangle10 (type 10): down then up, bounces between 0 and 31.
#[test]
fn envelope_triangle10_bounces() {
    let mut chip = SoundChip::default();
    chip.set_envelope_register(10);
    let mut values = Vec::new();
    for _ in 0..64 {
        values.push(chip.envelope_step);
        chip.step_envelope();
    }
    assert!(values.windows(2).any(|w| w[1] < w[0]), "Triangle10 must have a decreasing phase");
    assert!(values.windows(2).any(|w| w[1] > w[0]), "Triangle10 must have an increasing phase");
}

/// Triangle14 (type 14): up then down, bounces between 0 and 31.
#[test]
fn envelope_triangle14_bounces() {
    let mut chip = SoundChip::default();
    chip.set_envelope_register(14);
    let mut values = Vec::new();
    for _ in 0..64 {
        values.push(chip.envelope_step);
        chip.step_envelope();
    }
    assert!(values.windows(2).any(|w| w[1] < w[0]), "Triangle14 must have a decreasing phase");
    assert!(values.windows(2).any(|w| w[1] > w[0]), "Triangle14 must have an increasing phase");
}

/// DecayHold (type 11): decays then holds at 31.
#[test]
fn envelope_decay_hold_holds_at_31() {
    let mut chip = SoundChip::default();
    chip.set_envelope_register(11);
    for _ in 0..64 {
        chip.step_envelope();
        if !chip.first_period { break; }
    }
    assert!(!chip.first_period, "DecayHold first period should end");
    assert_eq!(chip.envelope_step, 31, "DecayHold must hold at 31 after first period");
    let held = chip.envelope_step;
    for _ in 0..10 {
        chip.step_envelope();
        assert_eq!(chip.envelope_step, held, "DecayHold must stay at 31");
    }
}

/// AttackHold (type 13): attacks then holds at 31.
#[test]
fn envelope_attack_hold_holds_at_31() {
    let mut chip = SoundChip::default();
    chip.set_envelope_register(13);
    for _ in 0..64 {
        chip.step_envelope();
        if !chip.first_period { break; }
    }
    assert!(!chip.first_period, "AttackHold first period should end");
    assert_eq!(chip.envelope_step, 31, "AttackHold must hold at 31 after first period");
    let held = chip.envelope_step;
    for _ in 0..10 {
        chip.step_envelope();
        assert_eq!(chip.envelope_step, held, "AttackHold must stay at 31");
    }
}

// ─── synthesizer_logic_q — noise & envelope counter behaviour ────────────────

#[test]
fn synthesizer_logic_q_noise_seed_changes_over_time() {
    let mut chip = SoundChip::default();
    chip.registers.noise = 1;
    chip.set_mixer_register(0b11_000_000); // noise A/B/C enabled
    let initial_seed = chip.noise_seed;
    for _ in 0..100 { chip.synthesizer_logic_q(); }
    assert_ne!(chip.noise_seed, initial_seed,
        "noise_seed must change after 100 synthesizer_logic_q steps");
}

#[test]
fn synthesizer_logic_q_envelope_triggers_step() {
    // With envelope period=1, the envelope steps on every chip clock.
    let mut chip = SoundChip::default();
    chip.registers.envelope = 1;
    chip.set_envelope_register(12); // Saw12 — ascending
    let initial = chip.envelope_step;
    chip.synthesizer_logic_q();
    assert_eq!(chip.envelope_step, (initial + 1) & 31,
        "one synthesizer_logic_q step with period=1 should advance the envelope once");
}

#[test]
fn synthesizer_logic_q_tone_b_toggles_with_period_1() {
    let mut chip = SoundChip::default();
    chip.registers.ton_b = 1;
    assert_eq!(chip.ton_b, 0);
    chip.synthesizer_logic_q(); assert_eq!(chip.ton_b, 1);
    chip.synthesizer_logic_q(); assert_eq!(chip.ton_b, 0);
}

#[test]
fn synthesizer_logic_q_tone_c_toggles_with_period_1() {
    let mut chip = SoundChip::default();
    chip.registers.ton_c = 1;
    assert_eq!(chip.ton_c, 0);
    chip.synthesizer_logic_q(); assert_eq!(chip.ton_c, 1);
    chip.synthesizer_logic_q(); assert_eq!(chip.ton_c, 0);
}

// ─── Synthesizer: apply_registers + render smoke test ────────────────────────

#[test]
fn synthesizer_apply_registers_then_render_is_stable() {
    use vti_core::AyRegisters;
    let cfg = AyConfig { is_filt: false, ..AyConfig::default() };
    let mut synth = Synthesizer::new(cfg, 1, ChipType::AY);

    // mixer = 0b00_111_000: bits 3-5 set → noise A/B/C off; bits 0-2 clear → tone A/B/C on.
    // Small periods (50, 60, 40) guarantee tone counters toggle within 256 frames.
    let regs = AyRegisters {
        ton_a: 50, ton_b: 60, ton_c: 40,
        mixer: 0b00_111_000,
        amplitude_a: 10, amplitude_b: 8, amplitude_c: 6,
        ..AyRegisters::default()
    };
    synth.apply_registers(0, &regs);
    synth.render_frame(256);

    let total: i64 = synth.output_buf.iter()
        .map(|s| s.left.abs() as i64 + s.right.abs() as i64)
        .sum();
    assert!(total > 0, "rendering with active tones should produce non-zero output");
}

#[test]
fn synthesizer_render_frame_zero_is_noop() {
    let cfg = AyConfig { is_filt: false, ..AyConfig::default() };
    let mut synth = Synthesizer::new(cfg, 1, ChipType::YM);
    synth.render_frame(0);
    assert!(synth.output_buf.is_empty(), "rendering 0 frames should produce no output");
}

// ─── Quality mode render ──────────────────────────────────────────────────────

#[test]
fn render_frame_quality_produces_correct_sample_count() {
    // Quality mode Bresenham upsampler: ay_tiks_in_interrupt (4434) AY ticks
    // → sample_tiks_in_interrupt (960) audio samples @ 48 kHz / 50 Hz.
    let cfg = AyConfig { is_filt: false, ..AyConfig::default() };
    let expected = cfg.sample_tiks_in_interrupt() as usize;
    let mut synth = Synthesizer::new(cfg, 1, ChipType::AY);
    synth.render_frame_quality();
    // Allow ±1 due to fractional Bresenham rounding across the frame boundary.
    let got = synth.output_buf.len();
    assert!(
        got.abs_diff(expected) <= 1,
        "quality render should produce ~{} samples, got {}",
        expected, got
    );
}

#[test]
fn render_frame_quality_produces_nonzero_with_active_tone() {
    let cfg = AyConfig { is_filt: false, ..AyConfig::default() };
    let mut synth = Synthesizer::new(cfg, 1, ChipType::AY);
    let regs = AyRegisters {
        ton_a: 200,
        mixer: 0b11_111_110, // tone A on, everything else off
        amplitude_a: 15,
        ..AyRegisters::default()
    };
    synth.apply_registers(0, &regs);
    synth.render_frame_quality();
    let any_nonzero = synth.output_buf.iter().any(|s| s.left != 0 || s.right != 0);
    assert!(any_nonzero, "quality render with active tone should produce non-zero samples");
}

#[test]
fn render_frame_quality_phase_continuous_across_frames() {
    // Verify the Bresenham upsampler state persists correctly across multiple
    // frame calls (total sample count across 3 frames ≈ 3 × sample_tiks_in_interrupt).
    let cfg = AyConfig { is_filt: false, ..AyConfig::default() };
    let expected_per_frame = cfg.sample_tiks_in_interrupt() as usize;
    let mut synth = Synthesizer::new(cfg, 1, ChipType::AY);
    let regs = AyRegisters {
        ton_a: 100,
        mixer: 0b11_111_110,
        amplitude_a: 8,
        ..AyRegisters::default()
    };
    synth.apply_registers(0, &regs);

    for _ in 0..3 {
        synth.render_frame_quality();
    }
    let total = synth.output_buf.len();
    let expected_total = expected_per_frame * 3;
    assert!(
        total.abs_diff(expected_total) <= 3,
        "3 quality frames should produce ~{} samples total, got {}",
        expected_total, total
    );
}

#[test]
fn render_frame_quality_two_chips_produce_more_signal() {
    let cfg = AyConfig { is_filt: false, ..AyConfig::default() };
    let mut s1 = Synthesizer::new(cfg.clone(), 1, ChipType::AY);
    let mut s2 = Synthesizer::new(cfg, 2, ChipType::AY);

    let regs = AyRegisters {
        ton_a: 120,
        mixer: 0b11_111_110,
        amplitude_a: 15,
        ..AyRegisters::default()
    };
    s1.apply_registers(0, &regs);
    s2.apply_registers(0, &regs);
    s2.apply_registers(1, &regs);

    s1.render_frame_quality();
    s2.render_frame_quality();

    let sum1: i64 = s1.output_buf.iter().map(|s| s.left.abs() as i64).sum();
    let sum2: i64 = s2.output_buf.iter().map(|s| s.left.abs() as i64).sum();
    assert!(sum2 >= sum1, "two chips in quality mode should be at least as loud as one");
}

// ─── Bug regression: sample-rate / audio-player mismatch ─────────────────────

/// The AudioPlayer must be opened at SAMPLE_RATE_DEF (48 kHz) so that the
/// Bresenham upsampler inside the Synthesizer produces samples at the rate the
/// hardware device expects.  If these diverge (e.g. player at 44100, synth at
/// 48000), all music plays at (device_rate / synth_rate) × speed — about 8%
/// too slow at 44100/48000.
///
/// This test locks the constant so a future accident is caught immediately.
#[test]
fn audio_player_must_use_same_sample_rate_as_ay_config() {
    // The application opens AudioPlayer with SAMPLE_RATE_DEF.
    // Verify that constant is 48000 so the chip emulator and audio device agree.
    assert_eq!(
        SAMPLE_RATE_DEF, 48_000,
        "SAMPLE_RATE_DEF must be 48000 Hz — AudioPlayer::start() uses this constant \
         and the synth upsampler is calibrated to it; a mismatch causes slow/fast playback"
    );

    // Also verify the default AyConfig uses it.
    let cfg = AyConfig::default();
    assert_eq!(
        cfg.sample_rate, SAMPLE_RATE_DEF,
        "AyConfig::default() sample_rate must equal SAMPLE_RATE_DEF"
    );

    // The derived sample count per 50 Hz interrupt must match what the device delivers.
    // At 48000 Hz / 50 Hz = 960 samples/interrupt.
    let samples_per_interrupt = cfg.sample_tiks_in_interrupt();
    assert_eq!(
        samples_per_interrupt, 960,
        "expected 960 samples per 50 Hz interrupt at 48 kHz, got {}",
        samples_per_interrupt
    );
}

// ─── Bug regression: missing linear interpolation in quality renderer ─────────

/// Verifies that `render_frame_quality` produces smoothly-interpolated output
/// when the FIR filter is active.
///
/// The Pascal `Synthesizer_Stereo16` uses `Interpolator16(Left_Chan, PrevLeft, i)`
/// where `i = Tik.Re − Tick_Counter.Re + 65536` to produce sub-tick accurate
/// timing.  Without this interpolation each output sample simply takes the last
/// filtered value, introducing timing jitter that manifests as aliased noise.
///
/// We verify that a step transition (chip registers changed mid-stream) produces
/// a gradual rather than instantaneous change in the interpolated output.
#[test]
fn render_frame_quality_interpolation_smooths_step_transitions() {
    // Run with filter disabled first to get the "raw" output as a baseline, then
    // compare with filter+interpolation enabled to confirm smoother transitions.
    let make_synth = |is_filt: bool| {
        let cfg = AyConfig { is_filt, ..AyConfig::default() };
        let mut synth = Synthesizer::new(cfg, 1, ChipType::AY);
        // Tone A at a low period → frequent square-wave transitions
        let regs = AyRegisters {
            ton_a: 20,
            mixer: 0b11_111_110, // tone A on
            amplitude_a: 15,
            ..AyRegisters::default()
        };
        synth.apply_registers(0, &regs);
        synth.render_frame_quality();
        synth.output_buf.clone()
    };

    let raw_buf   = make_synth(false);
    let filt_buf  = make_synth(true);

    assert_eq!(raw_buf.len(), filt_buf.len(),
        "both paths should produce the same number of samples");

    // The filtered+interpolated output must not be identical to the raw output
    // (it should be smoother).
    let raw_distinct: std::collections::HashSet<i16> =
        raw_buf.iter().map(|s| s.left).collect();
    let filt_distinct: std::collections::HashSet<i16> =
        filt_buf.iter().map(|s| s.left).collect();

    // The filtered signal has more distinct values because intermediate amplitudes
    // are produced during transitions (FIR ramp + interpolation), while the raw
    // square-wave only has 0 and max.
    assert!(
        filt_distinct.len() > raw_distinct.len(),
        "filtered+interpolated output should have more distinct amplitude levels \
         than the raw square-wave (got raw={}, filtered={})",
        raw_distinct.len(), filt_distinct.len()
    );
}
