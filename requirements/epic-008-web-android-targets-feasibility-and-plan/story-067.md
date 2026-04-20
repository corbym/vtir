# STORY-067: Web Target — Option B: KMP / Compose for Web

**Type:** feature

## Goal

Describe what this story should accomplish.

## Acceptance criteria

- [ ] Compile `vti-core` + `vti-ay` to WASM via `wasm-bindgen` in `vti-ffi`
- [ ] Write a Kotlin/Wasm wrapper (`vti-ffi-wasm`) that imports the WASM module via `@JsModule` and exposes a `VtiEngine` Kotlin class
- [ ] Write a Compose Multiplatform (Wasm target) UI in `apps/web-kmp/`
- [ ] Wire audio output through Kotlin's `kotlinx.coroutines` + a JS `AudioContext` interop helper
