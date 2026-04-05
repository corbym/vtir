use std::env;
use std::io::{self, Write};
use std::path::{Path, PathBuf};
use std::time::Duration;

use anyhow::{bail, Context, Result};
use crossterm::cursor::{Hide, MoveTo, Show};
use crossterm::event::{self, Event, KeyCode, KeyEvent};
use crossterm::execute;
use crossterm::queue;
use crossterm::style::Print;
use crossterm::terminal::{
    self, BeginSynchronizedUpdate, Clear, ClearType, EndSynchronizedUpdate, EnterAlternateScreen,
    LeaveAlternateScreen,
};
use vti_audio::AudioPlayer;
use vti_ay::{AyConfig, ChipType, Synthesizer};
use vti_core::formats;
use vti_core::playback::{
    get_module_time, get_position_time, get_position_time_ex, init_tracker_parameters, Engine,
    PlayVars,
};
use vti_core::util::note_to_str;
use vti_core::{AyRegisters, Module};

const TICK_MS: u64 = 20;
const VIEW_ROWS: usize = 20;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
enum Command {
    Quit,
    TogglePlay,
    Step,
    MoveUp,
    MoveDown,
    MoveLeft,
    MoveRight,
    PrevPosition,
    NextPosition,
    GoTop,
    GoBottom,
    ToggleFollow,
}

#[derive(Debug)]
struct CliArgs {
    module_path: PathBuf,
    ticks: Option<usize>,
    play: bool,
}

impl CliArgs {
    fn parse() -> Result<Self> {
        let mut module_path: Option<PathBuf> = None;
        let mut ticks: Option<usize> = None;
        let mut play = false;

        let mut args = env::args().skip(1);
        while let Some(arg) = args.next() {
            match arg.as_str() {
                "-h" | "--help" => {
                    print_usage();
                    std::process::exit(0);
                }
                "--ticks" => {
                    let Some(v) = args.next() else {
                        bail!("--ticks expects a numeric value");
                    };
                    let parsed = v
                        .parse::<usize>()
                        .with_context(|| format!("invalid --ticks value: {v}"))?;
                    ticks = Some(parsed);
                }
                "--play" => {
                    play = true;
                }
                "--no-play" => {
                    play = false;
                }
                _ if arg.starts_with("--play=") => {
                    let value = arg.trim_start_matches("--play=");
                    play = parse_bool_flag(value)
                        .with_context(|| format!("invalid --play value: {value}"))?;
                }
                _ if arg.starts_with('-') => {
                    bail!("unknown option: {arg}");
                }
                _ => {
                    if module_path.is_some() {
                        bail!("only one module path is allowed");
                    }
                    module_path = Some(PathBuf::from(arg));
                }
            }
        }

        let Some(module_path) = module_path else {
            print_usage();
            bail!("missing module file path");
        };

        Ok(Self {
            module_path,
            ticks,
            play,
        })
    }
}

fn parse_bool_flag(s: &str) -> Result<bool> {
    match s.to_ascii_lowercase().as_str() {
        "1" | "true" | "yes" | "on" => Ok(true),
        "0" | "false" | "no" | "off" => Ok(false),
        _ => bail!("expected true/false"),
    }
}

struct CliTracker {
    file_name: String,
    module: Module,
    vars: PlayVars,
    synth: Synthesizer,
    samples_per_tick: u32,
    selected_position: usize,
    selected_row: usize,
    selected_channel: usize,
    follow_playhead: bool,
    playing: bool,
    audio: Option<AudioPlayer>,
    audio_error: Option<String>,
    tick_count: u64,
    last_pcm_nonzero: usize,
    total_pcm_nonzero: usize,
    last_regs: AyRegisters,
    last_drawn_lines: u16,
}

impl CliTracker {
    fn load(path: &Path, start_playing: bool) -> Result<Self> {
        let bytes =
            std::fs::read(path).with_context(|| format!("cannot read file: {}", path.display()))?;
        let file_name = path
            .file_name()
            .and_then(|s| s.to_str())
            .unwrap_or("module")
            .to_string();

        let mut module = formats::load(&bytes, &file_name)
            .with_context(|| format!("cannot parse {}", path.display()))?;

        let mut vars = PlayVars::default();
        init_tracker_parameters(&mut module, &mut vars, true);
        vars.delay = module.initial_delay as i8;
        vars.delay_counter = 1;
        if module.positions.length > 0 {
            vars.current_position = 0;
            vars.current_pattern = module.positions.value[0] as i32;
        }

        let cfg = AyConfig::default();
        let sample_rate = cfg.sample_rate;
        let samples_per_tick = cfg.ay_tiks_in_interrupt();
        let synth = Synthesizer::new(cfg, 1, ChipType::AY);

        let (audio, audio_error) = match AudioPlayer::start(sample_rate) {
            Ok(player) => (Some(player), None),
            Err(e) => (None, Some(e.to_string())),
        };

        Ok(Self {
            file_name,
            module,
            vars,
            synth,
            samples_per_tick,
            selected_position: 0,
            selected_row: 0,
            selected_channel: 0,
            follow_playhead: true,
            playing: start_playing,
            audio,
            audio_error,
            tick_count: 0,
            last_pcm_nonzero: 0,
            total_pcm_nonzero: 0,
            last_regs: AyRegisters::default(),
            last_drawn_lines: 0,
        })
    }

    fn run_headless_ticks(&mut self, ticks: usize) {
        for _ in 0..ticks {
            self.tick_once();
        }
    }

    fn apply_command(&mut self, cmd: Command) -> bool {
        match cmd {
            Command::Quit => return true,
            Command::TogglePlay => {
                self.playing = !self.playing;
            }
            Command::Step => self.tick_once(),
            Command::MoveUp => {
                if self.selected_row > 0 {
                    self.selected_row -= 1;
                }
            }
            Command::MoveDown => {
                let max_row = self.current_pattern_length().saturating_sub(1);
                if self.selected_row < max_row {
                    self.selected_row += 1;
                }
            }
            Command::MoveLeft => {
                self.selected_channel = self.selected_channel.saturating_sub(1);
            }
            Command::MoveRight => {
                if self.selected_channel < 2 {
                    self.selected_channel += 1;
                }
            }
            Command::PrevPosition => {
                self.jump_to_position(self.selected_position.saturating_sub(1));
            }
            Command::NextPosition => {
                self.jump_to_position(self.selected_position.saturating_add(1));
            }
            Command::GoTop => self.selected_row = 0,
            Command::GoBottom => {
                self.selected_row = self.current_pattern_length().saturating_sub(1);
            }
            Command::ToggleFollow => self.follow_playhead = !self.follow_playhead,
        }
        false
    }

    fn tick_once(&mut self) {
        let mut regs = AyRegisters::default();
        {
            let mut engine = Engine {
                module: &mut self.module,
                vars: &mut self.vars,
            };
            let _ = engine.module_play_current_line(&mut regs);
        }
        self.last_regs = regs.clone();

        self.synth.apply_registers(0, &regs);
        self.synth.render_frame(self.samples_per_tick);
        let pcm = self.synth.drain(self.samples_per_tick as usize);
        self.last_pcm_nonzero = pcm.iter().filter(|s| s.left != 0 || s.right != 0).count();
        self.total_pcm_nonzero += self.last_pcm_nonzero;

        if let Some(audio) = &self.audio {
            audio.push_samples(&pcm);
        }
        self.tick_count += 1;

        if self.follow_playhead {
            self.selected_position = self
                .vars
                .current_position
                .min(self.module.positions.length.saturating_sub(1));
            self.selected_row = self.vars.current_line.saturating_sub(1);
            self.selected_channel = 0;
            self.clamp_cursor();
        }
    }

    fn jump_to_position(&mut self, requested: usize) {
        let max_pos = self.module.positions.length.saturating_sub(1);
        self.selected_position = requested.min(max_pos);
        self.selected_row = 0;
        self.clamp_cursor();
    }

    fn current_pattern_index(&self) -> usize {
        if self.module.positions.length == 0 {
            return 0;
        }
        self.module.positions.value[self.selected_position]
    }

    fn current_pattern_length(&self) -> usize {
        let pat_idx = self.current_pattern_index();
        self.module.patterns[pat_idx]
            .as_deref()
            .map(|p| p.length)
            .unwrap_or(1)
    }

    fn clamp_cursor(&mut self) {
        let max_row = self.current_pattern_length().saturating_sub(1);
        self.selected_row = self.selected_row.min(max_row);
        self.selected_channel = self.selected_channel.min(2);
    }

    fn draw(&mut self, out: &mut impl Write) -> Result<()> {
        let (term_w, term_h) = terminal::size().unwrap_or((120, 30));

        // Compute timing for the header line.
        let total_ticks = get_module_time(&self.module);
        let play_pos = if self.playing {
            self.vars.current_position
        } else {
            self.selected_position
        };
        let play_line = if self.playing {
            self.vars.current_line.saturating_sub(1)
        } else {
            self.selected_row
        };
        let (pos_ticks, pos_delay) = get_position_time(&self.module, play_pos);
        let row_ticks = get_position_time_ex(&self.module, play_pos, pos_delay, play_line);
        let elapsed = pos_ticks + row_ticks;
        let fmt_ticks = |t: u32| -> String {
            let secs = t / 50;
            format!("{:02}:{:02}", secs / 60, secs % 60)
        };

        let mut lines = Vec::new();
        lines.push(format!(
            "VTI CLI  file={}  title={}  author={}",
            self.file_name, self.module.title, self.module.author
        ));
        lines.push(format!(
            "play={}  follow={}  tick={}  pos={}/{}  pat={}  row={}  ch={}  time={}/{}",
            if self.playing { "on" } else { "off" },
            if self.follow_playhead { "on" } else { "off" },
            self.tick_count,
            self.selected_position,
            self.module.positions.length.saturating_sub(1),
            self.current_pattern_index(),
            self.selected_row,
            self.selected_channel,
            fmt_ticks(elapsed),
            fmt_ticks(total_ticks),
        ));
        let audio_state = if self.audio.is_some() {
            "on".to_string()
        } else if let Some(err) = &self.audio_error {
            format!("off ({err})")
        } else {
            "off".to_string()
        };
        lines.push(format!("audio={audio_state}"));
        lines.push(format!("regs: A={:02X} B={:02X} C={:02X} mix={:02X} noise={:02X} env={:04X}/{:02X} pcm_nonzero={}",
            self.last_regs.amplitude_a,
            self.last_regs.amplitude_b,
            self.last_regs.amplitude_c,
            self.last_regs.mixer,
            self.last_regs.noise,
            self.last_regs.envelope,
            self.last_regs.env_type,
            self.last_pcm_nonzero,
        ));
        lines.push("keys: arrows move  PgUp/PgDn position  Space play/pause  s step  f follow  Home/End  q quit".to_string());
        lines.push(String::new());

        let pat_idx = self.current_pattern_index();
        let Some(pattern) = self.module.patterns[pat_idx].as_deref() else {
            lines.push(format!("pattern {} is empty", pat_idx));
            render_lines(out, &lines, term_w, term_h, &mut self.last_drawn_lines)?;
            out.flush()?;
            return Ok(());
        };

        let play_row = self.vars.current_line.saturating_sub(1);
        let play_pos = self.vars.current_position;

        let first_row = self.selected_row.saturating_sub(VIEW_ROWS / 2);
        let last_row = (first_row + VIEW_ROWS).min(pattern.length);

        for row in first_row..last_row {
            let cursor_mark = if row == self.selected_row { '>' } else { ' ' };
            let play_mark = if play_pos == self.selected_position && row == play_row {
                '*'
            } else {
                ' '
            };
            let ch0 = format_channel(
                &pattern.items[row].channel[0],
                self.selected_channel == 0 && row == self.selected_row,
            );
            let ch1 = format_channel(
                &pattern.items[row].channel[1],
                self.selected_channel == 1 && row == self.selected_row,
            );
            let ch2 = format_channel(
                &pattern.items[row].channel[2],
                self.selected_channel == 2 && row == self.selected_row,
            );

            lines.push(format!(
                "{}{} {:02X}|{}|{}|{}",
                cursor_mark, play_mark, row, ch0, ch1, ch2
            ));
        }

        render_lines(out, &lines, term_w, term_h, &mut self.last_drawn_lines)?;
        out.flush()?;
        Ok(())
    }
}

fn render_lines(
    out: &mut impl Write,
    lines: &[String],
    term_w: u16,
    term_h: u16,
    last_drawn_lines: &mut u16,
) -> Result<()> {
    let max_visible = term_h as usize;
    let draw_count = lines.len().min(max_visible) as u16;

    queue!(out, BeginSynchronizedUpdate)?;
    for (i, line) in lines.iter().take(max_visible).enumerate() {
        let clipped = clip_to_width(line, term_w as usize);
        queue!(
            out,
            MoveTo(0, i as u16),
            Clear(ClearType::CurrentLine),
            Print(clipped),
        )?;
    }

    for i in draw_count..*last_drawn_lines {
        queue!(out, MoveTo(0, i), Clear(ClearType::CurrentLine))?;
    }

    queue!(out, EndSynchronizedUpdate)?;
    *last_drawn_lines = draw_count;
    Ok(())
}

fn clip_to_width(s: &str, max: usize) -> String {
    s.chars().take(max).collect()
}

fn format_channel(line: &vti_core::ChannelLine, selected: bool) -> String {
    let note = note_to_str(line.note);
    let sel = if selected { '>' } else { ' ' };
    format!(
        "{}{} s{:02X} o{:02X} v{:X}",
        sel, note, line.sample, line.ornament, line.volume
    )
}

fn command_from_key(key: KeyEvent) -> Option<Command> {
    match key.code {
        KeyCode::Char('q') | KeyCode::Esc => Some(Command::Quit),
        KeyCode::Char(' ') => Some(Command::TogglePlay),
        KeyCode::Char('s') => Some(Command::Step),
        KeyCode::Char('f') => Some(Command::ToggleFollow),
        KeyCode::Up => Some(Command::MoveUp),
        KeyCode::Down => Some(Command::MoveDown),
        KeyCode::Left => Some(Command::MoveLeft),
        KeyCode::Right => Some(Command::MoveRight),
        KeyCode::PageUp | KeyCode::Char('p') => Some(Command::PrevPosition),
        KeyCode::PageDown | KeyCode::Char('n') => Some(Command::NextPosition),
        KeyCode::Home => Some(Command::GoTop),
        KeyCode::End => Some(Command::GoBottom),
        _ => None,
    }
}

struct TerminalGuard;

impl TerminalGuard {
    fn enter(out: &mut impl Write) -> Result<Self> {
        terminal::enable_raw_mode().context("failed to enable raw mode")?;
        execute!(out, EnterAlternateScreen, Hide).context("failed to enter alternate screen")?;
        Ok(Self)
    }
}

impl Drop for TerminalGuard {
    fn drop(&mut self) {
        let mut out = io::stdout();
        let _ = execute!(out, Show, LeaveAlternateScreen);
        let _ = terminal::disable_raw_mode();
    }
}

fn run_interactive(mut tracker: CliTracker) -> Result<()> {
    let mut out = io::stdout();
    let _guard = TerminalGuard::enter(&mut out)?;
    let mut dirty = true;

    loop {
        if dirty {
            tracker.draw(&mut out)?;
            dirty = false;
        }

        if event::poll(Duration::from_millis(TICK_MS))? {
            if let Event::Key(key) = event::read()? {
                if let Some(cmd) = command_from_key(key) {
                    if tracker.apply_command(cmd) {
                        break;
                    }
                    dirty = true;
                }
            }
        }

        if tracker.playing {
            tracker.tick_once();
            dirty = true;
        }
    }

    Ok(())
}

fn print_usage() {
    eprintln!("Usage: vti-cli <module-file> [--ticks N] [--play[=true|false]]");
    eprintln!("  no --ticks: interactive keyboard tracker view");
    eprintln!("  --ticks N: headless playback harness for N ticks (for diagnostics/tests)");
    eprintln!("  --play: start interactive mode with playback enabled (default: off)");
}

fn main() -> Result<()> {
    env_logger::init();
    let args = CliArgs::parse()?;
    let mut tracker = CliTracker::load(&args.module_path, args.play)?;

    if let Some(ticks) = args.ticks {
        tracker.run_headless_ticks(ticks);
        println!(
            "ticks={} pcm_nonzero_last_tick={} pcm_nonzero_total={} total_ticks={} pos={} line={}",
            ticks,
            tracker.last_pcm_nonzero,
            tracker.total_pcm_nonzero,
            tracker.tick_count,
            tracker.vars.current_position,
            tracker.vars.current_line
        );
        return Ok(());
    }

    run_interactive(tracker)
}

#[cfg(test)]
mod tests {
    use super::*;
    use vti_core::{AdditionalCommand, ChannelLine, Pattern, Sample, SampleTick};

    fn make_test_module() -> Module {
        let mut m = Module::default();
        m.initial_delay = 1;
        m.positions.length = 1;
        m.positions.value[0] = 0;

        let mut s = Sample::default();
        s.length = 1;
        s.loop_pos = 0;
        s.items[0] = SampleTick {
            amplitude: 15,
            mixer_ton: true,
            mixer_noise: false,
            ..SampleTick::default()
        };
        m.samples[1] = Some(Box::new(s));

        let mut p = Pattern::default();
        p.length = 4;
        p.items[0].channel[0] = ChannelLine {
            note: 48,
            sample: 1,
            ornament: 0,
            volume: 15,
            envelope: 0,
            additional_command: AdditionalCommand::default(),
        };
        m.patterns[0] = Some(Box::new(p));
        m
    }

    fn tracker_for_test() -> CliTracker {
        let mut module = make_test_module();
        let mut vars = PlayVars::default();
        init_tracker_parameters(&mut module, &mut vars, true);
        vars.delay = module.initial_delay as i8;
        vars.delay_counter = 1;
        vars.current_pattern = module.positions.value[0] as i32;

        let cfg = AyConfig::default();
        let samples_per_tick = cfg.ay_tiks_in_interrupt();
        let synth = Synthesizer::new(cfg, 1, ChipType::AY);

        CliTracker {
            file_name: "test.pt3".to_string(),
            module,
            vars,
            synth,
            samples_per_tick,
            selected_position: 0,
            selected_row: 0,
            selected_channel: 0,
            follow_playhead: false,
            playing: false,
            audio: None,
            audio_error: None,
            tick_count: 0,
            last_pcm_nonzero: 0,
            total_pcm_nonzero: 0,
            last_regs: AyRegisters::default(),
            last_drawn_lines: 0,
        }
    }

    #[test]
    fn key_mapping_is_intuitive_for_core_controls() {
        assert_eq!(
            command_from_key(KeyEvent::from(KeyCode::Char('q'))),
            Some(Command::Quit)
        );
        assert_eq!(
            command_from_key(KeyEvent::from(KeyCode::Char(' '))),
            Some(Command::TogglePlay)
        );
        assert_eq!(
            command_from_key(KeyEvent::from(KeyCode::Up)),
            Some(Command::MoveUp)
        );
        assert_eq!(
            command_from_key(KeyEvent::from(KeyCode::PageDown)),
            Some(Command::NextPosition)
        );
    }

    #[test]
    fn navigation_commands_clamp_cursor() {
        let mut t = tracker_for_test();
        t.apply_command(Command::MoveLeft);
        assert_eq!(t.selected_channel, 0);

        t.apply_command(Command::MoveRight);
        t.apply_command(Command::MoveRight);
        t.apply_command(Command::MoveRight);
        assert_eq!(t.selected_channel, 2);

        t.apply_command(Command::GoBottom);
        assert_eq!(t.selected_row, 3);

        t.apply_command(Command::MoveDown);
        assert_eq!(t.selected_row, 3);
    }

    #[test]
    fn step_tick_produces_pcm_activity() {
        let mut t = tracker_for_test();
        t.apply_command(Command::Step);
        assert_eq!(t.tick_count, 1);
        assert!(
            t.last_pcm_nonzero > 0,
            "expected non-zero PCM from test module step"
        );
    }

    #[test]
    fn parse_bool_flag_accepts_true_false_variants() {
        assert_eq!(parse_bool_flag("true").expect("true parse"), true);
        assert_eq!(parse_bool_flag("1").expect("1 parse"), true);
        assert_eq!(parse_bool_flag("false").expect("false parse"), false);
        assert_eq!(parse_bool_flag("0").expect("0 parse"), false);
        assert!(parse_bool_flag("maybe").is_err());
    }

    // ── Editor logic smoke tests ──────────────────────────────────────────
    // These exercise the pure `vti_core::editor` functions that back keyboard
    // note entry in the GUI pattern editor.  Running them through the CLI
    // harness keeps the tests independent of any UI framework.

    use vti_core::editor::{
        compute_note, hex_digit_entry, note_key_result, piano_key_to_semitone_offset, NoteKeyResult,
    };

    #[test]
    fn piano_layout_z_at_octave4_is_c4() {
        // z → C, octave 4 → note 36  (C-4 in VT2 1-based notation)
        let offset = piano_key_to_semitone_offset('z').expect("z should be a note key");
        let note = compute_note(offset, 4).expect("should be in range");
        assert_eq!(note, 36);
    }

    #[test]
    fn piano_layout_s_at_octave4_is_csharp4() {
        // s → C#, octave 4 → note 37
        let offset = piano_key_to_semitone_offset('s').unwrap();
        assert_eq!(compute_note(offset, 4), Some(37));
    }

    #[test]
    fn piano_layout_u_at_octave3_is_b4() {
        // u → B+1 (offset 23), octave 3 → 23 + (3-1)*12 = 23+24 = 47 = B-4
        assert_eq!(note_key_result('u', 3), Some(NoteKeyResult::Note(47)));
    }

    #[test]
    fn piano_layout_a_is_sound_off() {
        assert_eq!(note_key_result('a', 4), Some(NoteKeyResult::SoundOff));
    }

    #[test]
    fn piano_layout_k_clears_cell() {
        assert_eq!(note_key_result('k', 4), Some(NoteKeyResult::ClearCell));
    }

    #[test]
    fn piano_layout_out_of_range_returns_none() {
        // ] at octave 8 → offset 31 + 84 = 115 > 95
        assert_eq!(note_key_result(']', 8), None);
    }

    #[test]
    fn hex_entry_sample_shift_insert() {
        // Sample field (max=31): type '1' then '5' gives 0x15 = 21
        let after_1 = hex_digit_entry(0, 1, 31);
        assert_eq!(after_1, 1);
        let after_5 = hex_digit_entry(after_1, 5, 31);
        assert_eq!(after_5, 0x15); // 21
    }

    #[test]
    fn hex_entry_sample_clamps_to_max() {
        // type '2' then '0' → (0x2 << 4 | 0) = 32 > 31 → clamped to 31
        let after_2 = hex_digit_entry(0, 2, 31);
        let after_0 = hex_digit_entry(after_2, 0, 31);
        assert_eq!(after_0, 31);
    }

    #[test]
    fn hex_entry_volume_overwrites() {
        // Volume (max=15): each digit replaces the previous value entirely
        let v = hex_digit_entry(12, 7, 15);
        assert_eq!(v, 7);
    }

    #[test]
    fn hex_entry_effect_param_shift_insert() {
        // Effect parameter (max=255): type '3' then '7' gives 0x37 = 55
        let after_3 = hex_digit_entry(0, 3, 255);
        let after_7 = hex_digit_entry(after_3, 7, 255);
        assert_eq!(after_7, 0x37);
    }

    #[test]
    fn note_written_to_module_and_visible() {
        // Simulate writing a note into a module pattern via the core types
        // (i.e. what the GUI pattern editor does after resolving the key).
        let mut m = make_test_module();
        let note = compute_note(
            piano_key_to_semitone_offset('z').unwrap(), // C
            4,                                          // octave 4 → C-4 = 36
        )
        .unwrap();

        // Write the note to row 1, channel 0.
        m.patterns[0].as_mut().unwrap().items[1].channel[0].note = note;

        assert_eq!(m.patterns[0].as_ref().unwrap().items[1].channel[0].note, 36);
    }

    #[test]
    fn note_sound_off_written_to_module() {
        use vti_core::NOTE_SOUND_OFF;
        let mut m = make_test_module();
        m.patterns[0].as_mut().unwrap().items[2].channel[1].note = NOTE_SOUND_OFF;
        assert_eq!(
            m.patterns[0].as_ref().unwrap().items[2].channel[1].note,
            NOTE_SOUND_OFF
        );
    }

    #[test]
    fn hex_entry_round_trip_through_module_fields() {
        let mut m = make_test_module();
        let cell = &mut m.patterns[0].as_mut().unwrap().items[0].channel[0];

        // Sample: type '1' → 1, then '5' → 0x15 = 21
        cell.sample = hex_digit_entry(cell.sample, 1, 31);
        cell.sample = hex_digit_entry(cell.sample, 5, 31);
        assert_eq!(cell.sample, 21);

        // Ornament: type 'A' (=10) → ornament = 10
        cell.ornament = hex_digit_entry(cell.ornament, 10, 15);
        assert_eq!(cell.ornament, 10);

        // Volume: type 'F' (=15) → volume = 15
        cell.volume = hex_digit_entry(cell.volume, 15, 15);
        assert_eq!(cell.volume, 15);
    }
}
