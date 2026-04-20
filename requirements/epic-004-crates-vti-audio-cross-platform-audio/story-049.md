# STORY-049: Player (player.rs) — replaces WaveOutAPI.pas

**Type:** chore

## Goal

Describe what this story should accomplish.

## Acceptance criteria

- [x] `PlayerCommand` enum (Play / Pause / Stop)
- [x] `RingBuf` — lock-based ring buffer (push / pop)
- [x] `AudioPlayer::start()` — open cpal stereo-i16 output stream
- [x] `AudioPlayer::push_samples()` — feed rendered samples into ring
- [x] `AudioPlayer::fill_level()` — approximate fill ratio
- [x] Render loop — 50 Hz tick timer in `eframe::App::update` calls `tick_audio()`, which runs `render_frame_quality()` and pushes samples via `AudioPlayer::push_samples()`; `AudioPlayer` opened lazily on first Play press (satisfies browser autoplay policy on WASM)
- [x] Play/Pause/Stop from UI thread — driven by `PlaybackState` enum transitions in `app.rs`; Stop resets position, Pause silences the AY chip, resume restores tick timer without a catch-up burst
- [x] `IsPlaying` / `Real_End` signalling back to UI — `PlaybackState::Playing` drives repaint and status-bar position/time display; `PlayResult::ModuleLoop` handled in `tick_audio()`
- [ ] Export to WAV file (replacing the existing export path)
