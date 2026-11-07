use std::{
    fs, io,
    path::{Path, PathBuf},
    process::Command,
    time::UNIX_EPOCH,
};

#[derive(Debug, Clone)]
pub struct FileEntry {
    pub name: std::string::String,
    pub path: std::string::String,
    pub is_directory: bool,
    pub is_file: bool,
    pub size_bytes: u64,
    pub modified_seconds: i64,
}

pub(crate) fn entry_from_metadata(
    name: std::string::String,
    path: std::string::String,
    metadata: &fs::Metadata,
) -> FileEntry {
    let modified_seconds = metadata
        .modified()
        .ok()
        .and_then(|time| time.duration_since(UNIX_EPOCH).ok())
        .map(|duration| duration.as_secs() as i64)
        .unwrap_or(0);

    FileEntry {
        name,
        path,
        is_directory: metadata.is_dir(),
        is_file: metadata.is_file(),
        size_bytes: metadata.len(),
        modified_seconds,
    }
}

#[derive(Debug)]
pub enum FileOperationError {
    Io(std::string::String),
    InvalidName(std::string::String),
    DestinationExists(std::string::String),
    UnsupportedSymlink(std::string::String),
    InvalidPath(std::string::String),
}

impl From<io::Error> for FileOperationError {
    fn from(error: io::Error) -> Self {
        Self::Io(error.to_string())
    }
}

fn remove_existing(path: &Path) -> Result<(), FileOperationError> {
    let metadata = fs::symlink_metadata(path)?;

    if metadata.is_dir() {
        fs::remove_dir_all(path)?;
    } else {
        // Covers regular files and symlinks (nothing follows the link).
        fs::remove_file(path)?;
    }

    Ok(())
}

fn validate_name(name: &str) -> Result<(), FileOperationError> {
    if name.trim().is_empty()
        || name == "."
        || name == ".."
        || name.contains('/')
        || name.contains('\\')
    {
        return Err(FileOperationError::InvalidName(
            "Invalid destination name".to_string(),
        ));
    }

    Ok(())
}

fn copy_directory_recursive(source: &Path, destination: &Path) -> Result<(), FileOperationError> {
    fs::create_dir(destination)?;

    for entry in fs::read_dir(source)? {
        let entry = entry?;
        let source_path = entry.path();
        let destination_path = destination.join(entry.file_name());

        let metadata = fs::symlink_metadata(&source_path)?;

        if metadata.file_type().is_symlink() {
            return Err(FileOperationError::UnsupportedSymlink(
                source_path.display().to_string(),
            ));
        }

        if metadata.is_dir() {
            copy_directory_recursive(&source_path, &destination_path)?;
        } else if metadata.is_file() {
            fs::copy(&source_path, &destination_path)?;
        }
    }

    Ok(())
}

#[flutter_rust_bridge::frb]
pub fn copy_entry(
    source_path: std::string::String,
    destination_directory: std::string::String,
    new_name: std::string::String,
    overwrite: bool,
) -> Result<(), FileOperationError> {
    validate_name(&new_name)?;

    let source = PathBuf::from(source_path);
    let destination_dir = PathBuf::from(destination_directory);

    let metadata =
        fs::symlink_metadata(&source).map_err(|error| FileOperationError::Io(error.to_string()))?;

    if metadata.file_type().is_symlink() {
        return Err(FileOperationError::UnsupportedSymlink(
            source.display().to_string(),
        ));
    }

    if !destination_dir.is_dir() {
        return Err(FileOperationError::InvalidPath(
            "Destination folder not found".to_string(),
        ));
    }

    let destination = destination_dir.join(new_name);

    if destination == source {
        return Err(FileOperationError::InvalidPath(
            "Source and destination are the same".to_string(),
        ));
    }

    if metadata.is_dir() && (destination.starts_with(&source) || source.starts_with(&destination)) {
        return Err(FileOperationError::InvalidPath(
            "Invalid source and destination folders".to_string(),
        ));
    }

    if destination.exists() {
        if !overwrite {
            return Err(FileOperationError::DestinationExists(
                destination.display().to_string(),
            ));
        }

        let destination_metadata = fs::symlink_metadata(&destination)
            .map_err(|error| FileOperationError::Io(error.to_string()))?;

        // A regular file can simply be rewritten by fs::copy; directories and
        // symlinks must be removed first so their old contents cannot leak
        // into the replacement.
        if metadata.is_dir()
            || destination_metadata.is_dir()
            || destination_metadata.file_type().is_symlink()
        {
            remove_existing(&destination)?;
        }
    }

    if metadata.is_dir() {
        copy_directory_recursive(&source, &destination)?;
    } else if metadata.is_file() {
        fs::copy(&source, &destination)?;
    } else {
        return Err(FileOperationError::InvalidPath(
            "Unsupported file type".to_string(),
        ));
    }

    Ok(())
}

#[flutter_rust_bridge::frb]
pub fn move_entry(
    source_path: std::string::String,
    destination_directory: std::string::String,
    new_name: std::string::String,
    overwrite: bool,
) -> Result<(), FileOperationError> {
    validate_name(&new_name)?;

    let source = PathBuf::from(source_path);
    let destination_dir = PathBuf::from(destination_directory);

    let metadata =
        fs::symlink_metadata(&source).map_err(|error| FileOperationError::Io(error.to_string()))?;

    if !destination_dir.is_dir() {
        return Err(FileOperationError::InvalidPath(
            "Destination folder not found".to_string(),
        ));
    }

    let destination = destination_dir.join(new_name);

    if destination == source {
        return Err(FileOperationError::InvalidPath(
            "Source and destination are the same".to_string(),
        ));
    }

    if metadata.is_dir() && (destination.starts_with(&source) || source.starts_with(&destination)) {
        return Err(FileOperationError::InvalidPath(
            "Invalid source and destination folders".to_string(),
        ));
    }

    if destination.exists() {
        if !overwrite {
            return Err(FileOperationError::DestinationExists(
                destination.display().to_string(),
            ));
        }

        remove_existing(&destination)?;
    }

    fs::rename(&source, &destination)?;

    Ok(())
}

pub fn delete_entry(path: std::string::String) -> Result<(), std::string::String> {
    let target = Path::new(&path);

    let metadata = fs::symlink_metadata(target)
        .map_err(|error| format!("Item not found or not accessible: {error}"))?;

    let file_type = metadata.file_type();

    if file_type.is_dir() {
        fs::remove_dir(target).map_err(|error| {
            format!("Failed to delete folder. Make sure the folder is empty: {error}")
        })?;
    } else {
        fs::remove_file(target).map_err(|error| format!("Failed to delete file: {error}"))?;
    }

    Ok(())
}

pub fn delete_entry_recursive(path: std::string::String) -> Result<(), std::string::String> {
    let target = Path::new(&path);

    let metadata = fs::symlink_metadata(target)
        .map_err(|error| format!("Item not found or not accessible: {error}"))?;

    let file_type = metadata.file_type();

    if file_type.is_symlink() || file_type.is_file() {
        fs::remove_file(target).map_err(|error| format!("Failed to delete file: {error}"))?;
    } else if file_type.is_dir() {
        fs::remove_dir_all(target)
            .map_err(|error| format!("Failed to delete folder and its contents: {error}"))?;
    } else {
        return Err("Unsupported item type".to_string());
    }

    Ok(())
}

pub fn rename_entry(
    source_path: std::string::String,
    new_name: std::string::String,
) -> Result<std::string::String, std::string::String> {
    let source = Path::new(&source_path);

    if !source.exists() {
        return Err(format!("File or folder not found: {source_path}"));
    }

    let name = new_name.trim();

    if name.is_empty() {
        return Err("New name cannot be empty".to_string());
    }

    if name == "." || name == ".." || name.contains('/') || name.contains('\\') {
        return Err("Invalid new name".to_string());
    }

    let parent = source.parent().ok_or("Cannot determine parent directory")?;

    let destination = parent.join(name);

    if source == destination {
        return Ok(destination.to_string_lossy().into_owned());
    }

    if destination.exists() {
        return Err(format!("Name '{}' is already in use", name));
    }

    fs::rename(source, &destination).map_err(|error| format!("Failed to rename: {error}"))?;

    Ok(destination.to_string_lossy().into_owned())
}

pub fn create_directory(
    parent_path: std::string::String,
    directory_name: std::string::String,
) -> Result<std::string::String, std::string::String> {
    let parent = Path::new(&parent_path);

    if !parent.exists() {
        return Err(format!("Parent directory not found: {parent_path}"));
    }

    if !parent.is_dir() {
        return Err("Parent path is not a directory".to_string());
    }

    let name = directory_name.trim();

    if name.is_empty() {
        return Err("Folder name cannot be empty".to_string());
    }

    if name == "." || name == ".." || name.contains('/') || name.contains('\\') {
        return Err("Invalid folder name".to_string());
    }

    let new_path = parent.join(name);

    fs::create_dir(&new_path).map_err(|error| format!("Failed to create folder: {error}"))?;

    Ok(new_path.to_string_lossy().into_owned())
}

pub fn list_directory(path: std::string::String) -> Result<Vec<FileEntry>, std::string::String> {
    let directory = Path::new(&path);
    if !directory.exists() {
        return Err(format!("Path not found: {}", path));
    }

    if !directory.is_dir() {
        return Err(format!("Path is not a directory: {}", path));
    }

    let entries = fs::read_dir(directory).map_err(|err| err.to_string())?;

    let mut result = Vec::new();
    for entry in entries {
        // A single broken entry — a stale FUSE mount, a vanished file, a
        // permission trap — must not fail the whole directory. Every other
        // file manager shows the rest and skips the broken one.
        let entry = match entry {
            Ok(entry) => entry,
            Err(_) => continue,
        };

        let item_path = entry.path();
        let metadata = match entry.metadata() {
            Ok(metadata) => metadata,
            Err(_) => continue,
        };

        let name = entry.file_name().to_string_lossy().into_owned();
        let path = item_path.to_string_lossy().into_owned();

        result.push(entry_from_metadata(name, path, &metadata));
    }

    result.sort_by_cached_key(|entry| (!entry.is_directory, entry.name.to_lowercase()));

    Ok(result)
}

pub fn open_file(path: String) -> Result<(), String> {
    let file_path = Path::new(&path);

    if !file_path.exists() {
        return Err(format!("File not found: {path}"));
    }

    if !file_path.is_file() {
        return Err(format!("Path is not a file: {path}"));
    }

    let status = Command::new("xdg-open")
        .arg(file_path)
        .status()
        .map_err(|error| format!("Failed to run xdg-open: {error}"))?;

    if !status.success() {
        return Err(format!("xdg-open failed to open file: {path}"));
    }

    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    fn workspace(tag: &str) -> PathBuf {
        let dir = std::env::temp_dir().join(format!(
            "defile_file_entry_test_{tag}_{}",
            std::process::id()
        ));
        fs::remove_dir_all(&dir).ok();
        fs::create_dir_all(&dir).unwrap();
        dir
    }

    fn path_string(path: &Path) -> std::string::String {
        path.to_string_lossy().into_owned()
    }

    #[test]
    fn copy_refuses_to_replace_without_overwrite() {
        let dir = workspace("copy_no_overwrite");
        let source = dir.join("index.html");
        let destination_dir = dir.join("dest");
        fs::create_dir_all(&destination_dir).unwrap();
        fs::write(&source, "new").unwrap();
        fs::write(destination_dir.join("index.html"), "old").unwrap();

        let result = copy_entry(
            path_string(&source),
            path_string(&destination_dir),
            "index.html".to_string(),
            false,
        );

        assert!(matches!(
            result,
            Err(FileOperationError::DestinationExists(_))
        ));
        assert_eq!(
            fs::read_to_string(destination_dir.join("index.html")).unwrap(),
            "old"
        );

        fs::remove_dir_all(&dir).ok();
    }

    #[test]
    fn copy_replaces_existing_file_when_overwrite_is_set() {
        let dir = workspace("copy_overwrite_file");
        let source = dir.join("index.html");
        let destination_dir = dir.join("dest");
        fs::create_dir_all(&destination_dir).unwrap();
        fs::write(&source, "new content").unwrap();
        fs::write(destination_dir.join("index.html"), "old content").unwrap();

        copy_entry(
            path_string(&source),
            path_string(&destination_dir),
            "index.html".to_string(),
            true,
        )
        .unwrap();

        assert_eq!(
            fs::read_to_string(destination_dir.join("index.html")).unwrap(),
            "new content"
        );
        // Copy keeps the source in place.
        assert_eq!(fs::read_to_string(&source).unwrap(), "new content");

        fs::remove_dir_all(&dir).ok();
    }

    #[test]
    fn copy_replaces_directory_without_leaving_stale_children() {
        let dir = workspace("copy_overwrite_dir");
        let source = dir.join("project");
        let destination_dir = dir.join("dest");
        fs::create_dir_all(source.join("new")).unwrap();
        fs::create_dir_all(destination_dir.join("project/old")).unwrap();
        fs::write(source.join("index.html"), "new").unwrap();
        fs::write(destination_dir.join("project/old/stale.txt"), "stale").unwrap();

        copy_entry(
            path_string(&source),
            path_string(&destination_dir),
            "project".to_string(),
            true,
        )
        .unwrap();

        assert!(destination_dir.join("project/index.html").is_file());
        assert!(destination_dir.join("project/new").is_dir());
        assert!(!destination_dir.join("project/old").exists());

        fs::remove_dir_all(&dir).ok();
    }

    #[test]
    fn move_replaces_existing_file_and_removes_source() {
        let dir = workspace("move_overwrite");
        let source = dir.join("index.html");
        let destination_dir = dir.join("dest");
        fs::create_dir_all(&destination_dir).unwrap();
        fs::write(&source, "new").unwrap();
        fs::write(destination_dir.join("index.html"), "old").unwrap();

        move_entry(
            path_string(&source),
            path_string(&destination_dir),
            "index.html".to_string(),
            true,
        )
        .unwrap();

        assert_eq!(
            fs::read_to_string(destination_dir.join("index.html")).unwrap(),
            "new"
        );
        assert!(!source.exists());

        fs::remove_dir_all(&dir).ok();
    }

    #[test]
    fn copy_onto_itself_is_rejected_without_touching_the_file() {
        let dir = workspace("copy_self");
        let source = dir.join("index.html");
        fs::write(&source, "keep me").unwrap();

        let result = copy_entry(
            path_string(&source),
            path_string(&dir),
            "index.html".to_string(),
            true,
        );

        assert!(matches!(result, Err(FileOperationError::InvalidPath(_))));
        assert_eq!(fs::read_to_string(&source).unwrap(), "keep me");

        fs::remove_dir_all(&dir).ok();
    }
}
