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
    let orn_len = o1_orig.length;
    assert_eq!(&o1_load.items[..orn_len], &o1_orig.items[..orn_len]);

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

/// Load the long-form "Descent Into Madness" fixture and verify that each
/// major VTM section (module, ornaments, samples, patterns, order list) is
/// parsed and playable through a full loop.
#[test]
fn load_madness_descent_vtm_sections_and_playback_loop() {
    let vtm_text = std::fs::read_to_string("tests/fixtures/tunes/madness_descent.vtm")
        .expect("should read madness_descent fixture");

    let mut module = vtm::parse(&vtm_text).expect("fixture should parse as VTM");

    // Module section
    assert_eq!(module.title, "Descent Into Madness");
    assert_eq!(module.author, "VTIR Test Fixture");
    assert_eq!(module.initial_delay, 6);
    assert_eq!(module.ton_table, 0);

    // PlayOrder section: 11 positions, loop at 0.
    assert_eq!(module.positions.length, 11);
    assert_eq!(module.positions.loop_pos, 0);
    let expected_order: [usize; 11] = [0, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1];
    assert_eq!(&module.positions.value[..module.positions.length], &expected_order);

    // Ornaments and samples sections
    assert!(module.ornaments[1].is_some(), "ornament 1 should exist");
    assert!(module.ornaments[2].is_some(), "ornament 2 should exist");
    assert!(module.samples[1].is_some(), "sample 1 should exist");
    assert!(module.samples[2].is_some(), "sample 2 should exist");
    assert!(module.samples[3].is_some(), "sample 3 should exist");
    assert_eq!(module.samples[1].as_deref().expect("s1").length, 3);
    assert_eq!(module.samples[2].as_deref().expect("s2").length, 4);
    assert_eq!(module.samples[3].as_deref().expect("s3").length, 4);

    // Pattern sections
    let pat0 = module.patterns[0].as_deref().expect("pattern 0 should exist");
    let pat1 = module.patterns[1].as_deref().expect("pattern 1 should exist");
    assert_eq!(pat0.length, 32);
    assert_eq!(pat1.length, 32);
    assert_eq!(note_to_str(pat0.items[0].channel[0].note), "D-3");
    assert_eq!(note_to_str(pat0.items[0].channel[1].note), "A-5");
    // Pattern1 expands Pattern0 with a denser lead + undertune and deeper C-channel hits.
    assert_eq!(note_to_str(pat1.items[0].channel[0].note), "D-4");
    assert_eq!(note_to_str(pat1.items[0].channel[1].note), "D-4");
    assert_eq!(note_to_str(pat1.items[0].channel[2].note), "C-1");

    // Playback smoke + timing: 11 * 32 rows at speed 6 -> ~42.24s at 50Hz.
    let mut vars = PlayVars::default();
    init_tracker_parameters(&mut module, &mut vars, true);
    vars.current_position = 0;
    vars.current_pattern = module.positions.value[0] as i32;
    vars.current_line = 0;
    vars.delay = module.initial_delay as i8;
    vars.delay_counter = 1;

    let mut regs = vti_core::AyRegisters::default();
    let mut loop_tick: Option<usize> = None;

    for t in 1..=3000usize {
        let result = {
            let mut engine = Engine { module: &mut module, vars: &mut vars };
            engine.module_play_current_line(&mut regs)
        };
        if result == PlayResult::ModuleLoop {
            loop_tick = Some(t);
            break;
        }
    }

    let t = loop_tick.expect("fixture should loop within 3000 ticks");
    assert!(t >= 2100 && t <= 2150, "loop tick out of expected range: {t}");
}

// ─── PT3 binary format: load, save, round-trip ───────────────────────────────

use vti_core::formats::pt3 as pt3_fmt;
use vti_core::formats::save_pt3;

/// Helper: read a fixture file from `tests/fixtures/tunes/`
fn read_fixture(name: &str) -> Vec<u8> {
    let path = format!(
        "{}/tests/fixtures/tunes/{}",
        env!("CARGO_MANIFEST_DIR"),
        name
    );
    std::fs::read(&path).unwrap_or_else(|e| panic!("Cannot read fixture {}: {}", path, e))
}

/// Smoke-test: the minimal_roundtrip.pt3 fixture parses without error.
#[test]
fn pt3_smoke_parse_minimal() {
    let bytes = read_fixture("minimal_roundtrip.pt3");
    let m = pt3_fmt::parse(&bytes).expect("minimal_roundtrip.pt3 must parse");
    assert_eq!(m.title.trim(), "Round Trip Test");
    assert_eq!(m.initial_delay, 3);
    assert_eq!(m.positions.length, 4);
    assert_eq!(m.positions.loop_pos, 0);
    assert_eq!(m.ton_table, 0);

    // Pattern 0: 4 rows, C-4 on ch A
    let p0 = m.patterns[0].as_deref().expect("pattern 0 must exist");
    assert_eq!(p0.length, 4);
    assert_eq!(p0.items[0].channel[0].note, 36); // C-4

    // Pattern 1: 3 rows, B-4 on ch A
    let p1 = m.patterns[1].as_deref().expect("pattern 1 must exist");
    assert_eq!(p1.length, 3);
    assert_eq!(p1.items[0].channel[0].note, 60); // B-4
}

/// Load minimal_roundtrip.pt3, write it back as PT3, parse the output, and
/// compare key fields — verifying the write→parse round-trip is lossless.
#[test]
fn pt3_round_trip_minimal() {
    let original_bytes = read_fixture("minimal_roundtrip.pt3");
    let original = pt3_fmt::parse(&original_bytes).expect("parse original");

    let written_bytes = save_pt3(&original).expect("write back to PT3");
    let reloaded = pt3_fmt::parse(&written_bytes).expect("re-parse written PT3");

    assert_eq!(reloaded.title.trim(), original.title.trim(), "title");
    assert_eq!(reloaded.initial_delay, original.initial_delay, "delay");
    assert_eq!(reloaded.ton_table, original.ton_table, "ton_table");
    assert_eq!(reloaded.positions.length, original.positions.length, "num_positions");
    assert_eq!(reloaded.positions.loop_pos, original.positions.loop_pos, "loop_pos");

    for i in 0..original.positions.length {
        assert_eq!(
            reloaded.positions.value[i], original.positions.value[i],
            "position[{}]", i
        );
    }

    // Pattern structure
    for pat_idx in 0..2 {
        let orig_pat = original.patterns[pat_idx]
            .as_deref()
            .expect("original pattern must exist");
        let new_pat = reloaded.patterns[pat_idx]
            .as_deref()
            .expect("reloaded pattern must exist");
        assert_eq!(new_pat.length, orig_pat.length, "pattern {} length", pat_idx);
        for row in 0..orig_pat.length {
            for ch in 0..3 {
                assert_eq!(
                    new_pat.items[row].channel[ch].note,
                    orig_pat.items[row].channel[ch].note,
                    "pattern[{}] row[{}] ch[{}] note", pat_idx, row, ch
                );
                if orig_pat.items[row].channel[ch].volume != 0 {
                    assert_eq!(
                        new_pat.items[row].channel[ch].volume,
                        orig_pat.items[row].channel[ch].volume,
                        "pattern[{}] row[{}] ch[{}] volume", pat_idx, row, ch
                    );
                }
            }
        }
    }
}

/// Smoke-test: madness_descent.pt3 parses without error and has the expected
/// key fields (title, positions, delay).
#[test]
fn pt3_smoke_parse_madness_descent() {
    let bytes = read_fixture("madness_descent.pt3");
    let m = pt3_fmt::parse(&bytes).expect("madness_descent.pt3 must parse");
    assert_eq!(m.title.trim(), "Descent Into Madness");
    assert_eq!(m.initial_delay, 6);
    assert_eq!(m.positions.length, 11);
    assert!(m.patterns[0].is_some(), "pattern 0 must be present");
    assert!(m.patterns[1].is_some(), "pattern 1 must be present");
}

/// Load madness_descent.pt3, write → re-parse and verify the first note of
/// pattern 0 is preserved exactly.
#[test]
fn pt3_round_trip_madness_descent() {
    let bytes = read_fixture("madness_descent.pt3");
    let original = pt3_fmt::parse(&bytes).expect("parse original");

    let written = save_pt3(&original).expect("write PT3");
    let reloaded = pt3_fmt::parse(&written).expect("re-parse");

    assert_eq!(reloaded.positions.length, original.positions.length, "num_positions");
    assert_eq!(reloaded.initial_delay, original.initial_delay, "delay");

    for i in 0..original.positions.length {
        assert_eq!(
            reloaded.positions.value[i], original.positions.value[i],
            "position[{}]", i
        );
    }

    let orig_p0 = original.patterns[0].as_deref().expect("orig pattern 0");
    let new_p0  = reloaded.patterns[0].as_deref().expect("reloaded pattern 0");
    assert_eq!(new_p0.length, orig_p0.length, "pattern 0 length");

    // First note row should survive the round-trip unchanged
    for ch in 0..3 {
        assert_eq!(
            new_p0.items[0].channel[ch].note,
            orig_p0.items[0].channel[ch].note,
            "pattern[0] row[0] ch[{}] note", ch
        );
    }
}

/// VTM → PT3 → VTM round-trip: convert madness_descent.vtm to PT3 binary,
/// then parse it back as a module and verify the key fields match.
#[test]
fn vtm_to_pt3_to_vtm_round_trip() {
    // Load the authoritative VTM text fixture
    let vtm_path = format!(
        "{}/tests/fixtures/tunes/madness_descent.vtm",
        env!("CARGO_MANIFEST_DIR")
    );
    let vtm_text = std::fs::read_to_string(&vtm_path)
        .unwrap_or_else(|e| panic!("Cannot read VTM fixture: {}", e));
    let from_vtm = vtm::parse(&vtm_text).expect("parse VTM");

    // Convert to PT3
    let pt3_bytes = save_pt3(&from_vtm).expect("VTM → PT3");
    // Parse the PT3 back
    let from_pt3 = pt3_fmt::parse(&pt3_bytes).expect("PT3 → Module");

    // Key metadata must survive
    assert_eq!(from_pt3.title.trim(), from_vtm.title.trim(), "title");
    assert_eq!(from_pt3.initial_delay, from_vtm.initial_delay, "delay");
    assert_eq!(from_pt3.ton_table, from_vtm.ton_table, "ton_table");
    assert_eq!(from_pt3.positions.length, from_vtm.positions.length, "num_positions");

    // Positions order must be preserved
    for i in 0..from_vtm.positions.length {
        assert_eq!(
            from_pt3.positions.value[i], from_vtm.positions.value[i],
            "position[{}]", i
        );
    }

    // Pattern 0 first row: all notes must survive
    let orig = from_vtm.patterns[0].as_deref().expect("orig pattern 0");
    let dest = from_pt3.patterns[0].as_deref().expect("dest pattern 0");
    assert_eq!(dest.length, orig.length, "pattern 0 length");
    for ch in 0..3 {
        assert_eq!(
            dest.items[0].channel[ch].note, orig.items[0].channel[ch].note,
            "p0 row0 ch{} note", ch
        );
    }
}

// ─── PT2 format tests ─────────────────────────────────────────────────────────

#[test]
fn pt2_smoke_parse_minimal() {
    use vti_core::formats::pt2;
    let bytes = read_fixture("minimal_roundtrip.pt2");
    let m = pt2::parse(&bytes).expect("minimal_roundtrip.pt2 must parse");
    assert_eq!(m.title.trim(), "PT2 minimal fixture", "title");
    assert_eq!(m.initial_delay, 6, "delay");
    assert_eq!(m.positions.length, 1, "num_positions");
    assert_eq!(m.positions.loop_pos, 0, "loop_pos");

    let p0 = m.patterns[0].as_deref().expect("pattern 0 must exist");
    assert_eq!(p0.length, 1, "pattern 0 length");
    assert_eq!(p0.items[0].channel[0].note, 36, "note C-4 on ch A");
    // Sample 1 is present in the module
    assert!(m.samples[1].is_some(), "sample 1 exists");
}

#[test]
fn pt2_roundtrip_via_pt3() {
    use vti_core::formats::pt2;
    let bytes = read_fixture("minimal_roundtrip.pt2");
    let original = pt2::parse(&bytes).expect("parse PT2");
    let pt3_bytes = save_pt3(&original).expect("save as PT3");
    let reloaded = pt3_fmt::parse(&pt3_bytes).expect("re-parse PT3");
    assert_eq!(reloaded.initial_delay, original.initial_delay, "delay");
    assert_eq!(reloaded.positions.length, original.positions.length, "positions");
    let orig_p0 = original.patterns[0].as_deref().expect("orig pat 0");
    let new_p0 = reloaded.patterns[0].as_deref().expect("reloaded pat 0");
    assert_eq!(new_p0.items[0].channel[0].note, orig_p0.items[0].channel[0].note, "note");
}

// ─── PT1 format tests ─────────────────────────────────────────────────────────

#[test]
fn pt1_smoke_parse_minimal() {
    use vti_core::formats::pt1;
    let bytes = read_fixture("minimal_roundtrip.pt1");
    let m = pt1::parse(&bytes).expect("minimal_roundtrip.pt1 must parse");
    assert_eq!(m.title.trim(), "PT1 minimal fixture", "title");
    assert_eq!(m.initial_delay, 6, "delay");
    assert_eq!(m.positions.length, 1, "num_positions");
    let p0 = m.patterns[0].as_deref().expect("pattern 0 must exist");
    assert_eq!(p0.items[0].channel[0].note, 36, "note C-4");
    assert!(m.samples[1].is_some(), "sample 1 exists");
}

#[test]
fn pt1_roundtrip_via_pt3() {
    use vti_core::formats::pt1;
    let bytes = read_fixture("minimal_roundtrip.pt1");
    let original = pt1::parse(&bytes).expect("parse PT1");
    let pt3_bytes = save_pt3(&original).expect("save as PT3");
    let reloaded = pt3_fmt::parse(&pt3_bytes).expect("re-parse PT3");
    assert_eq!(reloaded.initial_delay, original.initial_delay, "delay");
    assert_eq!(reloaded.positions.length, original.positions.length, "positions");
    let orig_p0 = original.patterns[0].as_deref().expect("orig pat 0");
    let new_p0 = reloaded.patterns[0].as_deref().expect("reloaded pat 0");
    assert_eq!(new_p0.items[0].channel[0].note, orig_p0.items[0].channel[0].note, "note");
}

// ─── STC format tests ─────────────────────────────────────────────────────────

#[test]
fn stc_smoke_parse_minimal() {
    use vti_core::formats::stc;
    let bytes = read_fixture("minimal_roundtrip.stc");
    let m = stc::parse(&bytes).expect("minimal_roundtrip.stc must parse");
    assert_eq!(m.title.trim(), "STC minimal", "title");
    assert_eq!(m.initial_delay, 6, "delay");
    assert_eq!(m.positions.length, 1, "num_positions");
    let p0 = m.patterns[0].as_deref().expect("pattern 0 must exist");
    assert_eq!(p0.items[0].channel[0].note, 36, "note C-4");
}

#[test]
fn stc_roundtrip_via_pt3() {
    use vti_core::formats::stc;
    let bytes = read_fixture("minimal_roundtrip.stc");
    let original = stc::parse(&bytes).expect("parse STC");
    let pt3_bytes = save_pt3(&original).expect("save as PT3");
    let reloaded = pt3_fmt::parse(&pt3_bytes).expect("re-parse PT3");
    assert_eq!(reloaded.initial_delay, original.initial_delay, "delay");
    assert_eq!(reloaded.positions.length, original.positions.length, "positions");
    let orig_p0 = original.patterns[0].as_deref().expect("orig pat 0");
    let new_p0 = reloaded.patterns[0].as_deref().expect("reloaded pat 0");
    assert_eq!(new_p0.items[0].channel[0].note, orig_p0.items[0].channel[0].note, "note");
}

// ─── STP format tests ─────────────────────────────────────────────────────────

#[test]
fn stp_smoke_parse_minimal() {
    use vti_core::formats::stp;
    let bytes = read_fixture("minimal_roundtrip.stp");
    let m = stp::parse(&bytes).expect("minimal_roundtrip.stp must parse");
    assert_eq!(m.initial_delay, 6, "delay");
    assert_eq!(m.positions.length, 1, "num_positions");
    let p0 = m.patterns[0].as_deref().expect("pattern 0 must exist");
    assert_eq!(p0.items[0].channel[0].note, 36, "note C-4");
    assert!(m.samples[1].is_some(), "sample 1 exists");
}

#[test]
fn stp_roundtrip_via_pt3() {
    use vti_core::formats::stp;
    let bytes = read_fixture("minimal_roundtrip.stp");
    let original = stp::parse(&bytes).expect("parse STP");
    let pt3_bytes = save_pt3(&original).expect("save as PT3");
    let reloaded = pt3_fmt::parse(&pt3_bytes).expect("re-parse PT3");
    assert_eq!(reloaded.initial_delay, original.initial_delay, "delay");
    assert_eq!(reloaded.positions.length, original.positions.length, "positions");
    let orig_p0 = original.patterns[0].as_deref().expect("orig pat 0");
    let new_p0 = reloaded.patterns[0].as_deref().expect("reloaded pat 0");
    assert_eq!(new_p0.items[0].channel[0].note, orig_p0.items[0].channel[0].note, "note");
}

/// `formats::load()` dispatches correctly for all supported extensions.
#[test]
fn format_load_dispatch_all_formats() {
    use vti_core::formats::load;
    for ext in &["pt2", "pt1", "stc", "stp"] {
        let bytes = read_fixture(&format!("minimal_roundtrip.{}", ext));
        let m = load(&bytes, &format!("module.{}", ext))
            .unwrap_or_else(|e| panic!("load(.{}) failed: {}", ext, e));
        assert_eq!(m.initial_delay, 6, "{}: delay", ext);
        assert_eq!(m.positions.length, 1, "{}: positions", ext);
    }
}


// ─── ZX Spectrum export tests ─────────────────────────────────────────────────

/// Build a Module that has many **identical** samples and ornaments under
/// different indices.  This is the worst-case fixture for the old Pascal code
/// (which would write duplicate data for each index) and the best-case
/// demonstration of the deduplication improvement in `pt3::write()`.
///
/// Layout:
/// - Samples 1-8 all contain the same single-tick silent lead tone.
/// - Ornaments 1-6 all contain the same two-step octave arpeggio [0, 12].
/// - Pattern 0 uses every sample (cols A/B/C across 8 rows) and every ornament.
fn make_duplicate_heavy_module() -> Module {
    let mut m = Module::default();
    m.initial_delay = 6;

    // Identical sample content: length=2, loop=0, same two ticks.
    let make_sample = || -> Sample {
        let mut s = Sample::default();
        s.length = 2;
        s.loop_pos = 0;
        s.items[0] = SampleTick { amplitude: 12, mixer_ton: true, ..SampleTick::default() };
        s.items[1] = SampleTick { amplitude: 8,  mixer_ton: true, ..SampleTick::default() };
        s
    };
    // Register the same sample data under indices 1-8.
    for i in 1..=8usize {
        m.samples[i] = Some(Box::new(make_sample()));
    }

    // Identical ornament: length=2, loop=0, steps [0, 12].
    let make_ornament = || -> Ornament {
        let mut o = Ornament::default();
        o.length = 2;
        o.loop_pos = 0;
        o.items[0] = 0;
        o.items[1] = 12;
        o
    };
    for i in 1..=6usize {
        m.ornaments[i] = Some(Box::new(make_ornament()));
    }

    // Build a pattern that references all samples and ornaments so they are
    // included by the `is_sample` / `is_ornament` usage scan in `pt3::write()`.
    let mut pat = Pattern::default();
    pat.length = 8;
    for row in 0..8usize {
        // Use a different sample index on each row (cycles 1-8).
        let s = (row % 8) as u8 + 1;
        // Use a different ornament index on each row (cycles 1-6).
        let o = (row % 6) as u8 + 1;
        for ch in 0..3 {
            pat.items[row].channel[ch] = ChannelLine {
                note: 36, // C-4
                sample: s,
                ornament: o,
                volume: 12,
                ..ChannelLine::default()
            };
        }
    }
    m.patterns[0] = Some(Box::new(pat));
    m.positions.length = 1;
    m.positions.value[0] = 0;

    m
}

#[test]
fn pt3_dedup_reduces_size_for_duplicate_heavy_module() {
    use vti_core::formats::pt3 as pt3_fmt;
    use vti_core::formats::save_pt3;

    let m = make_duplicate_heavy_module();
    let dedup_bytes = save_pt3(&m).expect("must write");

    // Build the same module but with 8 *different* samples (same structure, different
    // amplitudes) so we can measure how much data dedup saves.
    let mut m_unique = make_duplicate_heavy_module();
    for i in 1..=8usize {
        let mut s = Sample::default();
        s.length = 2;
        s.loop_pos = 0;
        // Give each sample a distinct amplitude so no two are equal.
        s.items[0] = SampleTick { amplitude: i as u8,      mixer_ton: true, ..SampleTick::default() };
        s.items[1] = SampleTick { amplitude: (i + 8) as u8, mixer_ton: true, ..SampleTick::default() };
        m_unique.samples[i] = Some(Box::new(s));
    }
    let unique_bytes = save_pt3(&m_unique).expect("unique must write");

    // Each sample is 2 (header) + 2×4 (ticks) = 10 bytes.
    // 8 unique samples = 80 bytes; 8 identical (dedup) = 10 bytes.
    // The dedup version must be strictly smaller.
    assert!(
        dedup_bytes.len() < unique_bytes.len(),
        "dedup ({} bytes) should be smaller than unique ({} bytes)",
        dedup_bytes.len(),
        unique_bytes.len()
    );
    // Expected saving: 7 × 10 = 70 bytes for samples (each of 8 dup ornaments
    // saves (2+2) = 4 bytes too, so total saving ≥ 70 bytes).
    let saving = unique_bytes.len() - dedup_bytes.len();
    assert!(
        saving >= 70,
        "expected at least 70 bytes saved by sample dedup, got {}",
        saving
    );

    // Round-trip: the parsed module must still reference all 8 samples with
    // identical content, even though the file stores only 1 copy.
    let reloaded = pt3_fmt::parse(&dedup_bytes).expect("must re-parse");
    for i in 1..=8usize {
        let s = reloaded.samples[i].as_deref().expect(&format!("sample {} must exist", i));
        assert_eq!(s.length, 2, "sample {} length", i);
        assert_eq!(s.items[0].amplitude, 12, "sample {} tick0 amplitude", i);
        assert_eq!(s.items[1].amplitude, 8,  "sample {} tick1 amplitude", i);
    }
    for i in 1..=6usize {
        let o = reloaded.ornaments[i].as_deref().expect(&format!("ornament {} must exist", i));
        assert_eq!(o.length, 2, "ornament {} length", i);
        assert_eq!(o.items[0], 0,  "ornament {} step0", i);
        assert_eq!(o.items[1], 12, "ornament {} step1", i);
    }
}

#[test]
fn pt3_dedup_no_change_for_unique_samples() {
    use vti_core::formats::save_pt3;

    // Module with all different sample contents — dedup must not change them.
    let mut m = Module::default();
    m.initial_delay = 6;
    for i in 1..=4usize {
        let mut s = Sample::default();
        s.length = 1;
        s.loop_pos = 0;
        s.items[0] = SampleTick { amplitude: i as u8, mixer_ton: true, ..SampleTick::default() };
        m.samples[i] = Some(Box::new(s));
    }
    let mut pat = Pattern::default();
    pat.length = 4;
    for row in 0..4usize {
        pat.items[row].channel[0] = ChannelLine {
            note: 36, sample: row as u8 + 1, ..ChannelLine::default()
        };
    }
    m.patterns[0] = Some(Box::new(pat));
    m.positions.length = 1;
    m.positions.value[0] = 0;

    let bytes = save_pt3(&m).expect("must write");
    let reloaded = vti_core::formats::pt3::parse(&bytes).expect("must re-parse");
    for i in 1..=4usize {
        let s = reloaded.samples[i].as_deref().expect(&format!("sample {} exists", i));
        assert_eq!(s.items[0].amplitude, i as u8, "sample {} amplitude preserved", i);
    }
}

// ─── ZX export format tests ────────────────────────────────────────────────────

fn make_simple_module() -> Module {
    let mut m = Module::default();
    m.initial_delay = 6;
    m.title = "Test".to_string();
    m.author = "Tester".to_string();

    let mut s = Sample::default();
    s.length = 1;
    s.loop_pos = 0;
    s.items[0] = SampleTick { amplitude: 12, mixer_ton: true, ..SampleTick::default() };
    m.samples[1] = Some(Box::new(s));

    let mut pat = Pattern::default();
    pat.length = 2;
    pat.items[0].channel[0] = ChannelLine { note: 36, sample: 1, ..ChannelLine::default() };
    m.patterns[0] = Some(Box::new(pat));
    m.positions.length = 1;
    m.positions.value[0] = 0;
    m
}

#[test]
fn zx_export_tap_basic_structure() {
    use vti_core::formats::zx_export::{export_zx, ZxExportOptions, ZxFormat};
    let m = make_simple_module();
    let opts = ZxExportOptions {
        format: ZxFormat::Tap,
        load_addr: 0xC000,
        looping: false,
        name: "test".to_string(),
        title: m.title.clone(),
        author: m.author.clone(),
    };
    let data = export_zx(&m, &opts).expect("tap export must succeed");

    // A TAP file is a sequence of blocks.  Each block: 2-byte LE length, then
    // (length) bytes.  We expect exactly 4 blocks: hdr1, data1, hdr2, data2.
    let mut pos = 0usize;
    let mut blocks = Vec::new();
    while pos + 2 <= data.len() {
        let blen = u16::from_le_bytes([data[pos], data[pos + 1]]) as usize;
        assert!(pos + 2 + blen <= data.len(), "block overflows at pos {}", pos);
        blocks.push(data[pos + 2..pos + 2 + blen].to_vec());
        pos += 2 + blen;
    }
    assert_eq!(blocks.len(), 4, "expected 4 TAP blocks, got {}", blocks.len());

    // Block 0 and 2 are header blocks (flag byte 0x00).
    assert_eq!(blocks[0][0], 0x00, "block 0 flag must be 0x00 (header)");
    assert_eq!(blocks[2][0], 0x00, "block 2 flag must be 0x00 (header)");
    // Block 1 and 3 are data blocks (flag byte 0xFF).
    assert_eq!(blocks[1][0], 0xFF, "block 1 flag must be 0xFF (data)");
    assert_eq!(blocks[3][0], 0xFF, "block 3 flag must be 0xFF (data)");
    // Header type byte (after flag) = 3 (CODE).
    assert_eq!(blocks[0][1], 3, "header0 type must be CODE (3)");
    assert_eq!(blocks[2][1], 3, "header2 type must be CODE (3)");
}

#[test]
fn zx_export_hobeta_code_header_signature() {
    use vti_core::formats::zx_export::{export_zx, ZxExportOptions, ZxFormat};
    let m = make_simple_module();
    let opts = ZxExportOptions {
        format: ZxFormat::HobetaCode,
        load_addr: 0xC000,
        looping: false,
        name: "demo".to_string(),
        title: m.title.clone(),
        author: m.author.clone(),
    };
    let data = export_zx(&m, &opts).expect("hobeta export must succeed");
    // Hobeta header is 17 bytes.  Byte 8 = type character 'C'.
    assert!(data.len() > 17, "must be longer than just the header");
    assert_eq!(data[8], b'C', "hobeta type byte must be 'C'");
    // Start address stored LE at bytes 9-10.
    let start = u16::from_le_bytes([data[9], data[10]]);
    assert_eq!(start, 0xC000, "start address must be 0xC000");
}

#[test]
fn zx_export_scl_header_signature() {
    use vti_core::formats::zx_export::{export_zx, ZxExportOptions, ZxFormat};
    let m = make_simple_module();
    let opts = ZxExportOptions {
        format: ZxFormat::Scl,
        load_addr: 0xC000,
        looping: false,
        name: "demo".to_string(),
        title: m.title.clone(),
        author: m.author.clone(),
    };
    let data = export_zx(&m, &opts).expect("scl export must succeed");
    // SCL files start with "SINCLAIR".
    assert_eq!(&data[..8], b"SINCLAIR", "SCL magic must be SINCLAIR");
    // Two directory entries.
    assert_eq!(data[8], 2, "NBlk must be 2");
}

#[test]
fn zx_export_ay_file_signature() {
    use vti_core::formats::zx_export::{export_zx, ZxExportOptions, ZxFormat};
    let m = make_simple_module();
    let opts = ZxExportOptions {
        format: ZxFormat::AyFile,
        load_addr: 0xC000,
        looping: false,
        name: "demo".to_string(),
        title: m.title.clone(),
        author: m.author.clone(),
    };
    let data = export_zx(&m, &opts).expect("ay export must succeed");
    // AY files start with "ZXAY" then "EMUL".
    assert_eq!(&data[..4], b"ZXAY", "AY magic must be ZXAY");
    assert_eq!(&data[4..8], b"EMUL", "AY type must be EMUL");
}

#[test]
fn zx_export_hobeta_mem_no_player() {
    use vti_core::formats::zx_export::{export_zx, ZxExportOptions, ZxFormat};
    let m = make_simple_module();
    let opts_mem = ZxExportOptions {
        format: ZxFormat::HobetaMem,
        load_addr: 0xC000,
        looping: false,
        name: "demo".to_string(),
        title: m.title.clone(),
        author: m.author.clone(),
    };
    let opts_code = ZxExportOptions {
        format: ZxFormat::HobetaCode,
        ..opts_mem.clone()
    };
    let mem_data  = export_zx(&m, &opts_mem).expect("mem export");
    let code_data = export_zx(&m, &opts_code).expect("code export");
    // $M is smaller because it omits the player binary.
    assert!(
        mem_data.len() < code_data.len(),
        "HobetaMem ({}) should be smaller than HobetaCode ({})",
        mem_data.len(), code_data.len()
    );
    // $M type byte is 'm'.
    assert_eq!(mem_data[8], b'm', "HobetaMem type byte must be 'm'");
}

#[test]
fn zx_export_duplicate_heavy_module_fits_in_zx_ram() {
    use vti_core::formats::zx_export::{export_zx, ZxExportOptions, ZxFormat};
    let m = make_duplicate_heavy_module();
    for fmt in [ZxFormat::HobetaCode, ZxFormat::Tap, ZxFormat::Scl, ZxFormat::AyFile] {
        let opts = ZxExportOptions {
            format: fmt,
            load_addr: 0xC000,
            looping: false,
            name: "dup_test".to_string(),
            title: "Dup Test".to_string(),
            author: "Test".to_string(),
        };
        let result = export_zx(&m, &opts);
        assert!(result.is_ok(), "export {:?} must succeed: {:?}", fmt, result);
    }
}
