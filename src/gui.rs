use crate::constants::{PATCH_DIRECTIVE, PREASSEMBLE_DIRECTIVE};
use crate::filedialog::{get_patch_path, get_project_path};
use crate::run_armips;
use crate::synthoverlay_utils::handle_synthoverlay;
use crate::usage_checks::{determine_game_version, is_patch_compatible, needs_synthoverlay};
use eframe::egui;
use eframe::egui::{Color32, RichText};
use log::{debug, error, info, warn, Level, LevelFilter, Log, Metadata, Record};
use std::path::{Path, PathBuf};
use std::sync::{Mutex, OnceLock};
use std::{fs};

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
    project_path: Option<String>,
    patch: Option<String>,
    game_version: Option<String>,
    exe_dir: PathBuf,
}

impl Default for G4PatcherApp {
    fn default() -> Self {
        Self {
            project_path: None,
            patch: None,
            game_version: None,
            exe_dir: std::env::current_exe()
                .ok()
                .and_then(|p| p.parent().map(Path::to_path_buf))
                .unwrap_or_else(|| PathBuf::from(".")),
        }
    }
}

impl eframe::App for G4PatcherApp {
    fn update(&mut self, ctx: &egui::Context, _frame: &mut eframe::Frame) {
        egui::CentralPanel::default().show(ctx, |ui| {
            ui.heading("Pokemon Gen 4 Code Injection Patcher");
            ui.horizontal(|ui| {
                if ui.button("Select ROM Folder").clicked() {
                    if let Some(path) = get_project_path() {
                        self.project_path = Some(path.display().to_string());
                        self.game_version = match determine_game_version(&path.display().to_string()) {
                            Ok(version) => {
                                info!("Game version: {version}");
                                Some(version.to_string())
                            },
                            Err(e) => {
                                error!("Error determining game version: {e}\nPlease ensure you are selecting the ROM folder, usually called 'romname_DSPRE_contents.'");
                                self.project_path = None;
                                None
                            }
                        };
                    } else {self.project_path = None;}
                }
                ui.with_layout(egui::Layout::left_to_right(egui::Align::TOP).with_main_wrap(true), |ui| {
                    ui.label(RichText::new(self.project_path.clone()
                        .unwrap_or_else(|| "No ROM folder selected".to_string())));
                });
            });
            ui.horizontal(|ui| {
                let selectpatch_enabled = self.project_path.is_some();
                if ui.add_enabled(selectpatch_enabled, egui::Button::new("Select Patch")).clicked() {
                    if let Some(file) = get_patch_path(&self.exe_dir) {
                        self.patch = Some(file.display().to_string());
                        if !is_patch_compatible(&self.patch.clone().unwrap(), &self.project_path.clone().unwrap()) {
                            warn!("This patch is not compatible with this ROM, please select a compatible patch.");
                            self.patch = None;
                        }
                    } else {self.patch = None;}
                }
                ui.with_layout(egui::Layout::left_to_right(egui::Align::TOP).with_main_wrap(true), |ui| {
                    ui.label(RichText::new(self.patch.clone()
                        .unwrap_or_else(|| "No patch selected".to_string())));
                });
            });
            ui.horizontal(|ui| {
                let apply_enabled = self.project_path.is_some() && self.patch.is_some();
                if ui.add_enabled(apply_enabled, egui::Button::new("Apply Patch")).clicked() {
                    if needs_synthoverlay(&self.patch.clone().unwrap()) {
                        match run_armips(
                            &self.patch.clone().unwrap(),
                            &self.project_path.clone().unwrap(),
                            &self.exe_dir,
                            PREASSEMBLE_DIRECTIVE
                        ) {
                            Ok(()) => {
                                let patch_path = self.project_path.clone().unwrap();
                                match fs::metadata(format!("{}/temp.bin", patch_path)) {
                                    Ok(metadata) => {
                                        let patch_size = metadata.len() as usize;
                                        info!("Patch size: {patch_size} bytes");

                                        if let Err(e) = fs::remove_file(format!("{}/temp.bin", patch_path)) {
                                            error!("Failed to delete temp.bin: {e}");
                                            return;
                                        }

                                        match handle_synthoverlay(
                                            &self.patch.clone().unwrap(),
                                            &patch_path,
                                            &self.game_version.clone().unwrap(),
                                            patch_size
                                        ) {
                                            Ok(()) => debug!("SynthOverlay handled successfully."),
                                            Err(e) => {
                                                error!("Failed to handle synthOverlay: {e}");
                                                return;
                                            }
                                        }
                                    }
                                    Err(e) => {
                                        error!("Failed to read temp.bin: {e}");
                                        return;
                                    }
                                }
                            }
                            Err(e) => {
                                error!("Failed to preassemble patch: {e}");
                                return;
                            }
                        }
                    }

                    match run_armips(
                        &self.patch.clone().unwrap(),
                        &self.project_path.clone().unwrap(),
                        &self.exe_dir,
                        PATCH_DIRECTIVE
                    ) {
                        Ok(()) => {
                            debug!("armips ran successfully.");
                            info!("\nPatch applied! You can now repack your ROM.\n");
                        }
                        Err(e) => {
                            error!("Failed to apply patch: {}", e);
                        }
                    }
                }
            });
            ui.separator();
            ui.collapsing("Limitations", |ui| {
                ui.label("- Does not check if patch is already applied (may duplicate).");
                ui.label("- Does not verify overlay compression (ensure hook overlay is uncompressed).");
            });
            ui.label("Make sure to read the documentation for the patch you are applying!");
            ui.separator();
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
                                ui.label(RichText::new(format!("[{}] {}", entry.level, entry.message))
                                    .color(color));
                            }
                        });
                });
            });
        });
    }
}
