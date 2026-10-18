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

    if destination.exists() {
        return Err(FileOperationError::DestinationExists(
            destination.display().to_string(),
        ));
    }

    if metadata.is_dir() {
        if destination.starts_with(&source) || source.starts_with(&destination) {
            return Err(FileOperationError::InvalidPath(
                "Invalid source and destination folders".to_string(),
            ));
        }

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

    if destination.exists() {
        return Err(FileOperationError::DestinationExists(
            destination.display().to_string(),
        ));
    }

    if metadata.is_dir() && (destination.starts_with(&source) || source.starts_with(&destination)) {
        return Err(FileOperationError::InvalidPath(
            "Invalid source and destination folders".to_string(),
        ));
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
        fs::remove_dir(target)
            .map_err(|error| format!("Failed to delete folder. Make sure the folder is empty: {error}"))?;
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

    let parent = source
        .parent()
        .ok_or("Cannot determine parent directory")?;

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
        let entry = entry.map_err(|err| err.to_string())?;

        let item_path = entry.path();
        let metadata = entry.metadata().map_err(|err| err.to_string())?;

        let name = entry.file_name().to_string_lossy().into_owned();
        let path = item_path.to_string_lossy().into_owned();

        result.push(entry_from_metadata(name, path, &metadata));
    }

    result.sort_by(|a, b| {
        b.is_directory
            .cmp(&a.is_directory)
            .then_with(|| a.name.to_lowercase().cmp(&b.name.to_lowercase()))
    });

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
