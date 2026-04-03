//! Vortex Tracker II — Rust port
//!
//! Original Delphi/Pascal application by Sergey Bulba (c) 2000-2009
//! <vorobey@mail.khstu.ru> — http://bulba.untergrund.net/
//!
//! This Rust port is a work in progress. See PLAN.md for the full backlog.

#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

mod app;
mod ui;

fn main() -> anyhow::Result<()> {
    env_logger::init();

    let options = eframe::NativeOptions {
        viewport: egui::ViewportBuilder::default()
            .with_title("Vortex Tracker II")
            .with_inner_size([1024.0, 768.0])
            .with_min_inner_size([640.0, 480.0]),
        ..Default::default()
    };

    eframe::run_native(
        "Vortex Tracker II",
        options,
        Box::new(|cc| Ok(Box::new(app::VortexTrackerApp::new(cc)))),
    )
    .map_err(|e| anyhow::anyhow!("eframe error: {e}"))
}
