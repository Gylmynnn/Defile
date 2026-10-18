use std::{
    collections::VecDeque,
    env,
    ffi::OsString,
    fs,
    path::{Path, PathBuf},
    time::{SystemTime, UNIX_EPOCH},
};

use crate::api::file_entry::{entry_from_metadata, FileEntry};

#[derive(Debug, Clone)]
pub struct DiskUsage {
    pub path: std::string::String,
    pub total_bytes: u64,
    pub free_bytes: u64,
    pub used_bytes: u64,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum PlaceKind {
    Home,
    Recent,
    Trash,
    Network,
    Folder,
    Drive,
}

#[derive(Debug, Clone)]
pub struct Place {
    pub label: std::string::String,
    pub path: std::string::String,
    pub kind: PlaceKind,
}

#[derive(Debug, Clone)]
pub struct OpenWithApp {
    pub id: std::string::String,
    pub name: std::string::String,
    pub exec: std::string::String,
    pub comment: std::string::String,
    pub icon: std::string::String,
}

pub(crate) fn home_dir() -> PathBuf {
    #[cfg(windows)]
    {
        if let Ok(profile) = env::var("USERPROFILE") {
            if !profile.is_empty() {
                return PathBuf::from(profile);
            }
        }

        if let (Ok(drive), Ok(path)) = (env::var("HOMEDRIVE"), env::var("HOMEPATH")) {
            return PathBuf::from(format!("{drive}{path}"));
        }
    }

    if let Ok(home) = env::var("HOME") {
        if !home.is_empty() {
            return PathBuf::from(home);
        }
    }

    PathBuf::from("/")
}

pub(crate) fn trash_root() -> Option<PathBuf> {
    if cfg!(target_os = "macos") {
        return Some(home_dir().join(".Trash"));
    }

    if cfg!(windows) {
        return None;
    }

    if let Ok(data_home) = env::var("XDG_DATA_HOME") {
        if !data_home.is_empty() {
            return Some(PathBuf::from(data_home).join("Trash"));
        }
    }

    Some(home_dir().join(".local/share/Trash"))
}

pub(crate) fn trash_dir() -> Option<PathBuf> {
    if cfg!(target_os = "macos") {
        return trash_root();
    }

    trash_root().map(|root| root.join("files"))
}

#[flutter_rust_bridge::frb]
pub fn move_to_trash(
    path: std::string::String,
) -> Result<std::string::String, std::string::String> {
    let source = PathBuf::from(&path);

    let _metadata = fs::symlink_metadata(&source)
        .map_err(|error| format!("Item not found or not accessible: {error}"))?;

    if cfg!(windows) {
        return Err("Move to Trash is not supported on Windows yet".to_string());
    }

    let home = home_dir();
    if source == Path::new("/") || source == home {
        return Err("This item cannot be moved to Trash".to_string());
    }

    let name = source
        .file_name()
        .map(Path::new)
        .ok_or("Invalid item name")?
        .to_path_buf();

    #[cfg(target_os = "macos")]
    {
        let trash = home.join(".Trash");
        fs::create_dir_all(&trash).map_err(|error| format!("Failed to set up Trash: {error}"))?;

        let destination = unique_destination(&trash, &name);
        fs::rename(&source, &destination)
            .map_err(|error| format!("Failed to move to Trash: {error}"))?;

        return Ok(destination.to_string_lossy().into_owned());
    }

    #[cfg(all(unix, not(target_os = "macos")))]
    {
        let root = trash_root().ok_or("Trash is not available")?;
        let files_dir = root.join("files");
        let info_dir = root.join("info");

        fs::create_dir_all(&files_dir)
            .map_err(|error| format!("Failed to set up Trash: {error}"))?;
        fs::create_dir_all(&info_dir)
            .map_err(|error| format!("Failed to set up Trash: {error}"))?;

        let destination = unique_destination(&files_dir, &name);
        fs::rename(&source, &destination)
            .map_err(|error| format!("Failed to move to Trash: {error}"))?;

        let info_name = destination
            .file_name()
            .map(|value| value.to_string_lossy().into_owned())
            .unwrap_or_default();

        let contents = format!(
            "[Trash Info]\nPath={}\nDeletionDate={}\n",
            source.display(),
            deletion_timestamp()
        );

        let _ = fs::write(info_dir.join(format!("{info_name}.trashinfo")), contents);

        return Ok(destination.to_string_lossy().into_owned());
    }

    #[allow(unreachable_code)]
    Err("Move to Trash is not supported on this platform yet".to_string())
}

#[flutter_rust_bridge::frb]
pub fn delete_from_trash(path: std::string::String) -> Result<(), std::string::String> {
    let source = PathBuf::from(&path);
    let root = trash_root().ok_or("Trash is not available on this platform")?;

    if !source.starts_with(&root) {
        return Err("Item is not part of Trash".to_string());
    }

    if source == root {
        return Err("Use Empty Trash to delete all items".to_string());
    }

    let metadata = fs::symlink_metadata(&source)
        .map_err(|error| format!("Item not found or not accessible: {error}"))?;

    let removal = if metadata.is_dir() {
        fs::remove_dir_all(&source)
    } else {
        fs::remove_file(&source)
    };

    removal.map_err(|error| format!("Failed to delete: {error}"))?;

    if let Some(name) = source.file_name() {
        let info = root
            .join("info")
            .join(format!("{}.trashinfo", name.to_string_lossy()));

        let _ = fs::remove_file(info);
    }

    Ok(())
}

#[flutter_rust_bridge::frb]
pub fn empty_trash() -> Result<u32, std::string::String> {
    let root = trash_root().ok_or("Trash is not available on this platform")?;
    let files_dir = trash_dir().ok_or("Trash is not available on this platform")?;

    let mut removed: u32 = 0;

    if let Ok(entries) = fs::read_dir(&files_dir) {
        for entry in entries.flatten() {
            let path = entry.path();
            let Ok(metadata) = fs::symlink_metadata(&path) else {
                continue;
            };

            let removal = if metadata.is_dir() {
                fs::remove_dir_all(&path)
            } else {
                fs::remove_file(&path)
            };

            if removal.is_ok() {
                removed += 1;
            }
        }
    }

    if let Ok(entries) = fs::read_dir(root.join("info")) {
        for entry in entries.flatten() {
            let _ = fs::remove_file(entry.path());
        }
    }

    Ok(removed)
}

fn unique_destination(directory: &Path, name: &Path) -> PathBuf {
    let file_name = name
        .file_name()
        .map(|value| value.to_os_string())
        .unwrap_or_else(|| OsString::from("item"));

    let candidate = directory.join(&file_name);
    if !candidate.exists() {
        return candidate;
    }

    let base = Path::new(&file_name);
    let stem = base
        .file_stem()
        .map(|value| value.to_string_lossy().into_owned())
        .unwrap_or_else(|| "item".to_string());
    let extension = base
        .extension()
        .map(|value| value.to_string_lossy().into_owned());

    for index in 1..10_000 {
        let next = match &extension {
            Some(extension) => format!("{stem}.{index}.{extension}"),
            None => format!("{stem}.{index}"),
        };

        let candidate = directory.join(next);
        if !candidate.exists() {
            return candidate;
        }
    }

    directory.join(format!("{stem}.{}", std::process::id()))
}

fn deletion_timestamp() -> std::string::String {
    if let Ok(output) = std::process::Command::new("date")
        .arg("+%Y-%m-%dT%H:%M:%S")
        .output()
    {
        if output.status.success() {
            let value = String::from_utf8_lossy(&output.stdout).trim().to_string();
            if !value.is_empty() {
                return value;
            }
        }
    }

    let seconds = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|duration| duration.as_secs() as i64)
        .unwrap_or(0);

    let days = seconds.div_euclid(86_400);
    let remainder = seconds.rem_euclid(86_400);
    let (year, month, day) = civil_from_days(days);

    format!(
        "{year:04}-{month:02}-{day:02}T{:02}:{:02}:{:02}",
        remainder / 3600,
        (remainder % 3600) / 60,
        remainder % 60
    )
}

fn civil_from_days(days_since_epoch: i64) -> (i64, u32, u32) {
    let shifted = days_since_epoch + 719_468;
    let era = if shifted >= 0 {
        shifted
    } else {
        shifted - 146_096
    } / 146_097;
    let day_of_era = shifted - era * 146_097;
    let year_of_era =
        (day_of_era - day_of_era / 1460 + day_of_era / 36_524 - day_of_era / 146_096) / 365;
    let year = year_of_era + era * 400;
    let day_of_year = day_of_era - (365 * year_of_era + year_of_era / 4 - year_of_era / 100);
    let month_part = (5 * day_of_year + 2) / 153;
    let day = day_of_year - (153 * month_part + 2) / 5 + 1;
    let month = if month_part < 10 {
        month_part + 3
    } else {
        month_part - 9
    };

    (
        if month <= 2 { year + 1 } else { year },
        month as u32,
        day as u32,
    )
}

#[flutter_rust_bridge::frb(sync)]
pub fn get_home_directory() -> std::string::String {
    home_dir().to_string_lossy().into_owned()
}

#[flutter_rust_bridge::frb]
pub fn get_disk_usage(path: std::string::String) -> Result<DiskUsage, std::string::String> {
    let target = Path::new(&path);

    if !target.exists() {
        return Err(format!("Path not found: {path}"));
    }

    let total_bytes = fs2::total_space(target).map_err(|error| error.to_string())?;
    let free_bytes = fs2::available_space(target).map_err(|error| error.to_string())?;

    Ok(DiskUsage {
        path,
        total_bytes,
        free_bytes,
        used_bytes: total_bytes.saturating_sub(free_bytes),
    })
}

pub fn list_places() -> Vec<Place> {
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

            if Path::new(&root).exists() {
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

pub fn list_recent_files(
    root: std::string::String,
    limit: u32,
) -> Result<Vec<FileEntry>, std::string::String> {
    let root = PathBuf::from(&root);

    if !root.is_dir() {
        return Err(format!("Path is not a directory: {root:?}"));
    }

    let max_visited: usize = 20_000;
    let max_candidates: usize = 4_000;

    let mut queue = VecDeque::from([root]);
    let mut candidates: Vec<FileEntry> = Vec::new();
    let mut visited = 0usize;

    while let Some(directory) = queue.pop_front() {
        if visited >= max_visited || candidates.len() >= max_candidates {
            break;
        }

        let Ok(entries) = fs::read_dir(&directory) else {
            continue;
        };

        for entry in entries.flatten() {
            visited += 1;
            if visited >= max_visited {
                break;
            }

            let name = entry.file_name().to_string_lossy().into_owned();
            if name.starts_with('.') {
                continue;
            }

            let path = entry.path();
            let Ok(metadata) = entry.metadata() else {
                continue;
            };

            if metadata.is_dir() {
                queue.push_back(path);
            } else if metadata.is_file() {
                candidates.push(entry_from_metadata(
                    name,
                    path.to_string_lossy().into_owned(),
                    &metadata,
                ));
            }
        }
    }

    candidates.sort_by(|a, b| b.modified_seconds.cmp(&a.modified_seconds));
    candidates.truncate(limit as usize);

    Ok(candidates)
}

pub fn open_in_terminal(path: std::string::String) -> Result<(), std::string::String> {
    let directory = Path::new(&path);

    if !directory.is_dir() {
        return Err(format!("Directory not found: {path}"));
    }

    #[cfg(target_os = "macos")]
    {
        std::process::Command::new("open")
            .arg("-a")
            .arg("Terminal")
            .arg(directory)
            .status()
            .map_err(|error| format!("Failed to open Terminal: {error}"))?;

        return Ok(());
    }

    #[cfg(windows)]
    {
        std::process::Command::new("cmd")
            .args(["/C", "start", "cmd", "/K"])
            .arg(format!("cd /d {}", directory.display()))
            .spawn()
            .map_err(|error| format!("Failed to open Command Prompt: {error}"))?;

        return Ok(());
    }

    #[cfg(all(unix, not(target_os = "macos")))]
    {
        const TERMINALS: [(&str, &[&str]); 9] = [
            ("gnome-terminal", &["--working-directory"]),
            ("konsole", &["--workdir"]),
            ("xfce4-terminal", &["--working-directory"]),
            ("kitty", &["--directory"]),
            ("alacritty", &["--working-directory"]),
            ("qterminal", &["--workdir"]),
            ("terminator", &["--working-directory"]),
            ("x-terminal-emulator", &["--working-directory"]),
            ("xterm", &[]),
        ];

        let quoted = shell_quote(&path);

        for (program, args) in TERMINALS {
            let available = std::process::Command::new("sh")
                .args(["-c", &format!("command -v {program} >/dev/null 2>&1")])
                .status()
                .map(|status| status.success())
                .unwrap_or(false);

            if !available {
                continue;
            }

            let argument = args.join(" ");
            let command = if argument.is_empty() {
                format!("cd {quoted} && exec {program}")
            } else {
                format!("exec {program} {argument} {quoted}")
            };

            std::process::Command::new("sh")
                .args(["-c", &format!("setsid {command} >/dev/null 2>&1 &")])
                .status()
                .map_err(|error| format!("Failed to run {program}: {error}"))?;

            return Ok(());
        }

        return Err("No terminal installed (gnome-terminal, konsole, xterm, ...)".to_string());
    }

    #[allow(unreachable_code)]
    Err("Terminal is not supported on this platform".to_string())
}

#[cfg(all(unix, not(target_os = "macos")))]
fn shell_quote(value: &str) -> std::string::String {
    format!("'{}'", value.replace('\'', "'\\''"))
}

#[flutter_rust_bridge::frb]
pub fn list_open_with_apps(path: std::string::String) -> Vec<OpenWithApp> {
    let mime = detect_mime_type(&path);
    let mut apps: Vec<OpenWithApp> = Vec::new();
    let mut seen: std::collections::HashSet<std::string::String> =
        std::collections::HashSet::new();

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

            if entry.no_display || entry.hidden || entry.app_type != "Application" {
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

    apps.sort_by(|a, b| a.name.to_lowercase().cmp(&b.name.to_lowercase()));
    apps
}

#[flutter_rust_bridge::frb]
pub fn open_with(
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
    no_display: bool,
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
    let mut no_display = false;
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
            "NoDisplay" => no_display = value.eq_ignore_ascii_case("true"),
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
        no_display,
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

#[cfg(test)]
mod tests {
    use super::*;
    use std::sync::Mutex;

    static ENV_LOCK: Mutex<()> = Mutex::new(());

    #[test]
    fn civil_from_days_matches_known_dates() {
        assert_eq!(civil_from_days(0), (1970, 1, 1));
        assert_eq!(civil_from_days(18_993), (2022, 1, 1));
    }

    #[test]
    fn unique_destination_appends_index() {
        let directory =
            std::env::temp_dir().join(format!("defile_unique_test_{}", std::process::id()));
        fs::create_dir_all(&directory).unwrap();
        fs::write(directory.join("file.txt"), "x").unwrap();

        let next = unique_destination(&directory, Path::new("file.txt"));
        assert_eq!(next.file_name().unwrap(), "file.1.txt");

        fs::write(directory.join("file.1.txt"), "x").unwrap();
        let next = unique_destination(&directory, Path::new("file.txt"));
        assert_eq!(next.file_name().unwrap(), "file.2.txt");

        let _ = fs::remove_dir_all(&directory);
    }

    #[test]
    #[cfg(all(unix, not(target_os = "macos")))]
    fn move_to_trash_writes_file_and_info() {
        let _guard = ENV_LOCK.lock().unwrap();

        let base = std::env::temp_dir().join(format!("defile_trash_test_{}", std::process::id()));
        let data_home = base.join("data");
        let work = base.join("work");
        fs::create_dir_all(&data_home).unwrap();
        fs::create_dir_all(&work).unwrap();

        std::env::set_var("XDG_DATA_HOME", &data_home);

        let source = work.join("hello.txt");
        fs::write(&source, "hi").unwrap();

        let destination = move_to_trash(source.to_string_lossy().into_owned()).unwrap();
        assert!(Path::new(&destination).exists());
        assert!(!source.exists());

        let info = data_home.join("Trash/info/hello.txt.trashinfo");
        let contents = fs::read_to_string(info).unwrap();
        assert!(contents.starts_with("[Trash Info]"));
        assert!(contents.contains(&format!("Path={}", source.display())));

        std::env::set_var("XDG_DATA_HOME", "");
        let _ = fs::remove_dir_all(&base);
    }

    #[test]
    #[cfg(all(unix, not(target_os = "macos")))]
    fn delete_from_trash_removes_item_and_info() {
        let _guard = ENV_LOCK.lock().unwrap();

        let base = std::env::temp_dir().join(format!("defile_trash_del_{}", std::process::id()));
        let data_home = base.join("data");
        let work = base.join("work");
        fs::create_dir_all(&data_home).unwrap();
        fs::create_dir_all(&work).unwrap();

        std::env::set_var("XDG_DATA_HOME", &data_home);

        let source = work.join("gone.txt");
        fs::write(&source, "hi").unwrap();

        let destination = move_to_trash(source.to_string_lossy().into_owned()).unwrap();
        assert!(Path::new(&destination).exists());

        delete_from_trash(destination.clone()).unwrap();
        assert!(!Path::new(&destination).exists());
        assert!(!data_home.join("Trash/info/gone.txt.trashinfo").exists());

        let outside = work.join("outside.txt");
        fs::write(&outside, "hi").unwrap();
        assert!(delete_from_trash(outside.to_string_lossy().into_owned()).is_err());

        std::env::set_var("XDG_DATA_HOME", "");
        let _ = fs::remove_dir_all(&base);
    }

    #[test]
    #[cfg(all(unix, not(target_os = "macos")))]
    fn empty_trash_clears_files_and_info() {
        let _guard = ENV_LOCK.lock().unwrap();

        let base = std::env::temp_dir().join(format!("defile_trash_empty_{}", std::process::id()));
        let data_home = base.join("data");
        let work = base.join("work");
        fs::create_dir_all(&data_home).unwrap();
        fs::create_dir_all(&work).unwrap();

        std::env::set_var("XDG_DATA_HOME", &data_home);

        let file = work.join("a.txt");
        fs::write(&file, "a").unwrap();
        move_to_trash(file.to_string_lossy().into_owned()).unwrap();

        let folder = work.join("dir");
        fs::create_dir_all(&folder).unwrap();
        fs::write(folder.join("inner.txt"), "b").unwrap();
        move_to_trash(folder.to_string_lossy().into_owned()).unwrap();

        let removed = empty_trash().unwrap();
        assert_eq!(removed, 2);

        let files_dir = data_home.join("Trash/files");
        assert_eq!(fs::read_dir(&files_dir).unwrap().count(), 0);
        assert_eq!(
            fs::read_dir(data_home.join("Trash/info")).unwrap().count(),
            0
        );

        std::env::set_var("XDG_DATA_HOME", "");
        let _ = fs::remove_dir_all(&base);
    }
}
