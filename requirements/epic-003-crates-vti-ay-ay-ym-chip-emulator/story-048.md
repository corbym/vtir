# STORY-048: vti-ay Integration Tests (tests/integration_tests.rs)

**Type:** chore

## Goal

Describe what this story should accomplish.

## Acceptance criteria

- [x] `noise_generator` — LFSR changes, 17-bit constraint, diversity
- [x] `EnvShape::from_register` mapping
- [x] All 8 `step_envelope` shapes (Hold0, Hold31, Saw8, Triangle10, DecayHold, Saw12, AttackHold, Triangle14)
- [x] `set_mixer_register` bit mapping
- [x] `set_ampl_a` envelope flag
- [x] `chip.reset()` clears state
- [x] `synthesizer_logic_q` tone A toggles with period=1
- [x] Level tables for None/AY/YM chip types
- [x] Level table monotonicity for AY
- [x] Synthesizer renders correct sample count
- [x] Synthesizer drain respects max
- [x] Silent chip produces zero output
- [x] Active tone produces non-zero output
- [x] Two chips produce ≥ signal of one chip
- [x] `render_frame_quality` produces correct sample count (~960 ± 1)
- [x] `render_frame_quality` produces non-zero output with active tone
- [x] `render_frame_quality` phase is continuous across 3 consecutive frames
- [ ] Envelope shapes produce correct waveforms end-to-end
- [ ] `SetStdChannelsAllocation` panning preset values
