use std::{env, path::PathBuf};

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
