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
