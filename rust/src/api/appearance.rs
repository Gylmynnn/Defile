use crate::api::settings::{read_setting, write_setting};

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
        return Err("Invalid interface scale".to_string());
    }

    write_setting("ui-scale", &format!("{scale}"))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn get_and_set_appearance_settings() {
        crate::api::settings::with_temp_config(|| {
            set_base_theme("test-theme".to_string()).unwrap();
            assert_eq!(get_base_theme(), "test-theme");
            set_base_theme("".to_string()).unwrap();
            assert_eq!(get_base_theme(), "");

            set_accent_color("test-accent".to_string()).unwrap();
            assert_eq!(get_accent_color(), "test-accent");
            set_accent_color("".to_string()).unwrap();
            assert_eq!(get_accent_color(), "");
        });
    }

    #[test]
    fn get_and_set_ui_scale() {
        crate::api::settings::with_temp_config(|| {
            set_ui_scale(1.25).unwrap();
            assert_eq!(get_ui_scale(), 1.25);
            set_ui_scale(1.0).unwrap();
            assert_eq!(get_ui_scale(), 1.0);
        });
    }
}
