use std::{
    env, fs,
    path::{Path, PathBuf},
};

use crate::api::paths::home_dir;
use crate::api::system::OpenWithApp;

pub(crate) fn list_open_with_apps(path: std::string::String) -> Vec<OpenWithApp> {
    let mime = detect_mime_type(&path);
    let mut apps: Vec<OpenWithApp> = Vec::new();
    let mut seen: std::collections::HashSet<std::string::String> = std::collections::HashSet::new();

    for dir in desktop_entry_dirs() {
        let Ok(entries) = fs::read_dir(&dir) else {
            continue;
        };

        for entry in entries.flatten() {
            let desktop_file = entry.path();
            if desktop_file.extension().and_then(|value| value.to_str()) != Some("desktop") {
                continue;
            }

            let Ok(content) = fs::read_to_string(&desktop_file) else {
                continue;
            };

            let Some(entry) = parse_desktop_entry(&content) else {
                continue;
            };

            if entry.hidden || entry.app_type != "Application" {
                continue;
            }

            if let Some(mime) = &mime {
                let supported = entry
                    .mime_types
                    .iter()
                    .any(|candidate| mime_matches(candidate, mime));
                if !supported {
                    continue;
                }
            }

            if !seen.insert(entry.name.clone()) {
                continue;
            }

            apps.push(OpenWithApp {
                id: desktop_file.to_string_lossy().into_owned(),
                name: entry.name,
                exec: entry.exec,
                comment: entry.comment,
                icon: entry.icon,
            });
        }
    }

    apps.sort_by_key(|app| app.name.to_lowercase());
    apps
}

pub(crate) fn open_with(
    path: std::string::String,
    desktop_file: std::string::String,
) -> Result<(), std::string::String> {
    if !Path::new(&path).exists() {
        return Err(format!("File not found: {path}"));
    }

    let status = std::process::Command::new("gio")
        .args(["launch", &desktop_file, &path])
        .status()
        .map_err(|error| format!("Failed to run gio: {error}"))?;

    if status.success() {
        Ok(())
    } else {
        Err(format!("Failed to open with {desktop_file}"))
    }
}

struct DesktopEntryInfo {
    name: std::string::String,
    exec: std::string::String,
    comment: std::string::String,
    icon: std::string::String,
    mime_types: Vec<std::string::String>,
    hidden: bool,
    app_type: std::string::String,
}

fn desktop_entry_dirs() -> Vec<PathBuf> {
    let mut dirs: Vec<PathBuf> = Vec::new();

    if let Ok(data_home) = env::var("XDG_DATA_HOME") {
        if !data_home.is_empty() {
            dirs.push(PathBuf::from(data_home).join("applications"));
        }
    } else {
        dirs.push(home_dir().join(".local/share/applications"));
    }

    if let Ok(data_dirs) = env::var("XDG_DATA_DIRS") {
        for dir in data_dirs.split(':').filter(|value| !value.is_empty()) {
            dirs.push(PathBuf::from(dir).join("applications"));
        }
    } else {
        dirs.push(PathBuf::from("/usr/local/share/applications"));
        dirs.push(PathBuf::from("/usr/share/applications"));
    }

    dirs
}

fn parse_desktop_entry(content: &str) -> Option<DesktopEntryInfo> {
    let mut in_desktop_entry = false;
    let mut name: Option<std::string::String> = None;
    let mut exec = std::string::String::new();
    let mut comment = std::string::String::new();
    let mut icon = std::string::String::new();
    let mut mime_types: Vec<std::string::String> = Vec::new();
    let mut hidden = false;
    let mut app_type = std::string::String::new();

    for line in content.lines() {
        let line = line.trim();

        if line.starts_with('[') {
            in_desktop_entry = line == "[Desktop Entry]";
            continue;
        }

        if !in_desktop_entry || line.starts_with('#') {
            continue;
        }

        let Some((key, value)) = line.split_once('=') else {
            continue;
        };

        let key = key.trim();
        let value = value.trim();

        match key {
            "Name" => name = Some(value.to_string()),
            "Exec" => exec = value.to_string(),
            "Comment" => comment = value.to_string(),
            "Icon" => icon = value.to_string(),
            "MimeType" => {
                mime_types = value
                    .split(';')
                    .filter(|item| !item.is_empty())
                    .map(|item| item.to_string())
                    .collect();
            }
            "Hidden" => hidden = value.eq_ignore_ascii_case("true"),
            "Type" => app_type = value.to_string(),
            _ => {}
        }
    }

    name.map(|name| DesktopEntryInfo {
        name,
        exec,
        comment,
        icon,
        mime_types,
        hidden,
        app_type,
    })
}

fn detect_mime_type(path: &str) -> Option<std::string::String> {
    let output = std::process::Command::new("xdg-mime")
        .args(["query", "filetype", path])
        .output()
        .ok()?;

    if !output.status.success() {
        return None;
    }

    let mime = String::from_utf8_lossy(&output.stdout).trim().to_string();
    if mime.is_empty() {
        None
    } else {
        Some(mime)
    }
}

fn mime_matches(declared: &str, actual: &str) -> bool {
    if declared == "*/*" {
        return true;
    }

    if let Some(prefix) = declared.strip_suffix("/*") {
        return actual.starts_with(prefix);
    }

    declared == actual
}
