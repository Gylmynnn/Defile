use std::{
    collections::HashSet,
    env, fs,
    path::{Path, PathBuf},
    process::Command,
};

use crate::api::paths::home_dir;
use crate::api::settings::{read_setting, write_setting};

#[flutter_rust_bridge::frb]
pub fn list_system_fonts() -> Vec<std::string::String> {
    let mut families: HashSet<std::string::String> = HashSet::new();

    // 1. Try via fc-list (Linux, BSD)
    if let Some(fc_fonts) = list_fonts_from_fc_list() {
        families.extend(fc_fonts);
    }

    // 2. If fc-list is unavailable or empty, scan the standard font folders
    if families.is_empty() {
        for root in font_search_roots() {
            scan_fonts_in_dir(&root, &mut families);
        }
    }

    let mut result: Vec<std::string::String> = families.into_iter().collect();
    result.sort_by(|a, b| a.to_lowercase().cmp(&b.to_lowercase()));
    result
}

fn font_search_roots() -> Vec<PathBuf> {
    let mut roots = Vec::new();
    let home = home_dir();

    #[cfg(target_os = "windows")]
    {
        if let Ok(windir) = env::var("WINDIR") {
            roots.push(PathBuf::from(windir).join("Fonts"));
        } else {
            roots.push(PathBuf::from(r"C:\Windows\Fonts"));
        }
    }

    #[cfg(target_os = "macos")]
    {
        roots.push(PathBuf::from("/System/Library/Fonts"));
        roots.push(PathBuf::from("/Library/Fonts"));
        roots.push(home.join("Library/Fonts"));
    }

    #[cfg(not(any(target_os = "windows", target_os = "macos")))]
    {
        roots.push(home.join(".fonts"));
        if let Ok(data_home) = env::var("XDG_DATA_HOME") {
            if !data_home.is_empty() {
                roots.push(PathBuf::from(data_home).join("fonts"));
            }
        }
        roots.push(home.join(".local/share/fonts"));
        roots.push(PathBuf::from("/usr/local/share/fonts"));
        roots.push(PathBuf::from("/usr/share/fonts"));
    }

    roots
}

fn list_fonts_from_fc_list() -> Option<Vec<std::string::String>> {
    let output = Command::new("fc-list")
        .args(["--format=%{family[0]}\n"])
        .output()
        .ok()?;

    if !output.status.success() {
        return None;
    }

    let text = String::from_utf8_lossy(&output.stdout);
    let mut families = HashSet::new();

    for line in text.lines() {
        for name in line.split(',') {
            let trimmed = name.trim();
            if !trimmed.is_empty() && !trimmed.starts_with('.') && !trimmed.starts_with('@') {
                families.insert(trimmed.to_string());
            }
        }
    }

    if families.is_empty() {
        None
    } else {
        Some(families.into_iter().collect())
    }
}

fn scan_fonts_in_dir(dir: &Path, families: &mut HashSet<std::string::String>) {
    let Ok(entries) = fs::read_dir(dir) else {
        return;
    };

    for entry in entries.flatten() {
        let path = entry.path();
        if path.is_dir() {
            scan_fonts_in_dir(&path, families);
        } else if let Some(ext) = path.extension().and_then(|e| e.to_str()) {
            let ext_lower = ext.to_lowercase();
            if ext_lower == "ttf" || ext_lower == "otf" || ext_lower == "ttc" {
                if let Some(family) = parse_font_family_from_file(&path) {
                    families.insert(family);
                }
            }
        }
    }
}

fn clean_font_stem(stem: &str) -> Option<std::string::String> {
    let cleaned = stem
        .replace(['-', '_'], " ")
        .replace("Regular", "")
        .replace("Bold", "")
        .replace("Italic", "")
        .replace("Medium", "")
        .replace("Light", "")
        .replace("SemiBold", "")
        .replace("ExtraBold", "")
        .replace("Black", "")
        .replace("Thin", "");
    let trimmed = cleaned.trim();
    if trimmed.is_empty() || trimmed.starts_with('.') {
        None
    } else {
        Some(trimmed.to_string())
    }
}

fn parse_font_family_from_file(path: &Path) -> Option<std::string::String> {
    let data = fs::read(path).ok()?;
    parse_font_family_from_bytes(&data).or_else(|| {
        path.file_stem()
            .and_then(|s| s.to_str())
            .and_then(clean_font_stem)
    })
}

fn parse_font_family_from_bytes(data: &[u8]) -> Option<std::string::String> {
    if data.len() < 12 {
        return None;
    }

    let num_tables = u16::from_be_bytes([data[4], data[5]]) as usize;
    let mut name_offset = None;

    for i in 0..num_tables {
        let start = 12 + i * 16;
        if start + 16 > data.len() {
            break;
        }
        if &data[start..start + 4] == b"name" {
            let offset = u32::from_be_bytes([
                data[start + 8],
                data[start + 9],
                data[start + 10],
                data[start + 11],
            ]) as usize;
            name_offset = Some(offset);
            break;
        }
    }

    let offset = name_offset?;
    if offset + 6 > data.len() {
        return None;
    }

    let count = u16::from_be_bytes([data[offset + 2], data[offset + 3]]) as usize;
    let string_offset = offset + u16::from_be_bytes([data[offset + 4], data[offset + 5]]) as usize;

    for i in 0..count {
        let rec_start = offset + 6 + i * 12;
        if rec_start + 12 > data.len() {
            break;
        }

        let platform_id = u16::from_be_bytes([data[rec_start], data[rec_start + 1]]);
        let name_id = u16::from_be_bytes([data[rec_start + 6], data[rec_start + 7]]);
        let length = u16::from_be_bytes([data[rec_start + 8], data[rec_start + 9]]) as usize;
        let str_offset = string_offset
            + u16::from_be_bytes([data[rec_start + 10], data[rec_start + 11]]) as usize;

        if name_id == 1 && str_offset + length <= data.len() {
            let bytes = &data[str_offset..str_offset + length];
            if platform_id == 3 || platform_id == 0 {
                let (chunks, _) = bytes.as_chunks::<2>();
                let u16_chars: Vec<u16> = chunks
                    .iter()
                    .map(|chunk| u16::from_be_bytes(*chunk))
                    .collect();
                if let Ok(name) = String::from_utf16(&u16_chars) {
                    let trimmed = name.trim().to_string();
                    if !trimmed.is_empty() && !trimmed.starts_with('.') {
                        return Some(trimmed);
                    }
                }
            } else if platform_id == 1 {
                let name = String::from_utf8_lossy(bytes).trim().to_string();
                if !name.is_empty() && !name.starts_with('.') {
                    return Some(name);
                }
            }
        }
    }

    None
}

#[flutter_rust_bridge::frb]
pub fn get_font_family() -> std::string::String {
    read_setting("font-family")
}

#[flutter_rust_bridge::frb]
pub fn set_font_family(name: std::string::String) -> Result<(), std::string::String> {
    write_setting("font-family", &name)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn get_and_set_font_family() {
        crate::api::settings::with_temp_config(|| {
            set_font_family("TestFont".to_string()).unwrap();
            assert_eq!(get_font_family(), "TestFont");

            set_font_family("".to_string()).unwrap();
            assert_eq!(get_font_family(), "");
        });
    }

    #[test]
    fn clean_font_stem_extracts_family() {
        assert_eq!(clean_font_stem("Roboto-BoldItalic").unwrap(), "Roboto");
        assert_eq!(clean_font_stem("FiraCode-Regular").unwrap(), "FiraCode");
    }

    #[test]
    fn list_system_fonts_not_empty_on_host() {
        let fonts = list_system_fonts();
        assert!(!fonts.is_empty());
    }
}
