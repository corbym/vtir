# STORY-068: Android Target — Rust shared libraries, UniFFI bindings, KMP UI, build pipeline

**Type:** feature

## Goal

Describe what this story should accomplish.

## Acceptance criteria

- [ ] Add Android NDK targets to the workspace (aarch64-linux-android, armv7-linux-androideabi, x86_64-linux-android, i686-linux-android)
- [ ] Install `cargo-ndk` (builds all targets and copies `.so` files into the correct `jniLibs/` tree)
- [ ] Enable `cpal`'s AAudio backend (cpal ≥ 0.15 supports AAudio on Android API 26+); ensure it compiles
- [ ] Verify `vti-ffi` builds as a `cdylib` for Android targets
- [ ] Run `uniffi-bindgen generate vti.udl --language kotlin` to produce `VtiCore.kt` and a JNI loader
- [ ] Add the generated Kotlin sources to the Android module's source set
- [ ] Keep the generated files out of version control; regenerate in the Gradle build via a `generateUniFFIBindings` task
- [ ] Scaffold a new Compose Multiplatform project targeting Android
- [ ] Implement `PatternEditorScreen` — pattern grid, note/sample/ornament/volume columns
- [ ] Implement `SampleEditorScreen`
- [ ] Implement `OrnamentEditorScreen`
- [ ] Implement `PositionListScreen`
- [ ] Implement `OptionsScreen`
- [ ] Implement a `VtiViewModel` (using `ViewModel` + `StateFlow`) that calls `vti-ffi` and drives the synthesizer render loop on a `Dispatchers.Default` coroutine
- [ ] Wire audio output: use Android's `AudioTrack` (or `cpal` on the Rust side) streaming 16-bit stereo PCM from the render loop
- [ ] File open: Android `Intent.ACTION_OPEN_DOCUMENT` → pass bytes to `vti_ffi::load_module()`
- [ ] `release.yml` Android job: `cargo ndk -t arm64-v8a -t armeabi-v7a build --release` → `./gradlew assembleRelease`
- [ ] Upload unsigned `.apk` as a release artifact
- [ ] (Optional) Sign with a release keystore stored as a GitHub Actions secret
