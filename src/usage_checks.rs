#![warn(clippy::nursery, clippy::pedantic)]

use crate::constants::{
    HEARTGOLD, HEARTGOLD_CODE, PLATINUM, PLATINUM_CODE, SOULSILVER, SOULSILVER_CODE,
};
use log::error;
use std::io::{BufRead, BufReader, Read, Seek, SeekFrom};
use std::path::{Path, PathBuf};
use std::{fs, io};

/// Determine the game version based on the header.yaml file in the project path.
///
/// # Arguments
/// * `project_path`: A path that holds the directory where `header.yaml` is located.
///
/// # Returns
/// A string representing the game version, which can be one of:
/// * `"Platinum"`
/// * `"HeartGold"`
/// * `"SoulSilver"`
///
/// # Details
/// This function:
/// * Constructs the path to `header.yaml` by appending it to the provided `project_path`.
/// * Opens the `header.yaml` file and reads lines to find the `gamecode` property.
/// * Compares the game code against predefined constants for each game version.
/// * If the code matches, it returns the corresponding game version.
/// * If the code does not match any known version, it returns an error indicating the unknown version.
pub fn determine_game_version(project_path: &Path) -> io::Result<String> {
    let header_path = project_path.join("header.yaml");

    let file = fs::File::open(&header_path).map_err(|_| {
        io::Error::new(io::ErrorKind::NotFound, "header.yaml not found")
    })?;

    let reader = BufReader::new(file);
    for line in reader.lines() {
        let line = line?;
        let line = line.trim();
        if let Some(code) = line.strip_prefix("gamecode:") {
            let code = code.trim();
            return match code {
                PLATINUM_CODE => Ok(PLATINUM.to_string()),
                HEARTGOLD_CODE => Ok(HEARTGOLD.to_string()),
                SOULSILVER_CODE => Ok(SOULSILVER.to_string()),
                _ => {
                    error!("Unknown game version in header.yaml at path: {}\nGame code found: {}",
                           header_path.display(), code);
                    Err(io::Error::new(io::ErrorKind::InvalidData, "Unknown game version in header.yaml"))
                }
            };
        }
    }

    Err(io::Error::new(io::ErrorKind::InvalidData, "gamecode not found in header.yaml"))
}

/// Check if the patch is compatible with the project based on the game version.
///
/// # Arguments
/// * `patch_path`: A string slice that holds the path to the patch file.
/// * `project_path`: A path that holds the project directory.
///
/// # Returns
/// A boolean value indicating whether the patch is compatible with the project:
/// * `true` if the patch is compatible with the game version of the project.
/// * `false` if the patch is not compatible.
///
/// # Details
/// This function:
/// * Calls `determine_game_version` to get the game version based on the `header.yaml` file in the project path.
/// * Checks if the `patch_path` contains specific substrings that indicate compatibility with the game version.
/// * Returns `true` if the patch is compatible, otherwise returns `false`.
///
/// # Example Usage
/// ```rust
/// use usage_checks::is_patch_compatible;
/// use std::path::Path;
/// let patch_path = "/path/to/patch_HG.asm";
/// let project_path = Path::new("/path/to/project");
/// if is_patch_compatible(patch_path, project_path) {
///    println!("The patch is compatible with the project.");
/// } else {
///   println!("The patch is not compatible with the project.");
/// }
/// ```
pub fn is_patch_compatible(patch_path: &str, project_path: &Path) -> bool {
    match determine_game_version(project_path).ok().as_deref() {
        Some(PLATINUM) if patch_path.contains("_PLAT") => true,
        Some(HEARTGOLD) if patch_path.contains("_HG") => true,
        Some(SOULSILVER) if patch_path.contains("_SS") => true,
        _ => false,
    }
}

/// Check if the synthOverlay is needed based on the assembly file content.
///
/// # Arguments
///
/// * `asm_path`: A string slice that holds the path to the assembly file.
///
/// # Returns
///
/// A boolean value indicating whether the synthOverlay is needed:
/// * `true` if the assembly file contains a line with `.open "unpacked/synthOverlay/"`.
/// * `false` if the assembly file does not contain such a line.
pub fn needs_synthoverlay(asm_path: &str) -> bool {
    let input = BufReader::new(
        fs::File::open(asm_path).unwrap_or_else(|_| panic!("Failed to open {asm_path}")),
    );
    let mut lines: Vec<String> = Vec::new();

    for line in input.lines() {
        let line = line.expect("Failed to read line");
        if line.contains(".open \"unpacked/synthOverlay/") {
            return true;
        }
        lines.push(line);
    }
    false
}

/// Check if the arm9 has been expanded for the given game version.
///
/// # Arguments
/// * `project_path`: A string slice that holds the path to the project directory where `arm9.bin` is located.
/// * `game_version`: A string slice that holds the game version, which can be one of:
///     * `"HeartGold"`
///     * `"SoulSilver"`
///     * `"Platinum"`
///
/// # Returns
/// A `Result<bool, io::Error>` where:
/// * `Ok(true)` indicates that the arm9 has been expanded for the specified game version.
/// * `Ok(false)` indicates that the arm9 has not been expanded for the specified game version.
/// * `Err(io::Error)` indicates an error occurred while trying to read the `arm9.bin` file, such as the file not being found or an unknown game version being specified.
///
/// # Details
/// This function:
/// * Constructs the path to `arm9.bin` by appending it to the provided `project_path`.
/// * Opens the `arm9.bin` file and reads a specific byte sequence at a defined offset based on the game version.
/// * Compares the read bytes against predefined constants for each game version.
/// * If the bytes match, it returns `Ok(true)` indicating the arm9 has been expanded.
/// * If the bytes do not match, it returns `Ok(false)` indicating the arm9 has not been expanded.
/// * If the file cannot be opened or the game version is unknown, it returns an `Err` with an appropriate error message.
///
/// # Example Usage
/// ```rust
/// use usage_checks::is_arm9_expanded;
/// let project_path = "/path/to/project";
/// let game_version = "HeartGold";
/// match is_arm9_expanded(project_path, game_version) {
///    Ok(expanded) => {
///        if expanded {
///           println!("The arm9 has been expanded for {}.", game_version);
///        } else {
///           println!("The arm9 has not been expanded for {}.", game_version);
///        }
///    },
///    Err(e) => {
///        eprintln!("Error checking arm9 expansion: {}", e);
///    }
/// }
/// ```
pub fn is_arm9_expanded(project_path: &str, game_version: &str) -> io::Result<bool> {
    let arm9_path = PathBuf::from(project_path).join("arm9/arm9.bin");
    let mut buf = [0u8; 4];

    match game_version {
        HEARTGOLD | SOULSILVER => fs::File::open(&arm9_path).map_or_else(
            |_| {
                eprintln!("arm9.bin not found at path: {}", arm9_path.display());
                Err(io::Error::new(
                    io::ErrorKind::NotFound,
                    "arm9.bin not found",
                ))
            },
            |mut file| {
                if file.seek(SeekFrom::Start(0xCD0)).is_ok()
                    && file.read_exact(&mut buf).is_ok()
                    && buf == [0x0F, 0xF1, 0x30, 0xFB]
                {
                    Ok(true)
                } else {
                    Ok(false)
                }
            },
        ),
        PLATINUM => fs::File::open(&arm9_path).map_or_else(
            |_| {
                eprintln!("arm9.bin not found at path: {}", arm9_path.display());
                Err(io::Error::new(
                    io::ErrorKind::NotFound,
                    "arm9.bin not found",
                ))
            },
            |mut file| {
                if file.seek(SeekFrom::Start(0xCB4)).is_ok()
                    && file.read_exact(&mut buf).is_ok()
                    && buf == [0x00, 0xF1, 0x5E, 0xFC]
                {
                    Ok(true)
                } else {
                    Ok(false)
                }
            },
        ),
        _ => {
            eprintln!("Unknown game version: {game_version}");
            Err(io::Error::new(
                io::ErrorKind::InvalidInput,
                "Unknown game version",
            ))
        }
    }
}
