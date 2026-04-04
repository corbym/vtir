//! Integration tests for vti-audio: ring buffer, player construction.
//!
//! Note: tests that actually open an audio device are gated behind the
//! `audio_device` feature flag so they can be skipped in headless CI.

use vti_audio::player::PlayerCommand;
use vti_ay::synth::StereoSample;

// ─── PlayerCommand ────────────────────────────────────────────────────────────

#[test]
fn player_command_variants_are_distinct() {
    assert_ne!(PlayerCommand::Play, PlayerCommand::Stop);
    assert_ne!(PlayerCommand::Pause, PlayerCommand::Stop);
    assert_ne!(PlayerCommand::Play, PlayerCommand::Pause);
}

#[test]
fn player_command_copy() {
    let cmd = PlayerCommand::Play;
    let cmd2 = cmd; // Copy
    assert_eq!(cmd, cmd2);
}

// ─── StereoSample ─────────────────────────────────────────────────────────────

#[test]
fn stereo_sample_default_is_silent() {
    let s = StereoSample::default();
    assert_eq!(s.left, 0);
    assert_eq!(s.right, 0);
}

#[test]
fn stereo_sample_copy() {
    let s = StereoSample { left: 100, right: -200 };
    let s2 = s;
    assert_eq!(s2.left, 100);
    assert_eq!(s2.right, -200);
}

// ─── AudioPlayer (device-dependent, gated) ────────────────────────────────────

/// These tests require a real audio device. Run with:
///   cargo test -p vti-audio -- --ignored
#[test]
#[ignore]
fn audio_player_starts_and_accepts_samples() {
    let player = vti_audio::AudioPlayer::start(44100)
        .expect("failed to open audio device");

    let samples: Vec<StereoSample> = (0..1024)
        .map(|i| StereoSample {
            left: ((i as f32 * 0.1).sin() * 16000.0) as i16,
            right: ((i as f32 * 0.1).cos() * 16000.0) as i16,
        })
        .collect();

    player.push_samples(&samples);
    let fill = player.fill_level();
    assert!(fill > 0.0, "ring buffer should have data after push");

    // Let the stream drain a bit
    std::thread::sleep(std::time::Duration::from_millis(200));
}

#[test]
#[ignore]
fn audio_player_fill_level_decreases_over_time() {
    let player = vti_audio::AudioPlayer::start(44100)
        .expect("failed to open audio device");

    let samples: Vec<StereoSample> = vec![StereoSample { left: 1000, right: 1000 }; 44100];
    player.push_samples(&samples);

    let fill_before = player.fill_level();
    std::thread::sleep(std::time::Duration::from_millis(500));
    let fill_after = player.fill_level();

    assert!(
        fill_after < fill_before,
        "fill level should decrease as cpal drains samples: before={fill_before} after={fill_after}"
    );
}

#[test]
#[ignore]
fn audio_player_diagnostics_show_callback_activity() {
    let player = vti_audio::AudioPlayer::start(44100)
        .expect("failed to open audio device");

    let before = player.diagnostics_snapshot();
    let samples: Vec<StereoSample> = vec![StereoSample { left: 1200, right: -1200 }; 22050];
    player.push_samples(&samples);

    std::thread::sleep(std::time::Duration::from_millis(300));

    let after = player.diagnostics_snapshot();
    assert!(after.callback_count > before.callback_count, "audio callback should run after start");
    assert!(after.pushed_samples >= before.pushed_samples + samples.len() as u64, "push counter should advance");
    assert!(after.popped_samples > before.popped_samples, "callback should consume at least some samples");
}

