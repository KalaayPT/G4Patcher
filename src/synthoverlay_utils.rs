#![warn(clippy::nursery, clippy::pedantic)]

use crate::constants::{GAME_DEPENDENT_OVERLAY_HG, GAME_DEPENDENT_OVERLAY_PLAT};
use crate::patcher::PatcherError;
use crate::usage_checks::is_arm9_expanded;
use log::info;
use std::io::{BufRead, BufReader};
use std::path::PathBuf;
use std::{fs, io};

/// Determine the game overlay based on the patch name.
///
/// # Arguments
/// * `patch_path`: A string slice that holds the path to the patch file.
///
/// # Returns
/// A string that represents the game-dependent overlay:
/// * `"0009"` for Pokémon Platinum
/// * `"0000"` for Pokémon HeartGold/SoulSilver
///
pub fn determine_game_overlay(patch_path: &str) -> &'static str {
    if patch_path.contains("_HG") {
        GAME_DEPENDENT_OVERLAY_HG
    } else if patch_path.contains("_PLAT") {
        GAME_DEPENDENT_OVERLAY_PLAT
    } else {
        panic!("Unknown game type in patch path: {patch_path}");
    }
}

/// Find the first aligned offset in the data where a block of `required_size` bytes is all zero.
///
/// # Arguments
/// * `data`: A slice of bytes representing the data to search through.
/// * `required_size`: The size of the block of bytes that must be all zero for a valid injection point.
///
/// # Returns
/// An `Option<usize>` that contains the offset of the first valid injection point if found, or `None` if no such point exists.
///
/// # Details
/// This function iterates through the `data` slice, checking every 16-byte aligned offset to see if the next `required_size` bytes are all zero. If it finds such a block, it returns the starting index of that block. If no such block is found, it returns `None`.
///
/// # Example
/// ```
/// let data = [0u8; 64]; // Example data with 64 bytes, all zero
/// let required_size = 16; // Looking for a block of 16 bytes
/// let offset = find_injection_offset(&data, required_size);
/// assert_eq!(offset, Some(0)); // The first 16 bytes are all zero, so the offset is 0
/// ```
pub fn find_injection_offset(data: &[u8], required_size: usize) -> Option<usize> {
    let mut i = 0;

    while i + required_size <= data.len() {
        if i % 0x10 == 0 {
            let window = &data[i..i + required_size];
            if window.iter().all(|&b| b == 0) {
                return Some(i);
            }
        }
        i += 1;
    }

    None
}

/// Insert a corrected offset into the assembly file at the specified path.
///
/// # Arguments
/// * `asm_path`: A string slice that holds the path to the assembly file.
/// * `new_addr`: A `u32` representing the new address to insert into the assembly file.
///
/// # Returns
/// A `Result<PathBuf, io::Error>` where:
/// * `Ok(PathBuf)` contains the path to the modified assembly file.
/// * `Err(io::Error)` indicates an error occurred while reading or writing the file.
///
/// # Details
/// This function reads the assembly file line by line, looking for a line that contains the string `"INJECT_ADDR equ"`. When it finds this line, it replaces it with a new line that sets `INJECT_ADDR` to the specified `new_addr`, formatted as a hexadecimal value. It then writes all lines back to the same file.
///
/// # Example Usage
/// ```rust
/// use synthoverlay_utils::insert_corrected_offset;
/// let asm_path = "path/to/your/asm_file.asm";
/// let new_addr = 0x12345678;
/// match insert_corrected_offset(asm_path, new_addr) {
///     Ok(path) => println!("Successfully updated assembly file at {:?}", path),
///     Err(e) => eprintln!("Error updating assembly file: {}", e),
/// }
/// ```
/// * Example assembly file content before modification:
/// ```asm
/// INJECT_ADDR equ 0x00000000
/// ```
/// * Example assembly file content after modification:
/// ```asm
/// INJECT_ADDR equ 0x12345678
/// ```
pub fn insert_corrected_offset(asm_path: &str, new_addr: u32) -> io::Result<PathBuf> {
    let input = BufReader::new(fs::File::open(asm_path)?);
    let mut lines: Vec<String> = Vec::new();

    for line in input.lines() {
        let mut line = line?;
        if line.contains("INJECT_ADDR equ") {
            line = format!("INJECT_ADDR equ 0x{new_addr:08X}");
        }
        lines.push(line);
    }

    let out_path = PathBuf::from(asm_path);
    fs::write(&out_path, lines.join("\n"))?;
    Ok(out_path)
}

/// Handle the synthOverlay process for the specified patch and project.
///
/// # Arguments
///
/// * `patch_path`: A string slice that holds the path to the patch file.
/// * `project_path`: A string slice that holds the path to the project directory.
/// * `game_version`: A string slice that holds the game version, which can be one of:
///     * `"Platinum"`
///     * `"HeartGold"`
///     * `"SoulSilver"`
///
/// # Returns
///
/// A `Result<(), io::Error>` where:
/// * `Ok(())` indicates the process completed successfully.
/// * `Err(io::Error)` indicates an error occurred during the process, such as file not found or read/write errors.
///
/// # Details
///
/// This function checks if the `arm9.bin` file has been expanded for the specified game version. If it has, it reads the `synthOverlay` file corresponding to the patch, finds the injection offset, and inserts a corrected offset into the assembly file specified by `patch_path`. If the `arm9.bin` is not expanded, it prompts the user to expand it before proceeding.
pub fn handle_synthoverlay(
    patch_path: &str,
    project_path: &str,
    game_version: &str,
    required_size: usize,
) -> Result<(), PatcherError> {
    if is_arm9_expanded(project_path, game_version).map_err(PatcherError::IoError)? {
        info!("arm9 is expanded, proceeding");
    } else {
        return Err(PatcherError::Arm9NotExpanded);
    }

    // Read and process the synthOverlay file
    let synth_overlay_path = format!(
        "{}\\unpacked\\synthOverlay\\{}",
        project_path,
        determine_game_overlay(patch_path)
    );
    let synth_overlay = fs::read(&synth_overlay_path).map_err(PatcherError::IoError)?;
    info!("Read synthOverlay file successfully. Located at: {synth_overlay_path}");

    info!("Searching for injection offset");
    let offset =
        find_injection_offset(&synth_overlay, required_size).ok_or(PatcherError::NoFreeSpace)?;
    info!(
        "Found injection offset at {:#X} in synthOverlay {}",
        offset,
        determine_game_overlay(patch_path)
    );

    let corrected_offset = 0x23c8000 + offset as u32;
    info!("Corrected offset: {corrected_offset:#X}");
    insert_corrected_offset(patch_path, corrected_offset).map_err(PatcherError::IoError)?;
    Ok(())
}
