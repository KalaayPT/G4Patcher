use crate::filedialog::{get_patch_path, get_project_path};
use crate::patcher::PatcherCore;
use eframe::egui;
use eframe::egui::{Color32, RichText};
use log::{debug, error, info, warn, Level, LevelFilter, Log, Metadata, Record};
use std::path::Path;
use std::sync::{Mutex, OnceLock};

pub struct GuiLogger {
    log_buffer: Mutex<Vec<LogEntry>>,
}

#[derive(Clone)]
pub struct LogEntry {
    pub level: Level,
    pub message: String,
}

static LOGGER: OnceLock<GuiLogger> = OnceLock::new();

impl Log for GuiLogger {
    fn enabled(&self, _: &Metadata) -> bool {
        true
    }

    fn log(&self, record: &Record) {
        if self.enabled(record.metadata()) {
            let mut buffer = self.log_buffer.lock().unwrap();
            buffer.push(LogEntry {
                level: record.level(),
                message: format!("{}", record.args()),
            });
        }
    }

    fn flush(&self) {}
}

impl GuiLogger {
    pub fn get_logs() -> Vec<LogEntry> {
        LOGGER
            .get()
            .map(|l| l.log_buffer.lock().unwrap().clone())
            .unwrap_or_default()
    }

    pub fn init(max_level: LevelFilter) {
        LOGGER
            .set(Self {
                log_buffer: Mutex::new(Vec::new()),
            })
            .ok();
        log::set_logger(LOGGER.get().unwrap()).unwrap();
        log::set_max_level(max_level);
    }
}

pub struct G4PatcherApp {
    core: PatcherCore,
}

impl Default for G4PatcherApp {
    fn default() -> Self {
        let exe_dir = std::env::current_exe()
            .ok()
            .and_then(|p| p.parent().map(Path::to_path_buf))
            .unwrap_or_else(|| std::path::PathBuf::from("."));

        Self {
            core: PatcherCore::new(exe_dir),
        }
    }
}

impl eframe::App for G4PatcherApp {
    fn update(&mut self, ctx: &egui::Context, _frame: &mut eframe::Frame) {
        egui::CentralPanel::default().show(ctx, |ui| {
            ui.heading("Pokemon Gen 4 Code Injection Patcher");

            // ROM Folder Selection
            ui.horizontal(|ui| {
                if ui.button("Select ROM Folder").clicked() {
                    if let Some(path) = get_project_path() {
                        match self.core.set_rom_folder(path) {
                            Ok(version) => {
                                info!("Game version detected: {}", version.as_str());
                            }
                            Err(e) => {
                                error!("{}", e);
                            }
                        }
                    }
                }

                ui.with_layout(
                    egui::Layout::left_to_right(egui::Align::TOP).with_main_wrap(true),
                    |ui| {
                        let display_text = self
                            .core
                            .rom_path()
                            .and_then(|p| p.to_str())
                            .unwrap_or("No ROM folder selected");
                        ui.label(RichText::new(display_text));

                        // Display game version if detected
                        if let Some(version) = self.core.game_version() {
                            ui.label(
                                RichText::new(format!("({})", version.as_str()))
                                    .color(Color32::LIGHT_GREEN),
                            );
                        }
                    },
                );
            });

            // Patch Selection
            ui.horizontal(|ui| {
                let select_patch_enabled = self.core.rom_path().is_some();

                if ui
                    .add_enabled(select_patch_enabled, egui::Button::new("Select Patch"))
                    .clicked()
                {
                    if let Some(exe_dir) = std::env::current_exe()
                        .ok()
                        .and_then(|p| p.parent().map(Path::to_path_buf))
                    {
                        if let Some(patch_path) = get_patch_path(&exe_dir) {
                            match self.core.set_patch(patch_path) {
                                Ok(()) => {}
                                Err(e) => {
                                    warn!("{}", e);
                                }
                            }
                        }
                    }
                }

                ui.with_layout(
                    egui::Layout::left_to_right(egui::Align::TOP).with_main_wrap(true),
                    |ui| {
                        let display_text = self
                            .core
                            .patch_path()
                            .and_then(|p| p.to_str())
                            .unwrap_or("No patch selected");
                        ui.label(RichText::new(display_text));
                    },
                );
            });

            // Apply Patch Button
            ui.horizontal(|ui| {
                let apply_enabled = self.core.is_ready();

                if ui
                    .add_enabled(apply_enabled, egui::Button::new("Apply Patch"))
                    .clicked()
                {
                    match self.core.apply_patch() {
                        Ok(()) => {
                            debug!("Patch applied successfully");
                        }
                        Err(e) => {
                            error!("Failed to apply patch: {}", e);
                        }
                    }
                }
            });

            ui.separator();

            // Limitations
            ui.collapsing("Limitations", |ui| {
                ui.label("- Does not check if patch is already applied (may duplicate).");
                ui.label(
                    "- Does not verify overlay compression (ensure hook overlay is uncompressed).",
                );
            });

            ui.label("Make sure to read the documentation for the patch you are applying!");

            ui.separator();

            // Log Display
            ui.with_layout(egui::Layout::top_down_justified(egui::Align::LEFT), |ui| {
                ui.group(|ui| {
                    ui.label("Log:");
                    egui::ScrollArea::vertical()
                        .max_height(ui.available_height())
                        .stick_to_bottom(true)
                        .show(ui, |ui| {
                            for entry in GuiLogger::get_logs() {
                                let color = match entry.level {
                                    Level::Error => Color32::LIGHT_RED,
                                    Level::Warn => Color32::YELLOW,
                                    Level::Info => Color32::WHITE,
                                    Level::Debug => Color32::LIGHT_BLUE,
                                    Level::Trace => Color32::GREEN,
                                };
                                ui.label(
                                    RichText::new(format!("[{}] {}", entry.level, entry.message))
                                        .color(color),
                                );
                            }
                        });
                });
            });
        });
    }
}
