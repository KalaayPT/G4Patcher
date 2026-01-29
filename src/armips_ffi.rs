//! FFI bindings for armips assembler
//!
//! This module provides a safe Rust wrapper around the armips C FFI.

use std::ffi::{c_char, c_int, CString};
use std::path::Path;
use std::ptr;

#[repr(C)]
pub struct ArmipsFFIArgs {
    input_file: *const c_char,
    working_dir: *const c_char,
    temp_file: *const c_char,
    sym_file: *const c_char,
    sym_version: c_int,
    defines: *const *const c_char,
    define_count: usize,
    error_on_warning: c_int,
    silent: c_int,
    show_stats: c_int,
    errors: *mut *mut c_char,
    error_count: usize,
}

impl ArmipsFFIArgs {
    pub fn new() -> Self {
        Self {
            input_file: ptr::null(),
            working_dir: ptr::null(),
            temp_file: ptr::null(),
            sym_file: ptr::null(),
            sym_version: 0,
            defines: ptr::null(),
            define_count: 0,
            error_on_warning: 0,
            silent: 1,
            show_stats: 0,
            errors: ptr::null_mut(),
            error_count: 0,
        }
    }
}

pub struct ArmipsArgsBuilder {
    input_file: Option<CString>,
    working_dir: Option<CString>,
    temp_file: Option<CString>,
    sym_file: Option<CString>,
    sym_version: i32,
    defines: Vec<CString>,
    define_ptrs: Vec<*const c_char>,
    error_on_warning: bool,
    silent: bool,
    show_stats: bool,
}

impl ArmipsArgsBuilder {
    pub fn new() -> Self {
        Self {
            input_file: None,
            working_dir: None,
            temp_file: None,
            sym_file: None,
            sym_version: 0,
            defines: Vec::new(),
            define_ptrs: Vec::new(),
            error_on_warning: false,
            silent: true,
            show_stats: false,
        }
    }

    pub fn input_file<P: AsRef<Path>>(mut self, path: P) -> Self {
        self.input_file = CString::new(path.as_ref().to_string_lossy().as_bytes()).ok();
        self
    }

    pub fn working_dir<P: AsRef<Path>>(mut self, path: P) -> Self {
        self.working_dir = CString::new(path.as_ref().to_string_lossy().as_bytes()).ok();
        self
    }

    pub fn define(mut self, name: &str, value: &str) -> Self {
        let def = format!("{}={}", name, value);
        if let Ok(cstr) = CString::new(def) {
            self.defines.push(cstr);
            self.define_ptrs.push(self.defines.last().unwrap().as_ptr());
        }
        self
    }

    pub fn silent(mut self, silent: bool) -> Self {
        self.silent = silent;
        self
    }

    fn into_ffi_args(self) -> ArmipsFFIArgs {
        ArmipsFFIArgs {
            input_file: self.input_file.as_ref().map_or(ptr::null(), |s| s.as_ptr()),
            working_dir: self
                .working_dir
                .as_ref()
                .map_or(ptr::null(), |s| s.as_ptr()),
            temp_file: self.temp_file.as_ref().map_or(ptr::null(), |s| s.as_ptr()),
            sym_file: self.sym_file.as_ref().map_or(ptr::null(), |s| s.as_ptr()),
            sym_version: self.sym_version,
            defines: if self.define_ptrs.is_empty() {
                ptr::null()
            } else {
                self.define_ptrs.as_ptr()
            },
            define_count: self.define_ptrs.len(),
            error_on_warning: self.error_on_warning as c_int,
            silent: self.silent as c_int,
            show_stats: self.show_stats as c_int,
            errors: ptr::null_mut(),
            error_count: 0,
        }
    }
}

pub struct AssemblyResult {
    pub success: bool,
    pub errors: Vec<String>,
}

extern "C" {
    fn armips_assemble(args: *const ArmipsFFIArgs) -> c_int;
    fn armips_free_errors(errors: *mut *mut c_char, count: usize);
    fn armips_version(major: *mut c_int, minor: *mut c_int, revision: *mut c_int);
}

pub fn assemble(builder: ArmipsArgsBuilder) -> AssemblyResult {
    let mut args = builder.into_ffi_args();
    let args_ptr = &mut args as *mut ArmipsFFIArgs;

    let success = unsafe { armips_assemble(args_ptr) } == 0;

    let mut errors = Vec::new();
    if !success && !args.errors.is_null() {
        unsafe {
            let error_slice = std::slice::from_raw_parts(args.errors, args.error_count);
            for &error_ptr in error_slice {
                if !error_ptr.is_null() {
                    let cstr = std::ffi::CStr::from_ptr(error_ptr);
                    if let Ok(s) = cstr.to_str() {
                        errors.push(s.to_string());
                    }
                }
            }
            armips_free_errors(args.errors, args.error_count);
        }
    }

    AssemblyResult { success, errors }
}

pub fn version() -> (i32, i32, i32) {
    let mut major = 0;
    let mut minor = 0;
    let mut revision = 0;
    unsafe {
        armips_version(&mut major, &mut minor, &mut revision);
    }
    (major, minor, revision)
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::fs;
    use std::path::PathBuf;

    fn test_dir() -> PathBuf {
        PathBuf::from(env!("CARGO_MANIFEST_DIR"))
            .join("target")
            .join("test_output")
    }

    fn setup() -> PathBuf {
        let dir = test_dir();
        let _ = fs::remove_dir_all(&dir);
        fs::create_dir_all(&dir).unwrap();
        dir
    }

    #[test]
    fn test_version() {
        let (major, minor, revision) = version();
        assert!(major >= 0);
        assert!(minor >= 0);
        assert!(revision >= 0);
        println!("armips version: {}.{}.{}", major, minor, revision);
    }

    #[test]
    fn test_simple_assembly() {
        let test_dir = setup();
        let asm_path = test_dir.join("test.asm");

        let asm_content = r#".nds
.create "output.bin",0

.thumb

main:
    mov r0, #1
    mov r1, #2
    add r0, r0, r1
    bx lr

.close
"#;

        fs::write(&asm_path, asm_content).unwrap();

        let result = assemble(
            ArmipsArgsBuilder::new()
                .input_file(&asm_path)
                .working_dir(&test_dir)
                .silent(true),
        );

        let _ = fs::remove_dir_all(&test_dir);

        if !result.success {
            for error in &result.errors {
                eprintln!("armips error: {}", error);
            }
        }

        assert!(result.success, "Assembly failed: {:?}", result.errors);
        assert!(result.errors.is_empty());
    }

    #[test]
    fn test_assembly_with_define() {
        let test_dir = setup();
        let asm_path = test_dir.join("test.asm");

        let asm_content = r#".nds
.create "output.bin",0

.thumb

.if defined(TEST_DEFINE)
    mov r0, #TEST_VALUE
.else
    mov r0, #0
.endif
    bx lr

.close
"#;

        fs::write(&asm_path, asm_content).unwrap();

        let result = assemble(
            ArmipsArgsBuilder::new()
                .input_file(&asm_path)
                .working_dir(&test_dir)
                .define("TEST_DEFINE", "1")
                .define("TEST_VALUE", "42")
                .silent(true),
        );

        let _ = fs::remove_dir_all(&test_dir);

        assert!(result.success, "Assembly failed: {:?}", result.errors);
    }

    #[test]
    fn test_assembly_error() {
        let test_dir = setup();
        let asm_path = test_dir.join("test.asm");

        // Invalid assembly (undefined instruction)
        let asm_content = r#".nds
.create "output.bin",0

.thumb

    invalid_instruction_here

.close
"#;

        fs::write(&asm_path, asm_content).unwrap();

        let result = assemble(
            ArmipsArgsBuilder::new()
                .input_file(&asm_path)
                .working_dir(&test_dir)
                .silent(true),
        );

        let _ = fs::remove_dir_all(&test_dir);

        assert!(!result.success, "Should have failed");
        assert!(!result.errors.is_empty(), "Should have errors");
    }
}
