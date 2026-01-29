#![windows_subsystem = "windows"]
#![warn(clippy::nursery)]

mod armips_ffi;
mod constants;
mod filedialog;
mod gui;
mod patcher;
mod synthoverlay_utils;
mod usage_checks;

use crate::gui::{G4PatcherApp, GuiLogger};
use eframe::egui;

fn main() -> eframe::Result {
    GuiLogger::init(log::LevelFilter::Info);

    let options = eframe::NativeOptions {
        viewport: egui::ViewportBuilder::default()
            .with_inner_size([640.0, 400.0])
            .with_drag_and_drop(true),
        ..Default::default()
    };
    eframe::run_native(
        "G4Patcher",
        options,
        Box::new(|_cc| Ok(Box::<G4PatcherApp>::default())),
    )
}
