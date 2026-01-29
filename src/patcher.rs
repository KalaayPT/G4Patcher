#![warn(clippy::nursery)]

use crate::armips_ffi::{assemble, ArmipsArgsBuilder};
use crate::constants::{PATCH_DIRECTIVE, PREASSEMBLE_DIRECTIVE};
use crate::synthoverlay_utils::handle_synthoverlay;
use crate::usage_checks::{determine_game_version, is_patch_compatible, needs_synthoverlay};
use log::{error, info};
use std::fs;
use std::path::{Path, PathBuf};

/// Errors that can occur during patching operations
#[derive(Debug)]
pub enum PatcherError {
    /// ROM folder not selected or invalid
    NoRomSelected,
    /// Patch file not selected
    NoPatchSelected,
    /// Game version could not be determined from header.bin
    InvalidGameVersion(String),
    /// Patch is not compatible with the selected ROM
    IncompatiblePatch { patch: String, rom: String },
    /// arm9.bin is not expanded (required for code injection)
    Arm9NotExpanded,
    /// armips failed during execution
    ArmipsFailed(String),
    /// Could not find free space in synthOverlay
    NoFreeSpace,
    /// File I/O error
    IoError(std::io::Error),
    /// Failed to read temp.bin for size calculation
    TempBinError(String),
}

impl std::fmt::Display for PatcherError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::NoRomSelected => write!(f, "No ROM folder selected"),
            Self::NoPatchSelected => write!(f, "No patch file selected"),
            Self::InvalidGameVersion(msg) => write!(f, "Invalid game version: {msg}"),
            Self::IncompatiblePatch { patch, rom } => {
                write!(f, "Patch '{}' is not compatible with ROM '{}'", patch, rom)
            }
            Self::Arm9NotExpanded => write!(f, "arm9.bin is not expanded. Please expand it before applying code injection patches."),
            Self::ArmipsFailed(msg) => write!(f, "armips failed: {msg}"),
            Self::NoFreeSpace => write!(f, "Could not find free space in synthOverlay"),
            Self::IoError(e) => write!(f, "I/O error: {e}"),
            Self::TempBinError(msg) => write!(f, "Failed to read temp.bin: {msg}"),
        }
    }
}

impl From<std::io::Error> for PatcherError {
    fn from(err: std::io::Error) -> Self {
        Self::IoError(err)
    }
}

/// Game version enum (more type-safe than strings)
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum GameVersion {
    Platinum,
    HeartGold,
    SoulSilver,
}

impl GameVersion {
    pub fn as_str(&self) -> &'static str {
        match self {
            Self::Platinum => "Platinum",
            Self::HeartGold => "HeartGold",
            Self::SoulSilver => "SoulSilver",
        }
    }
}

pub struct PatcherCore {
    rom_path: Option<PathBuf>,
    patch_path: Option<PathBuf>,
    game_version: Option<GameVersion>,
    exe_dir: PathBuf,
}

impl PatcherCore {
    /// Create a new patcher instance
    pub fn new(exe_dir: PathBuf) -> Self {
        Self {
            rom_path: None,
            patch_path: None,
            game_version: None,
            exe_dir,
        }
    }

    /// Set the ROM folder and validate it
    pub fn set_rom_folder(&mut self, path: PathBuf) -> Result<GameVersion, PatcherError> {
        let version_str = determine_game_version(&path)
            .map_err(|e| PatcherError::InvalidGameVersion(e.to_string()))?;

        let game_version = match version_str {
            "Platinum" => GameVersion::Platinum,
            "HeartGold" => GameVersion::HeartGold,
            "SoulSilver" => GameVersion::SoulSilver,
            _ => return Err(PatcherError::InvalidGameVersion(version_str.to_string())),
        };

        self.rom_path = Some(path);
        self.game_version = Some(game_version.clone());
        Ok(game_version)
    }

    /// Set the patch file and validate compatibility
    pub fn set_patch(&mut self, path: PathBuf) -> Result<(), PatcherError> {
        let rom_path = self.rom_path.as_ref().ok_or(PatcherError::NoRomSelected)?;

        if !is_patch_compatible(path.to_str().unwrap_or(""), rom_path) {
            return Err(PatcherError::IncompatiblePatch {
                patch: path
                    .file_name()
                    .and_then(|n| n.to_str())
                    .unwrap_or("unknown")
                    .to_string(),
                rom: self
                    .game_version
                    .as_ref()
                    .map(|v| v.as_str())
                    .unwrap_or("unknown")
                    .to_string(),
            });
        }

        self.patch_path = Some(path);
        Ok(())
    }

    /// Apply the selected patch to the ROM
    pub fn apply_patch(&self) -> Result<(), PatcherError> {
        let rom_path = self.rom_path.as_ref().ok_or(PatcherError::NoRomSelected)?;
        let patch_path = self
            .patch_path
            .as_ref()
            .ok_or(PatcherError::NoPatchSelected)?;
        let game_version = self
            .game_version
            .as_ref()
            .ok_or(PatcherError::NoRomSelected)?;

        // Check if this patch needs synthoverlay injection
        if needs_synthoverlay(patch_path.to_str().unwrap_or("")) {
            self.apply_synthoverlay_patch(rom_path, patch_path, game_version)?;
        } else {
            // Simple patch without synthoverlay
            self.run_armips_pass(patch_path, rom_path, PATCH_DIRECTIVE)?;
        }

        info!("Patch applied successfully! You can now repack your ROM.");
        Ok(())
    }

    /// Apply a patch that requires synthoverlay injection
    fn apply_synthoverlay_patch(
        &self,
        rom_path: &Path,
        patch_path: &Path,
        game_version: &GameVersion,
    ) -> Result<(), PatcherError> {
        // Step 1: Preassemble to calculate patch size
        info!("Calculating patch size...");
        self.run_armips_pass(patch_path, rom_path, PREASSEMBLE_DIRECTIVE)?;

        // Step 2: Read the generated temp.bin to get size
        let temp_bin_path = rom_path.join("temp.bin");
        let patch_size = fs::metadata(&temp_bin_path)
            .map_err(|e| PatcherError::TempBinError(e.to_string()))?
            .len() as usize;

        info!("Patch size: {} bytes", patch_size);

        // Step 3: Clean up temp.bin
        fs::remove_file(&temp_bin_path)?;

        // Step 4: Find free space and update injection address
        handle_synthoverlay(
            patch_path.to_str().unwrap_or(""),
            rom_path.to_str().unwrap_or(""),
            game_version.as_str(),
            patch_size,
        )?;

        // Step 5: Apply the actual patch
        info!("Applying patch to ROM...");
        self.run_armips_pass(patch_path, rom_path, PATCH_DIRECTIVE)?;

        Ok(())
    }

    /// Run armips with a specific directive (PREASSEMBLE or PATCH) using FFI
    fn run_armips_pass(
        &self,
        patch_path: &Path,
        rom_path: &Path,
        directive: &str,
    ) -> Result<(), PatcherError> {
        let canonical_patch = patch_path.canonicalize()?;
        let canonical_rom = rom_path.canonicalize()?;

        let result = assemble(
            ArmipsArgsBuilder::new()
                .input_file(&canonical_patch)
                .working_dir(&canonical_rom)
                .define(directive, "1")
                .silent(true),
        );

        if !result.success {
            let error_msg = if result.errors.is_empty() {
                "Assembly failed".to_string()
            } else {
                result.errors.join("\n")
            };
            error!("armips failed: {}", error_msg);
            return Err(PatcherError::ArmipsFailed(error_msg));
        }

        Ok(())
    }

    /// Get the current ROM path
    pub fn rom_path(&self) -> Option<&Path> {
        self.rom_path.as_deref()
    }

    /// Get the current patch path
    pub fn patch_path(&self) -> Option<&Path> {
        self.patch_path.as_deref()
    }

    /// Get the detected game version
    pub fn game_version(&self) -> Option<&GameVersion> {
        self.game_version.as_ref()
    }

    /// Check if ready to apply patch
    pub fn is_ready(&self) -> bool {
        self.rom_path.is_some() && self.patch_path.is_some()
    }
}
