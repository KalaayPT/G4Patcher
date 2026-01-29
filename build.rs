use fs_extra::dir::{copy, CopyOptions};
use std::fs;
use std::path::Path;
use std::process::Command;

fn main() {
    build_armips();

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
}

fn build_armips() {
    let manifest_dir = std::env::var("CARGO_MANIFEST_DIR").expect("CARGO_MANIFEST_DIR not set");
    let manifest_path = Path::new(&manifest_dir);
    let out_dir = std::env::var("OUT_DIR").expect("OUT_DIR not set");
    let out_path = Path::new(&out_dir);

    let armips_dir = manifest_path.join("armips");
    let armips_canonical = armips_dir
        .canonicalize()
        .expect("Failed to canonicalize armips path");

    let build_dir = out_path.join("armips-build");
    fs::create_dir_all(&build_dir).expect("Failed to create build dir");

    // Platform-specific path and command handling
    let (armips_path, build_path, use_bash) = if cfg!(target_os = "windows") {
        // On Windows with MSYS2, convert paths to Unix-style
        let to_msys_path = |p: &Path| {
            let s = p.to_string_lossy().replace('\\', "/");
            if s.len() > 2 && s.chars().nth(1) == Some(':') {
                // Convert C:/... to /c/...
                format!("/{}{}", &s[0..1].to_lowercase(), &s[2..])
            } else {
                s
            }
        };
        (
            to_msys_path(&armips_canonical),
            to_msys_path(&build_dir),
            true,
        )
    } else {
        // On Linux/macOS, use paths directly
        (
            armips_canonical.to_string_lossy().to_string(),
            build_dir.to_string_lossy().to_string(),
            false,
        )
    };

    eprintln!("Armips source: {}", armips_path);
    eprintln!("Build dir: {}", build_path);

    // Configure
    let status = if use_bash {
        let cmake_args = format!(
            "-S {} -B {} -GNinja -DARMIPS_LIBRARY_ONLY=ON -DARMIPS_USE_STD_FILESYSTEM=ON -DCMAKE_BUILD_TYPE=Release",
            armips_path, build_path
        );
        Command::new("bash")
            .arg("-c")
            .arg(format!("cmake {}", cmake_args))
            .status()
    } else {
        Command::new("cmake")
            .arg("-S")
            .arg(&armips_path)
            .arg("-B")
            .arg(&build_path)
            .arg("-GNinja")
            .arg("-DARMIPS_LIBRARY_ONLY=ON")
            .arg("-DARMIPS_USE_STD_FILESYSTEM=ON")
            .arg("-DCMAKE_BUILD_TYPE=Release")
            .status()
    }
    .expect("Failed to run cmake configure");

    if !status.success() {
        panic!("CMake configure failed");
    }

    // Build
    let status = if use_bash {
        Command::new("bash")
            .arg("-c")
            .arg(format!(
                "cmake --build {} --config Release --target armips",
                build_path
            ))
            .status()
    } else {
        Command::new("cmake")
            .arg("--build")
            .arg(&build_path)
            .arg("--config")
            .arg("Release")
            .arg("--target")
            .arg("armips")
            .status()
    }
    .expect("Failed to run cmake build");

    if !status.success() {
        panic!("CMake build failed");
    }

    println!("cargo:rustc-link-search=native={}", build_path);
    println!("cargo:rustc-link-lib=static=armips");

    // Link C++ standard library
    if cfg!(target_os = "macos") {
        println!("cargo:rustc-link-lib=c++");
    } else if cfg!(target_os = "windows") {
        println!("cargo:rustc-link-lib=shlwapi");
        // Windows may need additional C++ runtime linking depending on the toolchain
    } else {
        // Linux and other Unix-like systems
        println!("cargo:rustc-link-lib=stdc++");
    }

    println!("cargo:rerun-if-changed=armips/ffi");
    println!("cargo:rerun-if-changed=armips/CMakeLists.txt");
}
