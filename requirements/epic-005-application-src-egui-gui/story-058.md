# STORY-058: CLI Diagnostics Tool (src/bin/vti-cli.rs)

**Type:** feature

## Goal

Describe what this story should accomplish.

## Acceptance criteria

- [x] Terminal tracker viewer with keyboard navigation (rows/channels/positions)
- [x] Headless harness mode (`--ticks N`) for deterministic parser/playback/synth diagnostics
- [x] Integration test invokes CLI binary on `ADDAMS2.ay` and asserts non-zero PCM activity

## Notes

<!-- backlog-mcp: 2026-04-20T19:26:42Z -->
CLI diagnostics tool implemented with keyboard navigation, headless --ticks mode, and integration test on ADDAMS2.ay.
