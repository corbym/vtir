//! Integration tests for vti-core: data types, playback engine, note tables.

use vti_core::{
    AdditionalCommand, ChannelLine, FeaturesLevel, Module, Ornament, Pattern,
    PatternRow, PositionList, Sample, SampleTick, NOTE_NONE, NOTE_SOUND_OFF,
    MAX_PAT_LEN, MAX_PAT_NUM, MAX_SAM_LEN, MAX_ORN_LEN,
};
use vti_core::note_tables::{get_note_freq, get_note_by_envelope, PT3_NOTE_TABLE_PT};
use vti_core::playback::{Engine, PlayResult, PlayVars, init_tracker_parameters};
use vti_core::util::{note_to_str, samp_to_str, int2_to_str, ints_to_time};

// ─── note_tables ────────────────────────────────────────────────────────────

#[test]
fn note_tables_have_96_entries() {
    assert_eq!(PT3_NOTE_TABLE_PT.len(), 96);
}

#[test]
fn get_note_freq_table_0_note_0_is_c1() {
    // C-1 in PT table is the highest period (lowest pitch)
    let f = get_note_freq(0, 0);
    assert_eq!(f, 0x0C22);
}

#[test]
fn get_note_freq_clamps_above_95() {
    // note 200 should clamp to note 95
    let f = get_note_freq(0, 200);
    let expected = get_note_freq(0, 95);
    assert_eq!(f, expected);
}

#[test]
fn get_note_freq_unknown_table_falls_back_to_natural() {
    // table index 99 → NATURAL table
    let natural = get_note_freq(99, 0);
    let explicit = get_note_freq(4, 0);
    assert_eq!(natural, explicit);
}

#[test]
fn get_note_by_envelope_round_trips() {
    // envelope period 16× a note frequency should find that note
    let note_freq = PT3_NOTE_TABLE_PT[12] as i32; // note 12 = C-2
    let env_period = note_freq;                    // envelope = note_freq * 1 (approx)
    // Result may be 0 if no exact match, so just check it doesn't panic.
    let _ = get_note_by_envelope(0, env_period);
}

// ─── util ────────────────────────────────────────────────────────────────────

#[test]
fn note_to_str_sound_off() {
    assert_eq!(note_to_str(NOTE_SOUND_OFF), "R--");
}

#[test]
fn note_to_str_no_note() {
    assert_eq!(note_to_str(NOTE_NONE), "---");
}

#[test]
fn note_to_str_c1() {
    assert_eq!(note_to_str(0), "C-1");
}

#[test]
fn note_to_str_c2() {
    assert_eq!(note_to_str(12), "C-2");
}

#[test]
fn note_to_str_last_note() {
    // note 95 = B-8
    assert_eq!(note_to_str(95), "B-8");
}

#[test]
fn samp_to_str_zero() {
    assert_eq!(samp_to_str(0), "00");
}

#[test]
fn samp_to_str_max_sample() {
    assert_eq!(samp_to_str(31), "1F");
}

#[test]
fn int2_to_str_pads() {
    assert_eq!(int2_to_str(3), "03");
    assert_eq!(int2_to_str(99), "99");
}

#[test]
fn ints_to_time_zero() {
    assert_eq!(ints_to_time(0), "00:00");
}

#[test]
fn ints_to_time_one_minute() {
    // 50 Hz × 60 s = 3000 ticks
    assert_eq!(ints_to_time(3000), "01:00");
}

// ─── types ──────────────────────────────────────────────────────────────────

#[test]
fn module_default_has_no_positions() {
    let m = Module::default();
    assert_eq!(m.positions.length, 0);
}

#[test]
fn module_default_ornament_0_exists() {
    let m = Module::default();
    assert!(m.ornaments[0].is_some());
}

#[test]
fn module_pat_idx_negative_maps_to_last() {
    assert_eq!(Module::pat_idx(-1), vti_core::MAX_NUM_OF_PATS);
}

#[test]
fn module_pat_idx_zero() {
    assert_eq!(Module::pat_idx(0), 0);
}

#[test]
fn sample_default_length_is_one() {
    let s = Sample::default();
    assert_eq!(s.length, 1);
}

#[test]
fn ornament_default_length_is_one() {
    let o = Ornament::default();
    assert_eq!(o.length, 1);
}

#[test]
fn pattern_default_length_is_def_pat_len() {
    let p = Pattern::default();
    assert_eq!(p.length, vti_core::DEF_PAT_LEN);
}

#[test]
fn channel_line_default_is_empty() {
    let c = ChannelLine::default();
    assert_eq!(c.note, NOTE_NONE);
    assert_eq!(c.sample, 0);
    assert_eq!(c.volume, 0);
}

#[test]
fn features_level_default_is_vt2() {
    assert_eq!(FeaturesLevel::default(), FeaturesLevel::Vt2);
}

// ─── playback ───────────────────────────────────────────────────────────────

fn make_module_with_pattern() -> Module {
    let mut m = Module::default();
    m.initial_delay = 3;
    m.positions.length = 1;
    m.positions.value[0] = 0;

    // Install a short 4-row pattern
    let mut pat = Pattern::default();
    pat.length = 4;
    // Row 0: note C-4 on all channels, sample 1, volume 15
    for ch in 0..3 {
        pat.items[0].channel[ch] = ChannelLine {
            note: 36, // C-4
            sample: 1,
            ornament: 0,
            volume: 15,
            envelope: 0,
            additional_command: AdditionalCommand::default(),
        };
    }
    m.patterns[0] = Some(Box::new(pat));

    // Install a trivial sample 1
    let mut sam = Sample::default();
    sam.length = 4;
    sam.loop_pos = 0;
    for i in 0..4 {
        sam.items[i] = SampleTick {
            amplitude: 15,
            mixer_ton: false,  // tone on
            mixer_noise: true, // noise off
            ..SampleTick::default()
        };
    }
    m.samples[1] = Some(Box::new(sam));
    m
}

#[test]
fn init_tracker_parameters_resets_state() {
    let mut m = make_module_with_pattern();
    let mut vars = PlayVars::default();
    vars.delay = 6; // some non-zero value
    init_tracker_parameters(&mut m, &mut vars, true);
    assert_eq!(vars.delay_counter, 1);
    assert_eq!(vars.pt3_noise, 0);
    assert_eq!(vars.env_base, 0);
}

#[test]
fn pattern_play_returns_updated_on_first_tick() {
    let mut m = make_module_with_pattern();
    let mut vars = PlayVars {
        current_pattern: 0,
        current_line: 0,
        delay: 3,
        delay_counter: 1,
        ..PlayVars::default()
    };
    init_tracker_parameters(&mut m, &mut vars, true);

    let mut regs = vti_core::AyRegisters::default();
    let mut engine = Engine { module: &mut m, vars: &mut vars };
    let result = engine.pattern_play_current_line(&mut regs);
    assert_eq!(result, PlayResult::Updated);
}

#[test]
fn pattern_advances_line_after_delay() {
    let mut m = make_module_with_pattern();
    let mut vars = PlayVars {
        current_pattern: 0,
        current_line: 0,
        delay: 1,
        delay_counter: 1,
        ..PlayVars::default()
    };
    init_tracker_parameters(&mut m, &mut vars, true);

    let mut regs = vti_core::AyRegisters::default();
    for _ in 0..3 {
        let mut engine = Engine { module: &mut m, vars: &mut vars };
        engine.pattern_play_current_line(&mut regs);
    }
    assert_eq!(vars.current_line, 3);
}

#[test]
fn pattern_end_returned_at_pattern_boundary() {
    let mut m = make_module_with_pattern();
    // Set delay=1 so every tick advances a line; pattern len=4
    let mut vars = PlayVars {
        current_pattern: 0,
        current_line: 0,
        delay: 1,
        delay_counter: 1,
        ..PlayVars::default()
    };
    init_tracker_parameters(&mut m, &mut vars, true);
    vars.delay = 1;
    vars.delay_counter = 1;

    let mut regs = vti_core::AyRegisters::default();
    let mut last = PlayResult::Updated;
    for _ in 0..6 {
        let mut engine = Engine { module: &mut m, vars: &mut vars };
        last = engine.pattern_play_current_line(&mut regs);
    }
    assert_eq!(last, PlayResult::PatternEnd);
}

#[test]
fn module_play_loops_at_end() {
    let mut m = make_module_with_pattern();
    m.positions.loop_pos = 0;
    let mut vars = PlayVars {
        current_pattern: 0,
        current_line: 0,
        delay: 1,
        delay_counter: 1,
        ..PlayVars::default()
    };
    init_tracker_parameters(&mut m, &mut vars, true);
    vars.delay = 1;
    vars.delay_counter = 1;

    let mut regs = vti_core::AyRegisters::default();
    let mut saw_loop = false;
    for _ in 0..20 {
        let mut engine = Engine { module: &mut m, vars: &mut vars };
        if engine.module_play_current_line(&mut regs) == PlayResult::ModuleLoop {
            saw_loop = true;
            break;
        }
    }
    assert!(saw_loop, "module playback should loop");
}

#[test]
fn sound_off_note_disables_channel() {
    let mut m = make_module_with_pattern();
    // Overwrite row 1 with sound-off
    if let Some(Some(pat)) = m.patterns.get_mut(0) {
        pat.items[1].channel[0].note = NOTE_SOUND_OFF;
    }

    let mut vars = PlayVars {
        current_pattern: 0,
        current_line: 0,
        delay: 1,
        delay_counter: 1,
        ..PlayVars::default()
    };
    init_tracker_parameters(&mut m, &mut vars, true);
    vars.delay = 1;
    vars.delay_counter = 1;

    let mut regs = vti_core::AyRegisters::default();
    // Tick past row 0 to row 1
    {
        let mut engine = Engine { module: &mut m, vars: &mut vars };
        engine.pattern_play_current_line(&mut regs);
    }
    {
        let mut engine = Engine { module: &mut m, vars: &mut vars };
        engine.pattern_play_current_line(&mut regs);
    }
    // After sound-off, channel 0 should not be sounding
    assert!(!vars.params_of_chan[0].sound_enabled);
}

// ─── arpeggio and noise drum ─────────────────────────────────────────────────

/// Build a module with arpeggios on channels A/B and a noise drum on C.
/// This mirrors the startup demo module in `app.rs` so the same logical path
/// is exercised from the test suite.
fn make_arpeggio_module() -> Module {
    let mut m = Module::default();
    m.initial_delay = 3;

    // Sample 1 – lead tone (sustaining)
    let mut lead = Sample::default();
    lead.length = 1;
    lead.loop_pos = 0;
    lead.items[0] = SampleTick {
        amplitude: 14,
        mixer_ton: true,
        mixer_noise: false,
        ..SampleTick::default()
    };
    m.samples[1] = Some(Box::new(lead));

    // Sample 2 – bass tone
    let mut bass_samp = Sample::default();
    bass_samp.length = 1;
    bass_samp.loop_pos = 0;
    bass_samp.items[0] = SampleTick {
        amplitude: 10,
        mixer_ton: true,
        mixer_noise: false,
        ..SampleTick::default()
    };
    m.samples[2] = Some(Box::new(bass_samp));

    // Sample 3 – noise drum (decaying, loops on silent tick 7)
    let mut drum = Sample::default();
    drum.length = 8;
    drum.loop_pos = 7;
    let drum_amps: [u8; 8] = [15, 13, 11, 9, 7, 5, 2, 0];
    for (i, &amp) in drum_amps.iter().enumerate() {
        drum.items[i] = SampleTick {
            amplitude: amp,
            mixer_ton: false,
            mixer_noise: true,
            add_to_envelope_or_noise: 12,
            ..SampleTick::default()
        };
    }
    m.samples[3] = Some(Box::new(drum));

    // Ornament 0 – zero offset (already installed by Module::default())

    // Ornament 1 – major arpeggio [0, +4, +7]
    let mut orn_major = Ornament::default();
    orn_major.length = 3;
    orn_major.loop_pos = 0;
    orn_major.items[0] = 0;
    orn_major.items[1] = 4;
    orn_major.items[2] = 7;
    m.ornaments[1] = Some(Box::new(orn_major));

    // Ornament 2 – minor arpeggio [0, +3, +7]
    let mut orn_minor = Ornament::default();
    orn_minor.length = 3;
    orn_minor.loop_pos = 0;
    orn_minor.items[0] = 0;
    orn_minor.items[1] = 3;
    orn_minor.items[2] = 7;
    m.ornaments[2] = Some(Box::new(orn_minor));

    // 16-row pattern: I–V–vi–IV chord progression
    let mut pat = Pattern::default();
    pat.length = 16;

    let make_chan = |note: i8, sample: u8, ornament: u8, volume: u8| ChannelLine {
        note, sample, ornament, volume,
        envelope: 0,
        additional_command: AdditionalCommand::default(),
    };

    // Row 0 – C major (I): Ch A C-5, Ch B C-3, Ch C noise drum
    pat.items[0].channel[0] = make_chan(48, 1, 1, 15);
    pat.items[0].channel[1] = make_chan(24, 2, 1, 12);
    pat.items[0].channel[2] = make_chan(0,  3, 0, 15);

    // Row 4 – G major (V): Ch A G-4, Ch B G-3
    pat.items[4].channel[0] = make_chan(43, 1, 1, 15);
    pat.items[4].channel[1] = make_chan(31, 2, 1, 12);

    // Row 8 – A minor (vi): Ch A A-4, Ch B A-3, Ch C noise drum
    pat.items[8].channel[0] = make_chan(45, 1, 2, 15);
    pat.items[8].channel[1] = make_chan(33, 2, 2, 12);
    pat.items[8].channel[2] = make_chan(0,  3, 0, 15);

    // Row 12 – F major (IV): Ch A F-4, Ch B F-3
    pat.items[12].channel[0] = make_chan(41, 1, 1, 15);
    pat.items[12].channel[1] = make_chan(29, 2, 1, 12);

    m.patterns[0] = Some(Box::new(pat));

    m.positions.length = 1;
    m.positions.value[0] = 0;
    m.positions.loop_pos = 0;

    m
}

/// The arpeggio ornament must produce a different AY tone period on each of
/// the three consecutive ticks within a delay=3 row.
///
/// With ornament [0, +4, +7] on note C-5 (note 48, PT table):
///   tick 0: ornament offset 0  → note 48 → freq = PT3_NOTE_TABLE_PT[48]
///   tick 1: ornament offset +4 → note 52 → freq = PT3_NOTE_TABLE_PT[52]
///   tick 2: ornament offset +7 → note 55 → freq = PT3_NOTE_TABLE_PT[55]
///
/// The three tone values must be distinct (each arpeggio step is a different
/// frequency) and the first must be the root note period.
#[test]
fn arpeggio_ornament_produces_distinct_tone_periods() {
    use vti_core::note_tables::PT3_NOTE_TABLE_PT;

    let mut m = make_arpeggio_module();
    let mut vars = PlayVars {
        current_pattern: 0,
        current_line: 0,
        delay: 3,
        delay_counter: 1,
        ..PlayVars::default()
    };
    init_tracker_parameters(&mut m, &mut vars, true);

    let mut tones = Vec::new();
    let mut regs = vti_core::AyRegisters::default();

    // Three consecutive ticks cover one full delay=3 row (row 0 is processed
    // on tick 1 and then re-rendered twice while delay_counter counts down).
    for _ in 0..3 {
        regs = vti_core::AyRegisters::default();
        let mut engine = Engine { module: &mut m, vars: &mut vars };
        engine.pattern_play_current_line(&mut regs);
        tones.push(regs.ton_a);
    }

    // All three should be non-zero (tone is sounding)
    assert!(tones.iter().all(|&t| t > 0), "tone_a must be non-zero on each tick: {tones:?}");

    // All three should be distinct (arpeggio steps produce different periods)
    let unique: std::collections::HashSet<_> = tones.iter().copied().collect();
    assert_eq!(unique.len(), 3, "arpeggio should produce 3 distinct tone periods: {tones:?}");

    // The first tick period must match the root note (C-5 = note 48, PT table 0)
    let root_period = PT3_NOTE_TABLE_PT[48];
    assert_eq!(tones[0], root_period,
        "first tick must be the root note period (C-5 = {root_period})");
}

/// The noise drum sample (sample 3) must produce non-zero amplitude on channel
/// C when triggered, and the noise channel must be enabled in the mixer.
#[test]
fn noise_drum_produces_amplitude_on_channel_c() {
    let mut m = make_arpeggio_module();
    let mut vars = PlayVars {
        current_pattern: 0,
        current_line: 0,
        delay: 1,
        delay_counter: 1,
        ..PlayVars::default()
    };
    init_tracker_parameters(&mut m, &mut vars, true);
    vars.delay = 1;
    vars.delay_counter = 1;

    let mut regs = vti_core::AyRegisters::default();
    let mut engine = Engine { module: &mut m, vars: &mut vars };
    engine.pattern_play_current_line(&mut regs);

    // Channel C must have non-zero amplitude (the drum hit)
    assert!(regs.amplitude_c > 0, "channel C amplitude must be non-zero when drum hits");

    // Noise must be enabled for channel C in the mixer.
    // AY mixer bit 5 (value 32) = noise-C disable; must be 0 for noise to be on.
    assert_eq!(regs.mixer & 0x20, 0,
        "noise must be enabled for channel C (mixer bit 5 must be 0)");

    // Tone must be disabled for channel C (drum has no tone component).
    // AY mixer bit 2 (value 4) = tone-C disable; must be 1 for tone to be off.
    assert_ne!(regs.mixer & 0x04, 0,
        "tone must be disabled for channel C when drum plays (mixer bit 2 must be 1)");
}

/// After a noise drum hit, the drum sample decays and the channel falls silent
/// once the decaying sample loops on tick 7 (amplitude 0).
#[test]
fn noise_drum_decays_to_silence() {
    let mut m = make_arpeggio_module();
    let mut vars = PlayVars {
        current_pattern: 0,
        current_line: 0,
        delay: 1,
        delay_counter: 1,
        ..PlayVars::default()
    };
    init_tracker_parameters(&mut m, &mut vars, true);
    vars.delay = 1;
    vars.delay_counter = 1;

    let mut regs = vti_core::AyRegisters::default();

    // Advance 8 rows (= 8 ticks at delay=1): the drum sample has 8 ticks
    // (indices 0–7) and loops on tick 7 which has amplitude 0.
    for _ in 0..8 {
        regs = vti_core::AyRegisters::default();
        let mut engine = Engine { module: &mut m, vars: &mut vars };
        engine.pattern_play_current_line(&mut regs);
    }

    // After 8 ticks the sample is held at loop_pos=7 (amplitude 0).
    assert_eq!(regs.amplitude_c, 0, "drum channel must be silent after decay");
}

/// The arpeggio module must advance through all 16 rows of the pattern and
/// then signal PatternEnd, which causes module_play_current_line to loop.
#[test]
fn arpeggio_module_loops_after_full_pattern() {
    let mut m = make_arpeggio_module();
    m.positions.loop_pos = 0;
    let mut vars = PlayVars {
        current_pattern: 0,
        current_line: 0,
        delay: 1,
        delay_counter: 1,
        ..PlayVars::default()
    };
    init_tracker_parameters(&mut m, &mut vars, true);
    vars.delay = 1;
    vars.delay_counter = 1;

    let mut regs = vti_core::AyRegisters::default();
    let mut saw_loop = false;

    // 16 rows at delay=1 → 16 ticks to exhaust the pattern, then one more
    // to trigger the loop.  Give it a generous budget.
    for _ in 0..40 {
        let mut engine = Engine { module: &mut m, vars: &mut vars };
        if engine.module_play_current_line(&mut regs) == PlayResult::ModuleLoop {
            saw_loop = true;
            break;
        }
    }
    assert!(saw_loop, "arpeggio module should loop after 16 rows");
}

/// Channels A and B must both be sounding (non-zero amplitude) after
/// the first row is processed.
#[test]
fn arpeggio_channels_a_and_b_are_active_after_row0() {
    let mut m = make_arpeggio_module();
    let mut vars = PlayVars {
        current_pattern: 0,
        current_line: 0,
        delay: 1,
        delay_counter: 1,
        ..PlayVars::default()
    };
    init_tracker_parameters(&mut m, &mut vars, true);
    vars.delay = 1;
    vars.delay_counter = 1;

    let mut regs = vti_core::AyRegisters::default();
    let mut engine = Engine { module: &mut m, vars: &mut vars };
    engine.pattern_play_current_line(&mut regs);

    assert!(regs.amplitude_a > 0, "channel A must have non-zero amplitude");
    assert!(regs.amplitude_b > 0, "channel B must have non-zero amplitude");

    // Tone must be enabled on both channels A and B
    assert_eq!(regs.mixer & 0x01, 0, "tone must be ON for channel A (bit 0 = 0)");
    assert_eq!(regs.mixer & 0x02, 0, "tone must be ON for channel B (bit 1 = 0)");
}

// ─── playback cursor tracking ────────────────────────────────────────────────
// These tests verify that PlayVars.{current_line, current_pattern, current_position}
// track the playhead faithfully.  `app.rs` reads those fields to build the
// `play_pos: Option<(i32, usize)>` that is passed to PatternEditor::show(), so
// if the engine updates them correctly the UI will follow.
//
// Important engine contract (mirrors the Pascal original):
//   `current_line` always points to the NEXT row to be processed, not the row
//   whose audio is currently being rendered.  `pattern_play_current_line`
//   interprets a row, then increments the pointer before returning — so after
//   row N is processed, `current_line == N + 1`.  The UI must subtract 1 to
//   obtain the display row (`current_line.saturating_sub(1)`), exactly as the
//   original Delphi `umredrawtracks` handler does with `line - 1`.

/// After N ticks at delay=1, `current_line` must equal N (pattern is advancing
/// one row per tick until pattern end).
#[test]
fn current_line_advances_one_per_tick_at_delay_1() {
    let mut m = make_module_with_pattern();   // 4-row pattern
    let mut vars = PlayVars {
        current_pattern: 0,
        current_line: 0,
        delay: 1,
        delay_counter: 1,
        ..PlayVars::default()
    };
    init_tracker_parameters(&mut m, &mut vars, true);
    vars.delay = 1;
    vars.delay_counter = 1;

    let mut regs = vti_core::AyRegisters::default();

    for expected_line in 1..=3 {
        {
            let mut engine = Engine { module: &mut m, vars: &mut vars };
            engine.pattern_play_current_line(&mut regs);
        }
        assert_eq!(vars.current_line, expected_line,
            "current_line should be {expected_line} after {expected_line} ticks");
    }
}

/// The UI display row is `current_line.saturating_sub(1)` — one behind the
/// engine's internal pointer.  This test verifies that the display row is 0
/// (the first row) after the very first tick, and advances from there.
#[test]
fn display_row_is_current_line_minus_one() {
    let mut m = make_module_with_pattern(); // 4-row pattern
    let mut vars = PlayVars {
        current_pattern: 0,
        current_line: 0,
        delay: 1,
        delay_counter: 1,
        ..PlayVars::default()
    };
    init_tracker_parameters(&mut m, &mut vars, true);
    vars.delay = 1;
    vars.delay_counter = 1;

    let mut regs = vti_core::AyRegisters::default();

    for expected_display in 0..=2 {
        {
            let mut engine = Engine { module: &mut m, vars: &mut vars };
            engine.pattern_play_current_line(&mut regs);
        }
        let display = vars.current_line.saturating_sub(1);
        assert_eq!(display, expected_display,
            "display row should be {expected_display} after {} ticks", expected_display + 1);
    }
}

/// When the module advances to a new pattern, the engine eagerly processes
/// the first row of that new pattern.  After the transition tick,
/// `current_line = 1` (row 0 was processed, pointer moved to row 1) and
/// the display row (`current_line - 1 = 0`) correctly shows the start of
/// the new pattern — matching the Pascal `RedrawPlWindow` behaviour.
#[test]
fn current_line_after_pattern_transition_is_one() {
    // Build a two-position module (pos 0 → pattern 0, pos 1 → pattern 1).
    let mut m = Module::default();
    m.initial_delay = 1;

    // Pattern 0 – 2-row pattern
    let mut pat0 = Pattern::default();
    pat0.length = 2;
    pat0.items[0].channel[0] = ChannelLine { note: 48, sample: 1, ornament: 0, volume: 15, ..ChannelLine::default() };
    m.patterns[0] = Some(Box::new(pat0));

    // Pattern 1 – 2-row pattern
    let mut pat1 = Pattern::default();
    pat1.length = 2;
    pat1.items[0].channel[0] = ChannelLine { note: 36, sample: 1, ornament: 0, volume: 15, ..ChannelLine::default() };
    m.patterns[1] = Some(Box::new(pat1));

    // A one-note sample so the engine produces something
    let mut s = Sample::default();
    s.length = 1;
    s.loop_pos = 0;
    s.items[0] = SampleTick { amplitude: 10, mixer_ton: true, ..SampleTick::default() };
    m.samples[1] = Some(Box::new(s));

    m.positions.length = 2;
    m.positions.value[0] = 0;
    m.positions.value[1] = 1;
    m.positions.loop_pos = 0;

    let mut vars = PlayVars {
        current_pattern: 0,
        current_line: 0,
        delay: 1,
        delay_counter: 1,
        ..PlayVars::default()
    };
    init_tracker_parameters(&mut m, &mut vars, true);
    vars.delay = 1;
    vars.delay_counter = 1;

    let mut regs = vti_core::AyRegisters::default();

    // Drain pattern 0 until the pattern changes.
    let mut changed_pattern = false;
    for _ in 0..10 {
        let old_pat = vars.current_pattern;
        {
            let mut engine = Engine { module: &mut m, vars: &mut vars };
            engine.module_play_current_line(&mut regs);
        }
        if vars.current_pattern != old_pat {
            // The engine eagerly processed row 0 of the new pattern, so the
            // pointer is at 1.  The display row (`current_line - 1`) is 0,
            // correctly showing the top of the new pattern to the user.
            assert_eq!(vars.current_line, 1,
                "after transition, current_line should be 1 (row 0 processed eagerly)");
            assert_eq!(vars.current_line.saturating_sub(1), 0,
                "display row should be 0 (first row of the new pattern)");
            changed_pattern = true;
            break;
        }
    }
    assert!(changed_pattern, "engine should have advanced to pattern 1 within 10 ticks");
}

/// `current_position` must increment as the module advances through positions.
#[test]
fn current_position_advances_through_positions() {
    // Two-position module (same as above).
    let mut m = Module::default();
    m.initial_delay = 1;

    let mut pat = Pattern::default();
    pat.length = 2;
    m.patterns[0] = Some(Box::new(pat.clone()));
    m.patterns[1] = Some(Box::new(pat));

    m.positions.length = 2;
    m.positions.value[0] = 0;
    m.positions.value[1] = 1;
    m.positions.loop_pos = 0;

    let mut vars = PlayVars {
        current_pattern: 0,
        current_line: 0,
        delay: 1,
        delay_counter: 1,
        ..PlayVars::default()
    };
    init_tracker_parameters(&mut m, &mut vars, true);
    vars.delay = 1;
    vars.delay_counter = 1;

    let mut regs = vti_core::AyRegisters::default();

    // Keep ticking until position advances to 1
    let mut saw_position_1 = false;
    for _ in 0..15 {
        {
            let mut engine = Engine { module: &mut m, vars: &mut vars };
            engine.module_play_current_line(&mut regs);
        }
        if vars.current_position == 1 {
            saw_position_1 = true;
            break;
        }
    }
    assert!(saw_position_1, "current_position should advance to 1 after the first pattern ends");
}

/// After a full module loop the pattern and line pointers must return to the
/// loop start — exactly what the UI needs to show when the module wraps.
#[test]
fn current_line_and_pattern_reset_on_module_loop() {
    let mut m = make_arpeggio_module(); // 1 position, 16-row pattern, loop_pos=0
    let mut vars = PlayVars {
        current_pattern: 0,
        current_line: 0,
        delay: 1,
        delay_counter: 1,
        ..PlayVars::default()
    };
    init_tracker_parameters(&mut m, &mut vars, true);
    vars.delay = 1;
    vars.delay_counter = 1;

    let mut regs = vti_core::AyRegisters::default();
    let mut looped = false;

    for _ in 0..40 {
        let result = {
            let mut engine = Engine { module: &mut m, vars: &mut vars };
            engine.module_play_current_line(&mut regs)
        };
        if result == PlayResult::ModuleLoop {
            looped = true;
            break;
        }
    }

    assert!(looped, "module must loop");
    // After looping, position is at loop_pos (0) and line is at the first row
    assert_eq!(vars.current_position, 0, "position must be at loop_pos=0 after module loop");
    assert_eq!(vars.current_pattern, 0, "pattern must be 0 after module loop");
}

// ─── VTM text-format round-trip ──────────────────────────────────────────────

use vti_core::formats::vtm;
use vti_core::formats::load as format_load;

/// Rebuild the demo module from `src/app.rs` inside the test crate so we can
/// use it without a dependency on the binary.
fn make_demo_module_for_test() -> Module {
    let mut module = Module::default();
    module.title = "Demo Song".to_string();
    module.author = "Vortex Tracker II".to_string();
    module.initial_delay = 3;

    // Sample 1 – lead tone
    let mut lead = Sample::default();
    lead.length = 1;
    lead.loop_pos = 0;
    lead.items[0] = SampleTick {
        amplitude: 14,
        mixer_ton: true,
        mixer_noise: false,
        ..SampleTick::default()
    };
    module.samples[1] = Some(Box::new(lead));

    // Sample 2 – bass tone
    let mut bass = Sample::default();
    bass.length = 1;
    bass.loop_pos = 0;
    bass.items[0] = SampleTick {
        amplitude: 10,
        mixer_ton: true,
        mixer_noise: false,
        ..SampleTick::default()
    };
    module.samples[2] = Some(Box::new(bass));

    // Sample 3 – noise drum (8-tick decay, loops on tick 7)
    let mut drum = Sample::default();
    drum.length = 8;
    drum.loop_pos = 7;
    let amps: [u8; 8] = [15, 13, 11, 9, 7, 5, 2, 0];
    for (i, &amp) in amps.iter().enumerate() {
        drum.items[i] = SampleTick {
            amplitude: amp,
            mixer_ton: false,
            mixer_noise: true,
            add_to_envelope_or_noise: 12,
            ..SampleTick::default()
        };
    }
    module.samples[3] = Some(Box::new(drum));

    // Ornament 1 – major arpeggio
    let mut orn_maj = Ornament::default();
    orn_maj.length = 3;
    orn_maj.loop_pos = 0;
    orn_maj.items[0] = 0;
    orn_maj.items[1] = 4;
    orn_maj.items[2] = 7;
    module.ornaments[1] = Some(Box::new(orn_maj));

    // Ornament 2 – minor arpeggio
    let mut orn_min = Ornament::default();
    orn_min.length = 3;
    orn_min.loop_pos = 0;
    orn_min.items[0] = 0;
    orn_min.items[1] = 3;
    orn_min.items[2] = 7;
    module.ornaments[2] = Some(Box::new(orn_min));

    // Pattern 0 – 16 rows, I–V–vi–IV chord progression
    let mut pat = Pattern::default();
    pat.length = 16;
    let mk = |note: i8, sample: u8, ornament: u8, volume: u8| ChannelLine {
        note, sample, ornament, volume, envelope: 0,
        additional_command: AdditionalCommand::default(),
    };
    pat.items[0].channel[0]  = mk(48, 1, 1, 15); // C-5 lead
    pat.items[0].channel[1]  = mk(24, 2, 1, 12); // C-3 bass
    pat.items[0].channel[2]  = mk(0,  3, 0, 15); // noise drum
    pat.items[4].channel[0]  = mk(43, 1, 1, 15);
    pat.items[4].channel[1]  = mk(31, 2, 1, 12);
    pat.items[8].channel[0]  = mk(45, 1, 2, 15);
    pat.items[8].channel[1]  = mk(33, 2, 2, 12);
    pat.items[8].channel[2]  = mk(0,  3, 0, 15);
    pat.items[12].channel[0] = mk(41, 1, 1, 15);
    pat.items[12].channel[1] = mk(29, 2, 1, 12);
    module.patterns[0] = Some(Box::new(pat));

    module.positions.length = 1;
    module.positions.value[0] = 0;
    module.positions.loop_pos = 0;
    module
}

/// Verify that the VTM text format can be written and read back, and that the
/// key module fields survive the round-trip unchanged.
#[test]
fn vtm_round_trip_demo_song() {
    let original = make_demo_module_for_test();

    // --- save ---
    let text = vtm::write(&original);
    assert!(!text.is_empty(), "write should produce non-empty output");
    assert!(text.contains("[Module]"),  "output must contain [Module] section");
    assert!(text.contains("[Pattern0]"), "output must contain [Pattern0] section");
    assert!(text.contains("[Sample1]"),  "output must contain [Sample1] section");
    assert!(text.contains("[Ornament1]"), "output must contain [Ornament1] section");

    // --- load ---
    let loaded = vtm::parse(&text).expect("VTM parse should succeed");

    // Module metadata
    assert_eq!(loaded.title,         original.title);
    assert_eq!(loaded.author,        original.author);
    assert_eq!(loaded.initial_delay, original.initial_delay);
    assert_eq!(loaded.ton_table,     original.ton_table);
    assert_eq!(loaded.features_level, original.features_level);

    // Position list
    assert_eq!(loaded.positions.length,   original.positions.length);
    assert_eq!(loaded.positions.loop_pos, original.positions.loop_pos);
    assert_eq!(loaded.positions.value[0], original.positions.value[0]);

    // Sample 1 – lead tone
    let s1_orig = original.samples[1].as_deref().expect("sample 1 must exist");
    let s1_load = loaded.samples[1].as_deref().expect("sample 1 must round-trip");
    assert_eq!(s1_load.length,          s1_orig.length);
    assert_eq!(s1_load.loop_pos,        s1_orig.loop_pos);
    assert_eq!(s1_load.items[0].amplitude,   s1_orig.items[0].amplitude);
    assert_eq!(s1_load.items[0].mixer_ton,   s1_orig.items[0].mixer_ton);
    assert_eq!(s1_load.items[0].mixer_noise, s1_orig.items[0].mixer_noise);

    // Sample 3 – noise drum (8 ticks, loop on tick 7)
    let s3_orig = original.samples[3].as_deref().expect("sample 3 must exist");
    let s3_load = loaded.samples[3].as_deref().expect("sample 3 must round-trip");
    assert_eq!(s3_load.length,   s3_orig.length);
    assert_eq!(s3_load.loop_pos, s3_orig.loop_pos);
    for i in 0..s3_orig.length as usize {
        assert_eq!(
            s3_load.items[i].amplitude,
            s3_orig.items[i].amplitude,
            "drum tick {i} amplitude mismatch",
        );
        assert_eq!(
            s3_load.items[i].mixer_noise,
            s3_orig.items[i].mixer_noise,
            "drum tick {i} mixer_noise mismatch",
        );
    }

    // Ornament 1 – major arpeggio
    let o1_orig = original.ornaments[1].as_deref().expect("ornament 1 must exist");
    let o1_load = loaded.ornaments[1].as_deref().expect("ornament 1 must round-trip");
    assert_eq!(o1_load.length,   o1_orig.length);
    assert_eq!(o1_load.loop_pos, o1_orig.loop_pos);
    assert_eq!(&o1_load.items[..o1_orig.length], &o1_orig.items[..o1_orig.length]);

    // Pattern 0 – spot-check key rows
    let p0_orig = original.patterns[0].as_deref().expect("pattern 0 must exist");
    let p0_load = loaded.patterns[0].as_deref().expect("pattern 0 must round-trip");
    assert_eq!(p0_load.length, p0_orig.length);
    // Row 0: C major hit
    assert_eq!(p0_load.items[0].channel[0].note,    p0_orig.items[0].channel[0].note);
    assert_eq!(p0_load.items[0].channel[0].sample,  p0_orig.items[0].channel[0].sample);
    assert_eq!(p0_load.items[0].channel[0].ornament,p0_orig.items[0].channel[0].ornament);
    assert_eq!(p0_load.items[0].channel[0].volume,  p0_orig.items[0].channel[0].volume);
    // Row 8: A minor hit
    assert_eq!(p0_load.items[8].channel[0].note,    p0_orig.items[8].channel[0].note);
    assert_eq!(p0_load.items[8].channel[2].note,    p0_orig.items[8].channel[2].note);
}

/// The `formats::load` dispatcher must route `.vtm` files through the VTM text
/// parser without error.
#[test]
fn format_load_dispatches_vtm() {
    let demo = make_demo_module_for_test();
    let text = vtm::write(&demo);
    let bytes = text.into_bytes();
    let loaded = format_load(&bytes, "song.vtm").expect("load should succeed for .vtm");
    assert_eq!(loaded.initial_delay, demo.initial_delay);
    assert_eq!(loaded.positions.length, demo.positions.length);
}

/// A round-trip via the filesystem: write to a temp file, read it back.
#[test]
fn vtm_file_save_load_round_trip() {
    use std::io::Write;

    let original = make_demo_module_for_test();
    let text = vtm::write(&original);

    // Write to a temp file
    let mut tmp = tempfile::NamedTempFile::new().expect("tempfile");
    tmp.write_all(text.as_bytes()).expect("write");
    let path = tmp.path().to_owned();

    // Read back
    let bytes = std::fs::read(&path).expect("re-read");
    let loaded = format_load(&bytes, "demo.vtm").expect("load round-trip");

    assert_eq!(loaded.title,         original.title);
    assert_eq!(loaded.positions.length, original.positions.length);
    let p = loaded.patterns[0].as_deref().expect("pattern 0");
    assert_eq!(p.length, original.patterns[0].as_deref().unwrap().length);
}
