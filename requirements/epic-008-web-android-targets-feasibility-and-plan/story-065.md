# STORY-065: New Crate: crates/vti-ffi — FFI / binding layer

**Type:** feature

## Goal

Describe what this story should accomplish.

## Acceptance criteria

- [ ] Add `crates/vti-ffi` to the workspace
- [ ] Add `uniffi` as a build dependency (generates Kotlin & Swift bindings from a `.udl` interface file)
- [ ] Define a `vti.udl` interface covering: `load_module(bytes: sequence<u8>) -> Module`, `Engine::new(module: Module) -> Engine`, `Engine::tick() -> AyRegisters`, `Engine::reset()`, `module_title(module: Module) -> string`, `module_author(module: Module) -> string`, `module_position_count(module: Module) -> u32`
- [ ] Add `wasm-bindgen` feature flag for WASM target (exports the same API as JS-callable functions instead of JNI)
- [ ] Unit-test the FFI surface with the existing PT3 fixtures
