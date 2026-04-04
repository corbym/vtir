//! Cross-platform audio player.
//!
//! Replaces `WaveOutAPI.pas` (c) 2000-2009 S.V.Bulba.
//!
//! Architecture:
//!  - `AudioPlayer::start` opens a cpal output stream.
//!  - The cpal data-callback pulls stereo-i16 samples from a ring buffer.
//!  - A separate render thread calls `Synthesizer::render_frame` each interrupt
//!    period and pushes samples into the ring buffer.
//!
//! # Status
//! Core cpal stream setup and the ring buffer are implemented.
//! The render thread integration with the tracker engine is **TODO** — see
//! PLAN.md §4.

use anyhow::{Context, Result};
use cpal::traits::{DeviceTrait, HostTrait, StreamTrait};
use cpal::{SampleRate, StreamConfig};
use std::sync::atomic::{AtomicU64, Ordering};
use std::sync::{Arc, Mutex};
use vti_ay::synth::StereoSample;

/// Commands sent to the player from the UI thread.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum PlayerCommand {
    Play,
    Pause,
    Stop,
}

/// Snapshot of audio callback and ring-buffer activity.
#[derive(Debug, Clone, Copy, Default, PartialEq, Eq)]
pub struct AudioDiagnostics {
    pub pushed_samples: u64,
    pub popped_samples: u64,
    pub underrun_frames: u64,
    pub callback_count: u64,
}

#[derive(Default)]
struct AudioDiagnosticsInner {
    pushed_samples: AtomicU64,
    popped_samples: AtomicU64,
    underrun_frames: AtomicU64,
    callback_count: AtomicU64,
}

impl AudioDiagnosticsInner {
    fn snapshot(&self) -> AudioDiagnostics {
        AudioDiagnostics {
            pushed_samples: self.pushed_samples.load(Ordering::Relaxed),
            popped_samples: self.popped_samples.load(Ordering::Relaxed),
            underrun_frames: self.underrun_frames.load(Ordering::Relaxed),
            callback_count: self.callback_count.load(Ordering::Relaxed),
        }
    }
}

/// Shared ring buffer between the render thread and the cpal callback.
struct RingBuf {
    data: Vec<StereoSample>,
    write: usize,
    read: usize,
    capacity: usize,
}

impl RingBuf {
    fn new(capacity: usize) -> Self {
        Self {
            data: vec![StereoSample::default(); capacity],
            write: 0,
            read: 0,
            capacity,
        }
    }

    #[inline]
    fn push(&mut self, s: StereoSample) {
        let next = (self.write + 1) % self.capacity;
        if next != self.read {
            self.data[self.write] = s;
            self.write = next;
        }
        // silently drop if full
    }

    #[inline]
    fn pop(&mut self) -> Option<StereoSample> {
        if self.read == self.write {
            return None;
        }
        let s = self.data[self.read];
        self.read = (self.read + 1) % self.capacity;
        Some(s)
    }
}

/// Cross-platform audio player.
pub struct AudioPlayer {
    _stream: cpal::Stream,
    buf: Arc<Mutex<RingBuf>>,
    diagnostics: Arc<AudioDiagnosticsInner>,
}

impl AudioPlayer {
    /// Open a cpal output stream at the given sample rate.
    ///
    /// Returns an `AudioPlayer` whose ring buffer can be filled by calling
    /// `push_samples`.
    pub fn start(sample_rate: u32) -> Result<Self> {
        let host = cpal::default_host();
        let device = host
            .default_output_device()
            .context("no default audio output device")?;

        let config = StreamConfig {
            channels: 2,
            sample_rate: SampleRate(sample_rate),
            buffer_size: cpal::BufferSize::Default,
        };

        // Ring buffer large enough for ~500 ms at 44100 Hz stereo.
        let ring_capacity = (sample_rate as usize) / 2 + 1;
        let buf = Arc::new(Mutex::new(RingBuf::new(ring_capacity)));
        let buf_cb = Arc::clone(&buf);
        let diagnostics = Arc::new(AudioDiagnosticsInner::default());
        let diagnostics_cb = Arc::clone(&diagnostics);

        let stream = device
            .build_output_stream(
                &config,
                move |output: &mut [f32], _| {
                    let mut ring = buf_cb.lock().unwrap();
                    diagnostics_cb.callback_count.fetch_add(1, Ordering::Relaxed);
                    for frame in output.chunks_exact_mut(2) {
                        let s = if let Some(s) = ring.pop() {
                            diagnostics_cb.popped_samples.fetch_add(1, Ordering::Relaxed);
                            s
                        } else {
                            diagnostics_cb.underrun_frames.fetch_add(1, Ordering::Relaxed);
                            StereoSample::default()
                        };
                        frame[0] = s.left  as f32 / 32768.0;
                        frame[1] = s.right as f32 / 32768.0;
                    }
                },
                |err| log::error!("audio stream error: {err}"),
                None,
            )
            .context("failed to build output stream")?;

        stream.play().context("failed to start audio stream")?;

        Ok(Self {
            _stream: stream,
            buf,
            diagnostics,
        })
    }

    /// Push a batch of rendered samples into the ring buffer.
    pub fn push_samples(&self, samples: &[StereoSample]) {
        let mut ring = self.buf.lock().unwrap();
        for &s in samples {
            ring.push(s);
        }
        self.diagnostics
            .pushed_samples
            .fetch_add(samples.len() as u64, Ordering::Relaxed);
    }

    /// Return approximate fill level of the ring buffer (0.0 – 1.0).
    pub fn fill_level(&self) -> f32 {
        let ring = self.buf.lock().unwrap();
        let used = (ring.write + ring.capacity - ring.read) % ring.capacity;
        used as f32 / ring.capacity as f32
    }

    /// Return a snapshot of callback and ring-buffer counters for diagnostics.
    pub fn diagnostics_snapshot(&self) -> AudioDiagnostics {
        self.diagnostics.snapshot()
    }
}
