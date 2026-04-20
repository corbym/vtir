# STORY-050: vti-audio Integration Tests (tests/integration_tests.rs)

**Type:** chore

## Goal

Describe what this story should accomplish.

## Acceptance criteria

- [x] `PlayerCommand` variant distinctness and Copy
- [x] `StereoSample` default silence and Copy
- [x] `AudioPlayer::start` + push (device-dependent, `#[ignore]`)
- [x] Fill level decreases over time (device-dependent, `#[ignore]`)
- [x] Diagnostics snapshot shows callback/push/pop activity after `AudioPlayer::start` (device-dependent, `#[ignore]`)

## Notes

<!-- backlog-mcp: 2026-04-20T19:26:41Z -->
All vti-audio integration tests passing including device-dependent tests marked #[ignore].
