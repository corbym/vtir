# STORY-059: Custom On-Screen Keyboard for Mobile Web (ui/mobile_keyboard.rs) — WASM only

**Type:** feature

## Goal

Describe what this story should accomplish.

## Acceptance criteria

- [ ] Tapping a note cell shows the custom panel; OS QWERTY does not appear.
- [ ] Tapping a note button writes the correct note to the cell and advances the cursor by `step`.
- [ ] Tapping the Step DragValue still shows the OS numeric keyboard.
- [ ] The panel is absent on non-WASM (desktop native) builds.
- [ ] Covered by Jest tests (panel visibility toggle) and Rust unit tests (button → note mapping).
