# STORY-045: Chip state (chip.rs) — ported from AY.pas

**Type:** chore

## Goal

Describe what this story should accomplish.

## Acceptance criteria

- [x] `ChipType` enum (None / AY / YM)
- [x] `EnvShape` enum (8 shapes)
- [x] `EnvShape::from_register()` mapping
- [x] `SoundChip` struct (all counter / flag fields)
- [x] `SoundChip::reset()`
- [x] `set_mixer_register()` — derive `ton_en_*` / `noise_en_*` flags
- [x] `set_envelope_register()` — set shape + initial amplitude
- [x] `set_ampl_a/b/c()` — set amplitude + envelope-mode flag
- [x] `step_envelope()` — all 8 envelope shape handlers
- [x] `noise_generator()` — 17-bit LFSR
- [x] `synthesizer_logic_q()` — tone/noise/envelope counters (quality mode)
- [x] `synthesizer_mixer_q()` — stereo level accumulation
- [x] `synthesizer_mixer_q_mono()` — mono mixing path
