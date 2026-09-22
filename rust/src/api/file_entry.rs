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

pub fn delete_entry(path: std::string::String) -> Result<(), std::string::String> {
    let target = Path::new(&path);

    let metadata = fs::symlink_metadata(target)
        .map_err(|error| format!("Item tidak ditemukan atau tidak dapat diakses: {error}"))?;

    let file_type = metadata.file_type();

    if file_type.is_dir() {
        fs::remove_dir(target)
            .map_err(|error| format!("Gagal menghapus folder. Pastikan folder kosong: {error}"))?;
    } else {
        fs::remove_file(target).map_err(|error| format!("Gagal menghapus file: {error}"))?;
    }

    Ok(())
}

pub fn rename_entry(
    source_path: std::string::String,
    new_name: std::string::String,
) -> Result<std::string::String, std::string::String> {
    let source = Path::new(&source_path);

    if !source.exists() {
        return Err(format!("File atau folder tidak ditemukan: {source_path}"));
    }

    let name = new_name.trim();

    if name.is_empty() {
        return Err("Nama baru tidak boleh kosong".to_string());
    }

    if name == "." || name == ".." || name.contains('/') || name.contains('\\') {
        return Err("Nama baru tidak valid".to_string());
    }

    let parent = source
        .parent()
        .ok_or("Tidak dapat menentukan direktori induk")?;

    let destination = parent.join(name);

    if source == destination {
        return Ok(destination.to_string_lossy().into_owned());
    }

    if destination.exists() {
        return Err(format!("Nama '{}' sudah digunakan", name));
    }

    fs::rename(source, &destination).map_err(|error| format!("Gagal mengganti nama: {error}"))?;

    Ok(destination.to_string_lossy().into_owned())
}

pub fn create_directory(
    parent_path: std::string::String,
    directory_name: std::string::String,
) -> Result<std::string::String, std::string::String> {
    let parent = Path::new(&parent_path);

    if !parent.exists() {
        return Err(format!("Direktori induk tidak ditemukan: {parent_path}"));
    }

    if !parent.is_dir() {
        return Err("Path induk bukan direktori".to_string());
    }

    let name = directory_name.trim();

    if name.is_empty() {
        return Err("Nama folder tidak boleh kosong".to_string());
    }

    if name == "." || name == ".." || name.contains('/') || name.contains('\\') {
        return Err("Nama folder tidak valid".to_string());
    }

    let new_path = parent.join(name);

    fs::create_dir(&new_path).map_err(|error| format!("Gagal membuat folder: {error}"))?;

    Ok(new_path.to_string_lossy().into_owned())
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
