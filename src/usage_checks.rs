#![warn(clippy::nursery, clippy::pedantic)]

use crate::constants::{
    HEARTGOLD, HEARTGOLD_BYTES, PLATINUM, PLATINUM_BYTES, SOULSILVER, SOULSILVER_BYTES,
};
use log::error;
use std::io::{BufRead, BufReader, Read, Seek, SeekFrom};
use std::path::{Path, PathBuf};
use std::{fs, io};

/// Determine the game version based on the header.bin file in the project path.
///
/// # Arguments
/// * `project_path`: A path that holds the directory where `header.bin` is located.
///
/// # Returns
/// A string slice representing the game version, which can be one of:
/// * `"Platinum"`
/// * `"HeartGold"`
/// * `"SoulSilver"`
///
/// # Details
/// This function:
/// * Constructs the path to `header.bin` by appending it to the provided `project_path`.
/// * Opens the `header.bin` file and reads a specific byte sequence starting from offset 0xC.
/// * Compares the read bytes against predefined constants for each game version.
/// * If the bytes match, it returns the corresponding game version.
/// * If the bytes do not match any known version, it panics with an error message indicating the unknown version and the bytes found.
pub fn determine_game_version(project_path: &Path) -> io::Result<&str> {
    let header_path = project_path.join("header.bin");

    fs::File::open(&header_path).map_or_else(|_| {
        Err(io::Error::new(io::ErrorKind::NotFound, "header.bin not found"))
    }, |mut file| {
        let mut buf = [0u8; 4];
        file.seek(SeekFrom::Start(0xC))?;
        file.read_exact(&mut buf)?;
        match buf {
            PLATINUM_BYTES => Ok(PLATINUM),
            HEARTGOLD_BYTES => Ok(HEARTGOLD),
            SOULSILVER_BYTES => Ok(SOULSILVER),
            _ => {
                error!("Unknown game version in header.bin at path: {}\nBytes found:{:02X} {:02X} {:02X} {:02X}",
                       header_path.display(), buf[0], buf[1], buf[2], buf[3]);
                Err(io::Error::new(io::ErrorKind::InvalidData, "Unknown game version in header.bin"))
            }
        }
    })
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
/// * Calls `determine_game_version` to get the game version based on the `header.bin` file in the project path.
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
    match determine_game_version(project_path).ok() {
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
    let arm9_path = PathBuf::from(project_path).join("arm9.bin");
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
                    && buf == [0x00, 0xF1, 0xB4, 0xF8]
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
