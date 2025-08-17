use std::path::{Path, PathBuf};
use log::{debug, info};
use rfd::FileDialog;

pub fn get_project_path() -> Option<PathBuf> {
    debug!("Opening ROM folder dialog...");
    FileDialog::new()
        .set_title("Select unpacked ROM folder")
        .pick_folder()
        .map_or_else(
            || {
                info!("No folder selected");
                None
            },
            |selected_folder| {
                info!("Selected folder: {}", selected_folder.display());
                Some(selected_folder)
            },
        )
}

pub fn get_patch_path(exe_dir: &Path) -> Option<PathBuf> {
    //println!("Please select the patch file to apply");
    debug!("Opening patch file dialog...");

    let patches_dir = exe_dir.join("patches");

    // Use rfd to open a file dialog and select the project path
    FileDialog::new()
        .add_filter("Patch files", &["asm"])
        .set_title("Select Patch file")
        .set_directory(patches_dir)
        .pick_file()
        .map_or_else(
            || {
                info!("No patch selected.");
                None
            },
            |selected_patch| {
                info!("Selected patch: {}", selected_patch.display());
                Some(selected_patch)
            },
        )
}