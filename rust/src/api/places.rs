use std::{fs, path::PathBuf};

use crate::api::paths::{home_dir, trash_dir};
use crate::api::system::{Place, PlaceKind};

pub(crate) fn list_places() -> Vec<Place> {
    let home = home_dir();

    let mut places = vec![
        Place {
            label: "Home".to_string(),
            path: home.to_string_lossy().into_owned(),
            kind: PlaceKind::Home,
        },
        Place {
            label: "Recents".to_string(),
            path: home.to_string_lossy().into_owned(),
            kind: PlaceKind::Recent,
        },
        Place {
            label: "Trash".to_string(),
            path: trash_dir()
                .map(|path| path.to_string_lossy().into_owned())
                .unwrap_or_default(),
            kind: PlaceKind::Trash,
        },
        Place {
            label: "Network".to_string(),
            path: std::string::String::new(),
            kind: PlaceKind::Network,
        },
    ];

    let standard_dirs: [(&str, PathBuf); 6] = [
        ("Documents", home.join("Documents")),
        ("Downloads", home.join("Downloads")),
        ("Pictures", home.join("Pictures")),
        ("Music", home.join("Music")),
        ("Videos", home.join("Videos")),
        ("Desktop", home.join("Desktop")),
    ];

    for (label, path) in standard_dirs {
        if path.is_dir() {
            places.push(Place {
                label: label.to_string(),
                path: path.to_string_lossy().into_owned(),
                kind: PlaceKind::Folder,
            });
        }
    }

    places.extend(list_drives());

    places
}

fn list_drives() -> Vec<Place> {
    #[cfg(windows)]
    {
        let mut drives = Vec::new();

        for letter in b'A'..=b'Z' {
            let root = format!("{}:\\", letter as char);

            if std::path::Path::new(&root).exists() {
                drives.push(Place {
                    label: root.clone(),
                    path: root,
                    kind: PlaceKind::Drive,
                });
            }
        }

        if !drives.is_empty() {
            return drives;
        }
    }

    let root = PathBuf::from("/");
    let label = linux_drive_label().unwrap_or_else(|| "Filesystem".to_string());

    vec![Place {
        label,
        path: root.to_string_lossy().into_owned(),
        kind: PlaceKind::Drive,
    }]
}

fn linux_drive_label() -> Option<std::string::String> {
    let contents = fs::read_to_string("/etc/os-release").ok()?;

    for line in contents.lines() {
        if let Some(value) = line.strip_prefix("ID=") {
            let id = value.trim().trim_matches('"');
            if !id.is_empty() {
                return Some(id.to_lowercase());
            }
        }
    }

    None
}
