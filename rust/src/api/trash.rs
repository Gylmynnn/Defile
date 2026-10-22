use std::{
    ffi::OsString,
    fs,
    path::{Path, PathBuf},
    time::{SystemTime, UNIX_EPOCH},
};

use crate::api::paths::{home_dir, trash_dir, trash_root};

pub(crate) fn move_to_trash(
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

pub(crate) fn delete_from_trash(path: std::string::String) -> Result<(), std::string::String> {
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

pub(crate) fn empty_trash() -> Result<u32, std::string::String> {
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
