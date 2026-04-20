# STORY-060: CI Workflows — tests, WASM check, Pages deploy, Pascal baselines

**Type:** chore

## Goal

Describe what this story should accomplish.

## Acceptance criteria

- [x] `build.yml` — tests + WASM check on all branches/PRs
- [x] `pages.yml` — web deploy to GitHub Pages on push to master or manually
- [x] `pascal-baselines.yml` — manual-only (`workflow_dispatch`): install `fpc`, run `pascal-tests/run_harness.sh`, open a PR with updated fixture files if changed

## Notes

<!-- backlog-mcp: 2026-04-20T19:26:42Z -->
build.yml, pages.yml, and pascal-baselines.yml CI workflows all in place and running.
