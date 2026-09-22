use std::fs;
use std::path::Path;
use std::process::Command;

#[derive(Debug, Clone)]
pub struct FileEntry {
    pub name: std::string::String,
    pub path: std::string::String,
    pub is_directory: bool,
    pub is_file: bool,
}

pub fn list_directory(path: std::string::String) -> Result<Vec<FileEntry>, std::string::String> {
    let directory = Path::new(&path);
    if !directory.exists() {
        return Err(format!("Path tidak ditemukan: {}", path));
    }

    if !directory.is_dir() {
        return Err(format!("Path bukan directory: {}", path));
    }

    let entries = fs::read_dir(directory).map_err(|err| err.to_string())?;

    let mut result = Vec::new();
    for entry in entries {
        let entry = entry.map_err(|err| err.to_string())?;

        let item_path = entry.path();
        let metadata = entry.metadata().map_err(|err| err.to_string())?;

        let name = entry.file_name().to_string_lossy().into_owned();
        let path = item_path.to_string_lossy().into_owned();

        result.push(FileEntry {
            name,
            path,
            is_directory: metadata.is_dir(),
            is_file: metadata.is_file(),
        });
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
        return Err(format!("File tidak ditemukan: {path}"));
    }

    if !file_path.is_file() {
        return Err(format!("Path bukan file: {path}"));
    }

    let status = Command::new("xdg-open")
        .arg(file_path)
        .status()
        .map_err(|error| format!("Gagal menjalankan xdg-open: {error}"))?;

    if !status.success() {
        return Err(format!("xdg-open gagal membuka file: {path}"));
    }

    Ok(())
}
