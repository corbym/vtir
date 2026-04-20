# STORY-044: vti-core Integration Tests (tests/integration_tests.rs)

**Type:** chore

## Goal

Describe what this story should accomplish.

## Acceptance criteria

- [x] Note table size and value checks
- [x] `get_note_freq` clamping and fallback
- [x] All `util` formatting functions
- [x] `Module` / `Sample` / `Ornament` / `Pattern` / `ChannelLine` default values
- [x] `init_tracker_parameters` reset behaviour
- [x] `pattern_play_current_line` → `Updated` on first tick
- [x] Line advancement after delay cycles
- [x] Pattern-end detection
- [x] Module loop detection
- [x] Sound-off note disables channel
- [x] Arpeggio ornament produces 3 distinct tone periods per row
- [x] Noise drum sample produces non-zero amplitude on channel C with noise enabled in mixer
- [x] Noise drum decays to silence after 8 ticks (loop on silent tick)
- [x] Arpeggio module loops after full 16-row pattern
- [x] Channels A and B both active (non-zero amplitude, tone enabled) after first row
- [x] `ADDAMS2.ay` fixture loads via `formats::load` and survives one playback tick smoke-test
- [x] PT3 binary round-trip (parse → write → parse)
- [ ] Glide-up / glide-down effect commands
- [ ] Tone-slide (command 3) target arrival
- [ ] On/off toggle (command 6)
- [ ] Envelope-slide (commands 9 and 10)
- [ ] Sample position jump (command 4)
- [ ] Ornament position jump (command 5)
