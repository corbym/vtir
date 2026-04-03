//! Cross-platform pending-file channel.
//!
//! Holds the results produced by the async WASM file operations
//! (`wasm_file::spawn_open_file`, `wasm_file::spawn_save_file`) and lets the
//! synchronous egui frame loop drain them once per frame via
//! [`take_pending_open`] / [`take_pending_save_status`].
//!
//! Because this module contains no WASM-specific code it compiles on **all**
//! targets, which allows the channel logic and its tests to run with plain
//! `cargo test` without a browser.

use std::cell::RefCell;

// ── Data types ────────────────────────────────────────────────────────────────

/// A file that was successfully read by the browser's open-file picker.
pub struct PendingFile {
    /// The base name reported by the browser (e.g. `"song.pt3"`).
    pub name: String,
    /// Raw bytes of the file contents.
    pub bytes: Vec<u8>,
}

// ── Thread-local channels ─────────────────────────────────────────────────────

thread_local! {
    /// Written by the async open callback; drained by `App::update` each frame.
    static PENDING_OPEN: RefCell<Option<PendingFile>> = const { RefCell::new(None) };

    /// Written by the async save callback.
    /// `Ok(msg)` on success, `Err(msg)` on failure.  Not set on user cancel.
    static PENDING_SAVE_STATUS: RefCell<Option<Result<String, String>>> =
        const { RefCell::new(None) };
}

// ── Public drains (called from App::update each frame) ────────────────────────

/// Take the pending open-file result, if any.  Clears the slot.
pub fn take_pending_open() -> Option<PendingFile> {
    PENDING_OPEN.with(|c| c.borrow_mut().take())
}

/// Take the pending save-file status, if any.  Clears the slot.
pub fn take_pending_save_status() -> Option<Result<String, String>> {
    PENDING_SAVE_STATUS.with(|c| c.borrow_mut().take())
}

// ── Internal writers (called from wasm_file only) ─────────────────────────────

/// Store an open-file result so it is picked up on the next frame.
pub(crate) fn put_pending_open(pf: PendingFile) {
    PENDING_OPEN.with(|c| *c.borrow_mut() = Some(pf));
}

/// Store a save-file status so it is picked up on the next frame.
pub(crate) fn put_pending_save_status(result: Result<String, String>) {
    PENDING_SAVE_STATUS.with(|c| *c.borrow_mut() = Some(result));
}

// ── Tests ─────────────────────────────────────────────────────────────────────

#[cfg(test)]
mod tests {
    use super::*;

    // Helpers that clear state left over from a previous test.  The
    // thread-locals are shared across all tests that run on the same OS thread,
    // so each test must drain the slot before writing to guarantee independence.
    fn drain_open()   { let _ = take_pending_open(); }
    fn drain_save()   { let _ = take_pending_save_status(); }

    // ── take_pending_open ────────────────────────────────────────────────────

    #[test]
    fn take_pending_open_returns_none_when_empty() {
        drain_open();
        assert!(take_pending_open().is_none());
    }

    #[test]
    fn take_pending_open_returns_value_after_put() {
        drain_open();
        put_pending_open(PendingFile {
            name:  "test.pt3".to_string(),
            bytes: vec![0xDE, 0xAD],
        });
        let pf = take_pending_open().expect("should have a value");
        assert_eq!(pf.name, "test.pt3");
        assert_eq!(pf.bytes, vec![0xDE, 0xAD]);
    }

    #[test]
    fn take_pending_open_clears_slot() {
        drain_open();
        put_pending_open(PendingFile {
            name:  "song.vtm".to_string(),
            bytes: vec![1, 2, 3],
        });
        let _ = take_pending_open(); // first drain
        assert!(take_pending_open().is_none(), "slot should be empty after drain");
    }

    #[test]
    fn put_pending_open_overwrites_previous_value() {
        drain_open();
        put_pending_open(PendingFile { name: "a.pt3".to_string(), bytes: vec![1] });
        put_pending_open(PendingFile { name: "b.pt3".to_string(), bytes: vec![2] });
        let pf = take_pending_open().expect("should have a value");
        assert_eq!(pf.name, "b.pt3", "second put should overwrite the first");
        assert!(take_pending_open().is_none());
    }

    // ── take_pending_save_status ─────────────────────────────────────────────

    #[test]
    fn take_pending_save_status_returns_none_when_empty() {
        drain_save();
        assert!(take_pending_save_status().is_none());
    }

    #[test]
    fn take_pending_save_status_ok() {
        drain_save();
        put_pending_save_status(Ok("Saved: module.vtm".to_string()));
        let result = take_pending_save_status().expect("should have a value");
        assert_eq!(result, Ok("Saved: module.vtm".to_string()));
    }

    #[test]
    fn take_pending_save_status_err() {
        drain_save();
        put_pending_save_status(Err("Save failed: disk full".to_string()));
        let result = take_pending_save_status().expect("should have a value");
        assert_eq!(result, Err("Save failed: disk full".to_string()));
    }

    #[test]
    fn take_pending_save_status_clears_slot() {
        drain_save();
        put_pending_save_status(Ok("Saved: x.vtm".to_string()));
        let _ = take_pending_save_status();
        assert!(take_pending_save_status().is_none(), "slot should be empty after drain");
    }

    // ── Integration: open-result through formats::load ───────────────────────
    //
    // Verifies the full pipeline: bytes → PendingFile → take_pending_open →
    // formats::load → valid Module.  Uses a minimal hand-crafted VTM payload so
    // the test has no external file dependency.

    #[test]
    fn pending_open_bytes_parse_to_module() {
        drain_open();

        // Minimal valid VTM text (required fields only; see formats/vtm.rs).
        let vtm = "[Module]\n\
                   Title=Test\n\
                   Author=\n\
                   NoteTable=0\n\
                   Speed=6\n\
                   PlayOrder=L0,0\n\
                   [Pattern0]\n\
                   [End]\n";

        put_pending_open(PendingFile {
            name:  "test.vtm".to_string(),
            bytes: vtm.as_bytes().to_vec(),
        });

        let pf = take_pending_open().expect("should have result");
        let result = vti_core::formats::load(&pf.bytes, &pf.name);
        assert!(result.is_ok(), "valid VTM bytes should parse without error: {result:?}");
        let module = result.unwrap();
        assert_eq!(module.title, "Test");
    }

    #[test]
    fn pending_open_invalid_bytes_returns_parse_error() {
        drain_open();

        put_pending_open(PendingFile {
            name:  "junk.vtm".to_string(),
            bytes: b"this is not a valid module".to_vec(),
        });

        let pf = take_pending_open().expect("should have result");
        let result = vti_core::formats::load(&pf.bytes, &pf.name);
        assert!(result.is_err(), "invalid bytes should return an error");
    }
}
