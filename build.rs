// build.rs
use fs_extra::dir::{copy, CopyOptions};
use std::fs;
use std::path::Path;

fn main() {
    let out_dir = std::env::var("CARGO_TARGET_DIR").unwrap_or_else(|_| "target".into());
    let profile = std::env::var("PROFILE").unwrap_or_else(|_| "debug".into());
    let target_dir = Path::new(&out_dir).join(&profile);

    let folders = ["assets", "patches"];

    for folder in folders.iter() {
        let dest = target_dir.join(folder);
        if dest.exists() {
            fs::remove_dir_all(&dest).unwrap_or(());
        }
        if Path::new(folder).exists() {
            let mut options = CopyOptions::new();
            options.overwrite = true;
            options.copy_inside = true;
            copy(folder, &target_dir, &options).unwrap();
        }
    }

    #[cfg(unix)]
    {
        use std::os::unix::fs::PermissionsExt;
        let armips_path = target_dir.join("assets").join("armips.exe");
        if armips_path.exists() {
            fs::set_permissions(&armips_path, fs::Permissions::from_mode(0o755))
                .expect("Failed to set execute permissions on armips.exe");
        }
    }
}
