use std::{collections::VecDeque, fs, path::PathBuf};

use crate::api::file_entry::{entry_from_metadata, FileEntry};

pub(crate) fn list_recent_files(
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

    candidates.sort_by_key(|entry| std::cmp::Reverse(entry.modified_seconds));
    candidates.truncate(limit as usize);

    Ok(candidates)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn skips_hidden_files_and_directories() {
        let root = std::env::temp_dir().join(format!("defile_recent_test_{}", std::process::id()));
        fs::create_dir_all(root.join("visible")).unwrap();
        fs::create_dir_all(root.join(".hidden")).unwrap();
        fs::write(root.join("visible/a.txt"), "a").unwrap();
        fs::write(root.join("visible/.hidden.txt"), "b").unwrap();
        fs::write(root.join(".hidden/c.txt"), "c").unwrap();

        let files = list_recent_files(root.to_string_lossy().into_owned(), 10).unwrap();
        let names: Vec<&str> = files.iter().map(|file| file.name.as_str()).collect();
        assert_eq!(names, vec!["a.txt"]);

        let _ = fs::remove_dir_all(&root);
    }
}
