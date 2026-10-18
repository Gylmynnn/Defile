use std::{env, fs, path::PathBuf};

use crate::api::system::home_dir;

fn config_file(name: &str) -> PathBuf {
    let base = match env::var("XDG_CONFIG_HOME") {
        Ok(value) if !value.is_empty() => PathBuf::from(value),
        _ => home_dir().join(".config"),
    };

    base.join("defile").join(name)
}

fn read_setting(name: &str) -> std::string::String {
    match fs::read_to_string(config_file(name)) {
        Ok(value) => value.trim().to_string(),
        Err(_) => std::string::String::new(),
    }
}

fn write_setting(name: &str, value: &str) -> Result<(), std::string::String> {
    let file = config_file(name);

    if value.trim().is_empty() {
        let _ = fs::remove_file(file);
        return Ok(());
    }

    if let Some(parent) = file.parent() {
        fs::create_dir_all(parent)
            .map_err(|error| format!("Gagal menyiapkan folder pengaturan: {error}"))?;
    }

    fs::write(&file, value.trim())
        .map_err(|error| format!("Gagal menyimpan pengaturan tampilan: {error}"))
}

#[flutter_rust_bridge::frb]
pub fn get_base_theme() -> std::string::String {
    read_setting("base-theme")
}

#[flutter_rust_bridge::frb]
pub fn set_base_theme(name: std::string::String) -> Result<(), std::string::String> {
    write_setting("base-theme", &name)
}

#[flutter_rust_bridge::frb]
pub fn get_accent_color() -> std::string::String {
    read_setting("accent-color")
}

#[flutter_rust_bridge::frb]
pub fn set_accent_color(name: std::string::String) -> Result<(), std::string::String> {
    write_setting("accent-color", &name)
}

#[flutter_rust_bridge::frb]
pub fn get_ui_scale() -> f64 {
    read_setting("ui-scale")
        .parse::<f64>()
        .ok()
        .filter(|value| *value > 0.0)
        .unwrap_or(1.0)
}

#[flutter_rust_bridge::frb]
pub fn set_ui_scale(scale: f64) -> Result<(), std::string::String> {
    if !scale.is_finite() || scale <= 0.0 {
        return Err("Skala antarmuka tidak valid".to_string());
    }

    write_setting("ui-scale", &format!("{scale}"))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn get_and_set_appearance_settings() {
        let theme = format!("TestTheme_{}", std::process::id());
        set_base_theme(theme.clone()).unwrap();
        assert_eq!(get_base_theme(), theme);
        set_base_theme("".to_string()).unwrap();
        assert_eq!(get_base_theme(), "");

        let accent = format!("TestAccent_{}", std::process::id());
        set_accent_color(accent.clone()).unwrap();
        assert_eq!(get_accent_color(), accent);
        set_accent_color("".to_string()).unwrap();
        assert_eq!(get_accent_color(), "");
    }

    #[test]
    fn get_and_set_ui_scale() {
        set_ui_scale(1.25).unwrap();
        assert_eq!(get_ui_scale(), 1.25);
        set_ui_scale(1.0).unwrap();
        assert_eq!(get_ui_scale(), 1.0);
    }
}