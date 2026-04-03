//! Browser [File System Access API] bindings for WASM targets.
//!
//! Provides async helpers that open / save files via the browser's native
//! file-picker dialogs and ferry results back to the egui frame loop through
//! thread-local slots (`PENDING_OPEN`, `PENDING_SAVE_STATUS`).
//!
//! Callers (in `app.rs`) call [`spawn_open_file`] or [`spawn_save_file`] from
//! within a user-gesture handler (button click), then poll
//! [`take_pending_open`] / [`take_pending_save_status`] on each frame.
//!
//! [File System Access API]: https://developer.mozilla.org/en-US/docs/Web/API/File_System_Access_API

use std::cell::RefCell;

use js_sys::{Array, ArrayBuffer, Object, Promise, Reflect, Uint8Array};
use wasm_bindgen::prelude::*;
use wasm_bindgen::JsCast;
use wasm_bindgen_futures::JsFuture;

// ── extern "C" bindings ───────────────────────────────────────────────────────

#[wasm_bindgen]
extern "C" {
    /// A file handle returned by `showOpenFilePicker` / `showSaveFilePicker`.
    pub type FileSystemFileHandle;

    /// `FileSystemFileHandle.getFile()` → `Promise<File>`
    #[wasm_bindgen(method, js_name = getFile)]
    fn get_file(this: &FileSystemFileHandle) -> Promise;

    /// `FileSystemFileHandle.createWritable()` → `Promise<FileSystemWritableFileStream>`
    #[wasm_bindgen(method, js_name = createWritable)]
    fn create_writable(this: &FileSystemFileHandle) -> Promise;
}

#[wasm_bindgen]
extern "C" {
    /// A browser `File` object (extends `Blob`).
    pub type BrowserFile;

    /// `File.name` – the file's base name (e.g. `"song.pt3"`).
    #[wasm_bindgen(method, getter, js_name = name)]
    fn file_name(this: &BrowserFile) -> String;

    /// `File.arrayBuffer()` → `Promise<ArrayBuffer>`
    #[wasm_bindgen(method, js_name = arrayBuffer)]
    fn array_buffer(this: &BrowserFile) -> Promise;
}

#[wasm_bindgen]
extern "C" {
    /// A writable stream returned by `FileSystemFileHandle.createWritable()`.
    pub type FileSystemWritableFileStream;

    /// `FileSystemWritableFileStream.write(data)` → `Promise<undefined>`
    #[wasm_bindgen(method, js_name = write)]
    fn write_data(this: &FileSystemWritableFileStream, data: &JsValue) -> Promise;

    /// `FileSystemWritableFileStream.close()` → `Promise<undefined>`
    #[wasm_bindgen(method, js_name = close)]
    fn close_stream(this: &FileSystemWritableFileStream) -> Promise;
}

#[wasm_bindgen]
extern "C" {
    /// `window.showOpenFilePicker(options?)` → `Promise<FileSystemFileHandle[]>`
    ///
    /// The `catch` attribute makes the binding return `Result<Promise, JsValue>`
    /// so a missing API or user cancellation can be handled gracefully.
    #[wasm_bindgen(catch, js_name = showOpenFilePicker)]
    fn show_open_file_picker_raw(options: &JsValue) -> Result<Promise, JsValue>;

    /// `window.showSaveFilePicker(options?)` → `Promise<FileSystemFileHandle>`
    #[wasm_bindgen(catch, js_name = showSaveFilePicker)]
    fn show_save_file_picker_raw(options: &JsValue) -> Result<Promise, JsValue>;
}

// ── Pending-result channels ───────────────────────────────────────────────────

/// Data returned by a completed open-file operation.
pub struct PendingFile {
    pub name: String,
    pub bytes: Vec<u8>,
}

thread_local! {
    /// Written by the async open callback; drained by `App::update` each frame.
    static PENDING_OPEN: RefCell<Option<PendingFile>> = const { RefCell::new(None) };
    /// Written by the async save callback (success or error message).
    static PENDING_SAVE_STATUS: RefCell<Option<Result<String, String>>> =
        const { RefCell::new(None) };
}

/// Drain the pending open-file result (if any).  Call once per egui frame.
pub fn take_pending_open() -> Option<PendingFile> {
    PENDING_OPEN.with(|c| c.borrow_mut().take())
}

/// Drain the pending save-file status (if any).  Call once per egui frame.
pub fn take_pending_save_status() -> Option<Result<String, String>> {
    PENDING_SAVE_STATUS.with(|c| c.borrow_mut().take())
}

// ── Check browser support ─────────────────────────────────────────────────────

/// Returns `true` if `window.showOpenFilePicker` is available in this browser.
pub fn open_picker_supported() -> bool {
    Reflect::has(&js_sys::global(), &JsValue::from_str("showOpenFilePicker"))
        .unwrap_or(false)
}

/// Returns `true` if `window.showSaveFilePicker` is available in this browser.
pub fn save_picker_supported() -> bool {
    Reflect::has(&js_sys::global(), &JsValue::from_str("showSaveFilePicker"))
        .unwrap_or(false)
}

// ── Open ──────────────────────────────────────────────────────────────────────

/// Spawn an async task that opens the browser file picker, reads the chosen
/// file's bytes, and stores the result in `PENDING_OPEN` for the next frame.
///
/// Silently ignores `AbortError` (user pressed Cancel).
pub fn spawn_open_file() {
    wasm_bindgen_futures::spawn_local(async {
        match do_open_file().await {
            Ok(pf) => PENDING_OPEN.with(|c| *c.borrow_mut() = Some(pf)),
            Err(e) => {
                if !is_abort_error(&e) {
                    log::warn!("showOpenFilePicker error: {:?}", e);
                }
            }
        }
    });
}

async fn do_open_file() -> Result<PendingFile, JsValue> {
    let opts = build_open_options();
    let promise = show_open_file_picker_raw(&opts)?;
    let result = JsFuture::from(promise).await?;

    // result is `FileSystemFileHandle[]`
    let handles = Array::from(&result);
    let handle: FileSystemFileHandle = handles.get(0).unchecked_into();

    let file_val = JsFuture::from(handle.get_file()).await?;
    let file: BrowserFile = file_val.unchecked_into();
    let name = file.file_name();

    let buf_val = JsFuture::from(file.array_buffer()).await?;
    let buf: ArrayBuffer = buf_val.unchecked_into();
    let bytes = Uint8Array::new(&buf).to_vec();

    Ok(PendingFile { name, bytes })
}

fn build_open_options() -> JsValue {
    // { types: [{ description: "Tracker modules", accept: { "application/octet-stream": [".vtm", ".pt3"] } }], multiple: false }
    let exts = Array::new();
    exts.push(&JsValue::from_str(".vtm"));
    exts.push(&JsValue::from_str(".pt3"));

    let accept = Object::new();
    let _ = Reflect::set(&accept, &JsValue::from_str("application/octet-stream"), &exts);

    let type_entry = Object::new();
    let _ = Reflect::set(
        &type_entry,
        &JsValue::from_str("description"),
        &JsValue::from_str("Tracker modules"),
    );
    let _ = Reflect::set(&type_entry, &JsValue::from_str("accept"), &accept);

    let types_arr = Array::new();
    types_arr.push(&type_entry);

    let opts = Object::new();
    let _ = Reflect::set(&opts, &JsValue::from_str("types"), &types_arr);
    let _ = Reflect::set(&opts, &JsValue::from_str("multiple"), &JsValue::from_bool(false));
    opts.into()
}

// ── Save ──────────────────────────────────────────────────────────────────────

/// Spawn an async task that opens the browser save picker and writes `bytes`
/// to the chosen file.  Stores an `Ok(msg)` or `Err(msg)` in
/// `PENDING_SAVE_STATUS` (not set on user cancel).
pub fn spawn_save_file(suggested_name: String, bytes: Vec<u8>) {
    wasm_bindgen_futures::spawn_local(async move {
        match do_save_file(&suggested_name, &bytes).await {
            Ok(()) => {
                PENDING_SAVE_STATUS.with(|c| {
                    *c.borrow_mut() = Some(Ok(format!("Saved: {suggested_name}")));
                });
            }
            Err(e) => {
                if !is_abort_error(&e) {
                    let msg = e.as_string().unwrap_or_else(|| format!("{e:?}"));
                    PENDING_SAVE_STATUS.with(|c| {
                        *c.borrow_mut() = Some(Err(format!("Save failed: {msg}")));
                    });
                }
            }
        }
    });
}

async fn do_save_file(filename: &str, bytes: &[u8]) -> Result<(), JsValue> {
    let opts = build_save_options(filename);
    let promise = show_save_file_picker_raw(&opts)?;
    let handle_val = JsFuture::from(promise).await?;
    let handle: FileSystemFileHandle = handle_val.unchecked_into();

    let writable_val = JsFuture::from(handle.create_writable()).await?;
    let writable: FileSystemWritableFileStream = writable_val.unchecked_into();

    let js_bytes = Uint8Array::from(bytes);
    JsFuture::from(writable.write_data(&js_bytes.into())).await?;
    JsFuture::from(writable.close_stream()).await?;

    Ok(())
}

fn build_save_options(filename: &str) -> JsValue {
    // { suggestedName: filename, types: [{ description: "VTM text", accept: { "text/plain": [".vtm"] } }] }
    let exts = Array::new();
    exts.push(&JsValue::from_str(".vtm"));

    let accept = Object::new();
    let _ = Reflect::set(&accept, &JsValue::from_str("text/plain"), &exts);

    let type_entry = Object::new();
    let _ = Reflect::set(
        &type_entry,
        &JsValue::from_str("description"),
        &JsValue::from_str("VTM text"),
    );
    let _ = Reflect::set(&type_entry, &JsValue::from_str("accept"), &accept);

    let types_arr = Array::new();
    types_arr.push(&type_entry);

    let opts = Object::new();
    let _ = Reflect::set(&opts, &JsValue::from_str("suggestedName"), &JsValue::from_str(filename));
    let _ = Reflect::set(&opts, &JsValue::from_str("types"), &types_arr);
    opts.into()
}

// ── Helpers ───────────────────────────────────────────────────────────────────

/// Returns `true` if the JS error is an `AbortError` (user cancelled the picker).
fn is_abort_error(e: &JsValue) -> bool {
    Reflect::get(e, &JsValue::from_str("name"))
        .ok()
        .and_then(|v| v.as_string())
        .map(|s| s == "AbortError")
        .unwrap_or(false)
}
