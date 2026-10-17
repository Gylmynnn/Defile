use std::{
    fs,
    path::{Path, PathBuf},
    time::{SystemTime, UNIX_EPOCH},
};

#[derive(Debug, Clone)]
pub struct EntryProperties {
    pub name: std::string::String,
    pub path: std::string::String,
    pub kind: std::string::String,
    pub link_target: Option<std::string::String>,
    pub is_directory: bool,
    pub size_bytes: u64,
    pub size_on_disk_bytes: u64,
    pub created_seconds: i64,
    pub modified_seconds: i64,
    pub accessed_seconds: i64,
    pub file_count: u64,
    pub folder_count: u64,
}

#[derive(Default)]
#[flutter_rust_bridge::frb(ignore)]
struct DirectoryTotals {
    size_bytes: u64,
    size_on_disk_bytes: u64,
    file_count: u64,
    folder_count: u64,
}

#[flutter_rust_bridge::frb]
pub fn get_entry_properties(
    path: std::string::String,
) -> Result<EntryProperties, std::string::String> {
    let target = PathBuf::from(&path);

    let metadata = fs::symlink_metadata(&target)
        .map_err(|error| format!("Item tidak dapat dibaca: {error}"))?;

    let file_type = metadata.file_type();
    let name = target
        .file_name()
        .map(|value| value.to_string_lossy().into_owned())
        .unwrap_or_else(|| path.clone());

    let link_target = if file_type.is_symlink() {
        fs::read_link(&target)
            .ok()
            .map(|value| value.to_string_lossy().into_owned())
    } else {
        None
    };

    let is_directory = file_type.is_dir();

    let (size_bytes, size_on_disk_bytes, file_count, folder_count) = if is_directory {
        let totals = directory_totals(&target);
        (
            totals.size_bytes,
            totals.size_on_disk_bytes,
            totals.file_count,
            totals.folder_count,
        )
    } else {
        (metadata.len(), allocated_bytes(&metadata), 0, 0)
    };

    Ok(EntryProperties {
        name,
        path: target.to_string_lossy().into_owned(),
        kind: describe_kind(&target, &file_type),
        link_target,
        is_directory,
        size_bytes,
        size_on_disk_bytes,
        created_seconds: seconds(metadata.created()),
        modified_seconds: seconds(metadata.modified()),
        accessed_seconds: seconds(metadata.accessed()),
        file_count,
        folder_count,
    })
}

fn directory_totals(root: &Path) -> DirectoryTotals {
    let mut totals = DirectoryTotals::default();

    if let Ok(metadata) = fs::symlink_metadata(root) {
        totals.size_on_disk_bytes += allocated_bytes(&metadata);
    }

    let mut stack: Vec<PathBuf> = vec![root.to_path_buf()];

    while let Some(directory) = stack.pop() {
        let Ok(entries) = fs::read_dir(&directory) else {
            continue;
        };

        for entry in entries.flatten() {
            let Ok(metadata) = entry.metadata() else {
                continue;
            };

            totals.size_on_disk_bytes += allocated_bytes(&metadata);

            if metadata.is_dir() {
                totals.folder_count += 1;
                stack.push(entry.path());
            } else {
                totals.file_count += 1;
                totals.size_bytes += metadata.len();
            }
        }
    }

    totals
}

fn seconds(time: std::io::Result<SystemTime>) -> i64 {
    time.ok()
        .and_then(|value| value.duration_since(UNIX_EPOCH).ok())
        .map(|duration| duration.as_secs() as i64)
        .unwrap_or(0)
}

#[cfg(unix)]
fn allocated_bytes(metadata: &fs::Metadata) -> u64 {
    use std::os::unix::fs::MetadataExt;

    metadata.blocks().saturating_mul(512)
}

#[cfg(not(unix))]
fn allocated_bytes(metadata: &fs::Metadata) -> u64 {
    metadata.len()
}

fn describe_kind(path: &Path, file_type: &fs::FileType) -> std::string::String {
    if file_type.is_symlink() {
        return "Symbolic link".to_string();
    }

    if file_type.is_dir() {
        return "Folder".to_string();
    }

    let extension = path
        .extension()
        .map(|value| value.to_string_lossy().to_lowercase())
        .unwrap_or_default();

    match extension.as_str() {
        "" => "File".to_string(),
        "png" | "jpg" | "jpeg" | "gif" | "webp" | "bmp" | "svg" | "ico" | "heic" | "tiff" => {
            format!("{} image", extension.to_uppercase())
        }
        "mp4" | "mkv" | "avi" | "mov" | "webm" | "flv" | "wmv" | "m4v" | "mpg" | "mpeg" => {
            format!("{} video", extension.to_uppercase())
        }
        "mp3" | "wav" | "flac" | "ogg" | "m4a" | "aac" | "opus" | "wma" | "mid" => {
            format!("{} audio", extension.to_uppercase())
        }
        "pdf" => "PDF document".to_string(),
        "txt" | "md" | "rtf" | "log" => "Text document".to_string(),
        "doc" | "docx" | "odt" => "Word document".to_string(),
        "xls" | "xlsx" | "ods" | "csv" => "Spreadsheet".to_string(),
        "ppt" | "pptx" | "odp" => "Presentation".to_string(),
        "zip" | "rar" | "7z" | "tar" | "gz" | "bz2" | "xz" | "zst" => "Archive".to_string(),
        "iso" | "img" => "Disc image".to_string(),
        "deb" | "rpm" | "apk" | "msi" | "pkg" => "Package".to_string(),
        "sh" | "bash" | "zsh" | "fish" => "Shell script".to_string(),
        "dart" | "rs" | "py" | "js" | "ts" | "tsx" | "jsx" | "c" | "h" | "cpp" | "hpp" | "java"
        | "kt" | "go" | "rb" | "php" | "html" | "css" | "scss" | "json" | "yaml" | "yml"
        | "toml" | "xml" | "sql" | "lua" | "vim" => {
            format!("{} source file", extension.to_uppercase())
        }
        _ => format!("{} file", extension.to_uppercase()),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn directory_totals_and_kind() {
        let root = std::env::temp_dir().join(format!("defile_props_test_{}", std::process::id()));
        let sub = root.join("sub");
        fs::create_dir_all(&sub).unwrap();
        fs::create_dir_all(root.join("empty")).unwrap();
        fs::write(root.join("a.txt"), "hello").unwrap();
        fs::write(sub.join("b.bin"), "world!").unwrap();

        let properties = get_entry_properties(root.to_string_lossy().into_owned()).unwrap();
        assert_eq!(properties.kind, "Folder");
        assert!(properties.is_directory);
        assert_eq!(properties.size_bytes, 11);
        assert_eq!(properties.file_count, 2);
        assert_eq!(properties.folder_count, 2);
        assert!(properties.modified_seconds > 0);

        let file = get_entry_properties(root.join("a.txt").to_string_lossy().into_owned()).unwrap();
        assert_eq!(file.kind, "Text document");
        assert_eq!(file.size_bytes, 5);
        assert_eq!(file.file_count, 0);

        let binary =
            get_entry_properties(root.join("sub/b.bin").to_string_lossy().into_owned()).unwrap();
        assert_eq!(binary.kind, "BIN file");

        let _ = fs::remove_dir_all(&root);
    }

    #[cfg(unix)]
    #[test]
    fn symlink_is_described_without_following() {
        let root =
            std::env::temp_dir().join(format!("defile_props_link_test_{}", std::process::id()));
        fs::create_dir_all(&root).unwrap();
        let target = root.join("target.txt");
        fs::write(&target, "hi").unwrap();
        let link = root.join("link.txt");
        std::os::unix::fs::symlink(&target, &link).unwrap();

        let properties = get_entry_properties(link.to_string_lossy().into_owned()).unwrap();
        assert_eq!(properties.kind, "Symbolic link");
        assert_eq!(
            properties.link_target,
            Some(target.to_string_lossy().into_owned())
        );
        assert!(!properties.is_directory);

        let _ = fs::remove_dir_all(&root);
    }
}
