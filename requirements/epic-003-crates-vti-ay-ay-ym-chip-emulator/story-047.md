# STORY-047: Synthesizer (synth.rs) — ported from AY.pas

**Type:** chore

## Goal

Describe what this story should accomplish.

## Acceptance criteria

- [x] `LevelTables` struct
- [x] `calculate_level_tables()` — AY and YM amplitude → PCM level tables (fixed: `l` now uses `* 2` normalisation factor matching Pascal; single-step `trunc(… + 0.5)` formula replaces double-round)
- [x] `Synthesizer` struct (chips array, ring buffer, FIR state)
- [x] `Synthesizer::new()` — initialise with chip type
- [x] `Synthesizer::apply_registers()` — push AY register snapshot to chip
- [x] `Synthesizer::render_frame()` — produce N stereo-16 PCM samples (performance / test mode)
- [x] `Synthesizer::render_frame_quality()` — quality mode: runs AY chip at correct clock rate (`ay_tiks_in_interrupt` ≈ 4434 ticks / 50 Hz frame), Bresenham upsampler decimates to `sample_tiks_in_interrupt` ≈ 960 audio samples. FIR runs at AY rate. Fixes all-tones-2.2-octaves-too-low bug.
- [x] `Synthesizer::drain()` — pull samples from output buffer
- [x] FIR low-pass filter (windowed-sinc, Hanning window)
- [x] `calculate_level_tables()` global-volume scaling (`k = exp(vol*ln2/max) - 1`)
- [ ] `SetStdChannelsAllocation()` — channel panning presets (Mono/ABC/ACB/BAC…)
- [ ] `ToggleChanMode()` — cycle panning preset
- [ ] `SetIntFreq()` / `SetSampleRate()` — dynamic rate change
- [ ] Turbo Sound (2-chip) render path
