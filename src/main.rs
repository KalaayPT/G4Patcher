#![warn(clippy::nursery, clippy::pedantic)]

mod constants;
mod synthoverlay_utils;
mod usage_checks;
mod filedialog;
mod gui;

use std::fs;
use std::io::{self, Write};
use std::path::{Path, PathBuf};
use std::process::Command;
use eframe::{egui};
use usage_checks::{determine_game_version, is_patch_compatible, needs_synthoverlay};
use synthoverlay_utils::handle_synthoverlay;
use constants::{PATCH_DIRECTIVE, PREASSEMBLE_DIRECTIVE};
use log::{error, info, warn};
use filedialog::{get_project_path, get_patch_path};
use crate::gui::{G4PatcherApp, GuiLogger};

fn run_armips(asm_path: &str, rom_dir: &str, exe_dir: &Path, armips_directive: &str) -> io::Result<()> {
    let armips_path = exe_dir.join("assets").join("armips.exe");
    if !armips_path.exists() {
        error!("armips executable not found at {}", armips_path.display());
        return Err(io::Error::new(io::ErrorKind::NotFound, "armips.exe not found"));
    }

    if armips_directive == PREASSEMBLE_DIRECTIVE { 
        info!("Calculating patch size...");
        Command::new(armips_path)
            .args([asm_path, "-definelabel", PREASSEMBLE_DIRECTIVE, "1"])
            .current_dir(rom_dir)
            .status()?;
    } else {
        info!("Patching ROM with armips...");
        Command::new(armips_path)
            .args([asm_path, "-definelabel", PATCH_DIRECTIVE, "1"])
            .current_dir(rom_dir)
            .status()?;
    }
    Ok(())
}

fn enter_to_exit() -> Result<(), io::Error> {
    println!("\nPress Enter to exit...");
    let _ = io::stdout().flush();
    let _ = io::stdin().read_line(&mut String::new());
    Ok(())
}

fn run_cli() -> io::Result<()> {
    println!("Welcome to the Platinum/HGSS code injection patcher!\n\nMake sure to read the documentation for the patch you are trying to apply!\n\nPlease select your unpacked ROM folder");

    // Get the project path from the user
    let project_path = match get_project_path() {
        Some(path) => path.display().to_string(),
        None => {
            println!("No project path selected, exiting.");
            return enter_to_exit();
        }
    };
    
    let game_version = match determine_game_version(&project_path) {
        Ok(version) => version,
        Err(e) => {
            println!("Error determining game version: {e}\nPlease ensure you are selecting the ROM folder, and not the \"unpacked\" folder within it.");
            enter_to_exit()?;
            return Ok(());
        }
    };
    println!("Game version: {game_version}");

    // Get the directory of the executable for the patch file and armips locations
    let exe_dir = std::env::current_exe()
        .ok()
        .and_then(|p| p.parent().map(Path::to_path_buf))
        .unwrap_or_else(|| PathBuf::from("."));

    // Get the selected patch file from the user
    let patch_path = get_patch_path(&exe_dir)
        .ok_or_else(|| io::Error::new(io::ErrorKind::NotFound, "No patch file selected"))?
        .display().to_string();

    // Check if the patch is compatible with the selected ROM
    if !is_patch_compatible(&patch_path, &project_path) {
        println!("This patch is not compatible with this ROM, please select a compatible patch.");
        return enter_to_exit();
    }

    if needs_synthoverlay(&patch_path) {
        // preassemble the patch to calculate the size from the created temp.bin
        if !matches!(run_armips(&patch_path, &project_path, &exe_dir, PREASSEMBLE_DIRECTIVE), Ok(())) {
            return enter_to_exit();
        }
        let patch_size = fs::metadata(format!("{project_path}/temp.bin"))
            .map_err(|e| io::Error::new(io::ErrorKind::NotFound, format!("Failed to read temp.bin: {}", e)))?
            .len() as usize;
        println!("Patch size: {patch_size} bytes");
        fs::remove_file(format!("{project_path}/temp.bin"))
            .map_err(|e| io::Error::new(io::ErrorKind::NotFound, format!("Failed to delete temp.bin: {e}")))?;
        handle_synthoverlay(&patch_path, &project_path, game_version, patch_size)?;
    }

    if matches!(run_armips(&patch_path, &project_path, &exe_dir, PATCH_DIRECTIVE), Ok(())) {
        println!("\narmips ran successfully, patch applied! You can now repack your ROM.\n");
    }

    enter_to_exit()
}

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

    //if let Err(e) = run_cli() {
    //    error!("An error occurred: {e}");
    //    return Err(e);
    //}
    //Ok(())
}

