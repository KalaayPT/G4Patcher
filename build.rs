// build.rs
use fs_extra::dir::{copy, CopyOptions};
use std::fs;
use std::path::Path;
use std::process::Command;

fn main() {
    build_armips();

    let out_dir = std::env::var("CARGO_TARGET_DIR").unwrap_or_else(|_| "target".into());
    let profile = std::env::var("PROFILE").unwrap_or_else(|_| "debug".into());
    let target_dir = Path::new(&out_dir).join(&profile);

    let folders = ["patches"];

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
    if !armips_dir.exists() {
        panic!(
            "armips source directory does not exist: {}",
            armips_dir.display()
        );
    }

    let build_dir = out_path.join("armips-build");
    let cmake_cache = build_dir.join("CMakeCache.txt");
    if cmake_cache.exists() {
        // `cargo package` verifies the crate from an extracted copy, but Cargo can reuse the
        // same OUT_DIR as the checkout build. CMake caches the original source directory and
        // refuses to reconfigure if it changes, so start fresh when build.rs is rerun.
        fs::remove_dir_all(&build_dir).expect("Failed to remove stale armips build dir");
    }
    fs::create_dir_all(&build_dir).expect("Failed to create build dir");

    let armips_path = armips_dir.to_string_lossy().to_string();
    let build_path = build_dir.to_string_lossy().to_string();

    eprintln!("Armips source: {}", armips_path);
    eprintln!("Build dir: {}", build_path);

    // Configure. Use direct process arguments instead of going through a shell; on
    // GitHub's Windows runners, `bash` can resolve to WSL, which is not installed.
    let mut configure = Command::new("cmake");
    configure
        .arg("-S")
        .arg(&armips_path)
        .arg("-B")
        .arg(&build_path);

    if cfg!(target_env = "msvc") {
        // Build armips with MSVC too. Mixing a MinGW/GNU static archive with the
        // MSVC Rust target can produce linker errors like LNK1143.
        configure.arg("-G").arg("Visual Studio 17 2022");
        // Rust's MSVC target links the static CRT by default. CMake's Visual
        // Studio Release default is /MD, which leaves unresolved __imp_* CRT
        // symbols when linked into the Rust binary, so force /MT for armips.
        configure
            .arg("-DCMAKE_POLICY_DEFAULT_CMP0091=NEW")
            .arg("-DCMAKE_MSVC_RUNTIME_LIBRARY=MultiThreaded");
        if std::env::var("TARGET").is_ok_and(|target| target.starts_with("x86_64-")) {
            configure.arg("-A").arg("x64");
        }
    } else {
        configure.arg("-GNinja").arg("-DCMAKE_BUILD_TYPE=Release");
    }

    let status = configure
        .arg("-DARMIPS_LIBRARY_ONLY=ON")
        .arg("-DARMIPS_USE_STD_FILESYSTEM=ON")
        .status()
        .expect("Failed to run cmake configure");

    if !status.success() {
        panic!("CMake configure failed");
    }

    // Build
    let status = Command::new("cmake")
        .arg("--build")
        .arg(&build_path)
        .arg("--config")
        .arg("Release")
        .arg("--target")
        .arg("armips")
        .status()
        .expect("Failed to run cmake build");

    if !status.success() {
        panic!("CMake build failed");
    }

    let link_path = if cfg!(target_env = "msvc") {
        build_dir.join("Release")
    } else {
        build_dir.clone()
    };

    println!("cargo:rustc-link-search=native={}", link_path.display());
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
