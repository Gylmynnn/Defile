use std::{env, fs, path::PathBuf};

use crate::api::paths::home_dir;

fn config_dir() -> PathBuf {
    match env::var("XDG_CONFIG_HOME") {
        Ok(value) if !value.is_empty() => PathBuf::from(value),
        _ => home_dir().join(".config"),
    }
    .join("defile")
}

fn settings_path(name: &str) -> PathBuf {
    config_dir().join(name)
}

pub(crate) fn read_setting(name: &str) -> std::string::String {
    match fs::read_to_string(settings_path(name)) {
        Ok(value) => value.trim().to_string(),
        Err(_) => std::string::String::new(),
    }
}

pub(crate) fn write_setting(name: &str, value: &str) -> Result<(), std::string::String> {
    let file = settings_path(name);

    if value.trim().is_empty() {
        let _ = fs::remove_file(file);
        return Ok(());
    }

    if let Some(parent) = file.parent() {
        fs::create_dir_all(parent)
            .map_err(|error| format!("Failed to prepare settings folder: {error}"))?;
    }

    fs::write(&file, value.trim()).map_err(|error| format!("Failed to save settings: {error}"))
}

#[cfg(test)]
pub(crate) fn with_temp_config<T>(run: impl FnOnce() -> T) -> T {
    use std::sync::{
        atomic::{AtomicU64, Ordering},
        Mutex,
    };

    static LOCK: Mutex<()> = Mutex::new(());
    static COUNTER: AtomicU64 = AtomicU64::new(0);

    struct Restore {
        previous: Option<std::ffi::OsString>,
        directory: PathBuf,
    }

    impl Drop for Restore {
        fn drop(&mut self) {
            match &self.previous {
                Some(value) => env::set_var("XDG_CONFIG_HOME", value),
                None => env::remove_var("XDG_CONFIG_HOME"),
            }
            let _ = fs::remove_dir_all(&self.directory);
        }
    }

    let _guard = LOCK.lock().unwrap_or_else(|error| error.into_inner());
    let directory = env::temp_dir().join(format!(
        "defile_settings_test_{}_{}",
        std::process::id(),
        COUNTER.fetch_add(1, Ordering::Relaxed)
    ));
    fs::create_dir_all(&directory).expect("failed to create temp config dir");

    let restore = Restore {
        previous: env::var_os("XDG_CONFIG_HOME"),
        directory: directory.clone(),
    };
    env::set_var("XDG_CONFIG_HOME", &directory);

    let result = run();
    drop(restore);
    result
}
