#![warn(clippy::nursery, clippy::pedantic)]

mod constants;
mod synthoverlay_utils;
mod usage_checks;

use std::fs;
use rfd::FileDialog;
use std::io::{self, Write};
use std::path::{Path, PathBuf};
use std::process::Command;
use usage_checks::{determine_game_version, is_patch_compatible, needs_synthoverlay};
use synthoverlay_utils::handle_synthoverlay;
use constants::{PATCH_DIRECTIVE, PREASSEMBLE_DIRECTIVE};

fn get_project_path() -> PathBuf {
    // Use rfd to open a file dialog and select the project path
    FileDialog::new()
        .set_title("Select unpacked ROM folder")
        .pick_folder()
        .map_or_else(
            || {
                println!("No folder selected, exiting.");
                std::process::exit(0);
            },
            |selected_folder| {
                println!("Selected folder: {}", selected_folder.display());
                selected_folder
            },
        )
}

fn get_patch_path(exe_dir: &Path, game_version: &str) -> PathBuf {
    println!("Please select the patch file to apply");

    let patches_dir = exe_dir.join("patches");

    // Use rfd to open a file dialog and select the project path
    FileDialog::new()
        .add_filter("Patch files", &["asm"])
        .set_title("Select Patch file")
        .set_directory(patches_dir.join(
            match game_version {
                "Platinum" => "PLAT",
                "HeartGold" | "SoulSilver" => "HG_SS",
                _ => {
                    panic!("Unknown game version: {game_version}.");
                }
            }
        ))
        .pick_file()
        .map_or_else(
            || {
                println!("No patch selected, exiting.");
                std::process::exit(0);
            },
            |selected_patch| {
                println!("\nSelected patch: {}", selected_patch.display());
                selected_patch
            },
        )
}

fn run_armips(asm_path: &str, rom_dir: &str, exe_dir: &Path, armips_directive: &str) -> io::Result<()> {
    let armips_path = exe_dir.join("assets").join("armips.exe");
    //println!("Using armips at: {}", armips_path.display());
    
    if armips_directive == PREASSEMBLE_DIRECTIVE { 
        println!("Calculating patch size...");
        Command::new(armips_path)
            .args([asm_path, "-definelabel", PREASSEMBLE_DIRECTIVE, "1"])
            .current_dir(rom_dir)
            .status()?;
    } else {
        println!("Patching ROM with armips...");
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

fn main() -> io::Result<()> {
    println!("Welcome to the Platinum/HGSS code injection patcher!\n\nMake sure to read the documentation for the patch you are trying to apply!\n\nPlease select your unpacked ROM folder");

    // Get the project path from the user
    let project_path = get_project_path().display().to_string();
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
    let patch_path = get_patch_path(&exe_dir, game_version).display().to_string();

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
