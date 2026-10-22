use std::path::Path;

use crate::api::file_entry::FileEntry;
use crate::api::paths::home_dir;
use crate::api::{open_with, places, recent, terminal, trash};

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

#[flutter_rust_bridge::frb]
pub fn move_to_trash(
    path: std::string::String,
) -> Result<std::string::String, std::string::String> {
    trash::move_to_trash(path)
}

#[flutter_rust_bridge::frb]
pub fn delete_from_trash(path: std::string::String) -> Result<(), std::string::String> {
    trash::delete_from_trash(path)
}

#[flutter_rust_bridge::frb]
pub fn empty_trash() -> Result<u32, std::string::String> {
    trash::empty_trash()
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
    places::list_places()
}

pub fn list_recent_files(
    root: std::string::String,
    limit: u32,
) -> Result<Vec<FileEntry>, std::string::String> {
    recent::list_recent_files(root, limit)
}

pub fn open_in_terminal(path: std::string::String) -> Result<(), std::string::String> {
    terminal::open_in_terminal(path)
}

#[flutter_rust_bridge::frb]
pub fn list_open_with_apps(path: std::string::String) -> Vec<OpenWithApp> {
    open_with::list_open_with_apps(path)
}

#[flutter_rust_bridge::frb]
pub fn open_with(
    path: std::string::String,
    desktop_file: std::string::String,
) -> Result<(), std::string::String> {
    open_with::open_with(path, desktop_file)
}
