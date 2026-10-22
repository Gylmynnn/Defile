use std::{
    collections::{HashMap, HashSet, VecDeque},
    env, fs,
    path::{Path, PathBuf},
    sync::{Mutex, OnceLock},
    time::SystemTime,
};

use crate::api::paths::home_dir;
use crate::api::settings::{read_setting, write_setting};

#[derive(Debug, Clone)]
pub struct IconThemeEntry {
    pub name: std::string::String,
    pub path: std::string::String,
}

#[derive(Clone)]
struct IconDir {
    rel: std::string::String,
    size: u32,
    scalable: bool,
}

#[derive(Clone)]
struct ThemeIndex {
    dirs: Vec<IconDir>,
    inherits: Vec<std::string::String>,
}

fn parse_index_theme(path: &Path) -> Option<ThemeIndex> {
    type Cache = HashMap<PathBuf, (Option<SystemTime>, ThemeIndex)>;
    static CACHE: OnceLock<Mutex<Cache>> = OnceLock::new();

    let modified = fs::metadata(path).and_then(|meta| meta.modified()).ok();
    let cache = CACHE.get_or_init(|| Mutex::new(HashMap::new()));
    let cached = {
        let cache = cache.lock().unwrap_or_else(|error| error.into_inner());
        cache
            .get(path)
            .filter(|(cached_modified, _)| *cached_modified == modified)
            .map(|(_, index)| index.clone())
    };

    if let Some(index) = cached {
        return Some(index);
    }

    let index = parse_index_theme_uncached(path)?;
    let mut cache = cache.lock().unwrap_or_else(|error| error.into_inner());
    cache.insert(path.to_path_buf(), (modified, index.clone()));
    Some(index)
}

fn parse_index_theme_uncached(path: &Path) -> Option<ThemeIndex> {
    let contents = fs::read_to_string(path).ok()?;

    let mut dirs: Vec<IconDir> = Vec::new();
    let mut inherits: Vec<std::string::String> = Vec::new();
    let mut current: Option<(std::string::String, Option<u32>, bool)> = None;

    let flush = |current: &mut Option<(std::string::String, Option<u32>, bool)>,
                 dirs: &mut Vec<IconDir>| {
        if let Some((rel, Some(size), scalable)) = current.take() {
            dirs.push(IconDir {
                rel,
                size,
                scalable,
            });
        }
    };

    for raw in contents.lines() {
        let line = raw.trim();

        if line.is_empty() || line.starts_with('#') {
            continue;
        }

        if line.starts_with('[') && line.ends_with(']') {
            flush(&mut current, &mut dirs);
            let section = line[1..line.len() - 1].trim().to_string();
            current = Some((section, None, false));
            continue;
        }

        let Some((key, value)) = line.split_once('=') else {
            continue;
        };

        let key = key.trim();
        let value = value.trim();

        match &mut current {
            Some((section, size, scalable)) if !section.eq_ignore_ascii_case("Icon Theme") => {
                if key.eq_ignore_ascii_case("Size") {
                    *size = value.parse().ok();
                } else if key.eq_ignore_ascii_case("Type") {
                    *scalable = value.eq_ignore_ascii_case("Scalable");
                }
            }
            _ => {
                if key.eq_ignore_ascii_case("Inherits") {
                    inherits = value
                        .split(',')
                        .map(str::trim)
                        .filter(|item| !item.is_empty())
                        .map(std::string::String::from)
                        .collect();
                }
            }
        }
    }

    flush(&mut current, &mut dirs);

    Some(ThemeIndex { dirs, inherits })
}

pub(crate) fn icon_search_roots() -> Vec<PathBuf> {
    let home = home_dir();
    let mut roots = vec![home.join(".icons")];

    match env::var("XDG_DATA_HOME") {
        Ok(value) if !value.is_empty() => roots.push(PathBuf::from(value).join("icons")),
        _ => roots.push(home.join(".local/share/icons")),
    }

    roots.push(PathBuf::from("/usr/local/share/icons"));
    roots.push(PathBuf::from("/usr/share/icons"));

    roots
}

fn locate_theme(roots: &[PathBuf], name: &str) -> Option<PathBuf> {
    for root in roots {
        let candidate = root.join(name);
        if candidate.join("index.theme").is_file() {
            return Some(candidate);
        }
    }

    None
}

fn theme_chain(roots: &[PathBuf], theme: &str) -> Vec<PathBuf> {
    let mut visited: HashSet<std::string::String> = HashSet::new();
    let mut queue: VecDeque<std::string::String> = VecDeque::new();

    if !theme.is_empty() {
        queue.push_back(theme.to_string());
    }
    queue.push_back("hicolor".to_string());

    let mut chain: Vec<PathBuf> = Vec::new();

    while let Some(name) = queue.pop_front() {
        if !visited.insert(name.clone()) {
            continue;
        }

        let Some(theme_path) = locate_theme(roots, &name) else {
            continue;
        };

        if let Some(index) = parse_index_theme(&theme_path.join("index.theme")) {
            for parent in index.inherits {
                if !visited.contains(&parent) {
                    queue.push_back(parent);
                }
            }
        }

        chain.push(theme_path);
    }

    chain
}

fn find_icon_candidates_in_roots(
    roots: &[PathBuf],
    theme: &str,
    name: &str,
    size: u32,
) -> Vec<PathBuf> {
    let file_names = [format!("{name}.png"), format!("{name}.svg")];
    let mut candidates: Vec<(u32, usize, PathBuf)> = Vec::new();

    for (depth, theme_path) in theme_chain(roots, theme).iter().enumerate() {
        let Some(index) = parse_index_theme(&theme_path.join("index.theme")) else {
            continue;
        };

        for dir in &index.dirs {
            for file_name in &file_names {
                let candidate = theme_path.join(&dir.rel).join(file_name);
                if !candidate.is_file() {
                    continue;
                }

                let distance = dir.size.abs_diff(size);
                let score = if dir.scalable { distance + 1 } else { distance };

                candidates.push((score, depth, candidate));
            }
        }
    }

    candidates.sort_by(|a, b| a.1.cmp(&b.1).then(a.0.cmp(&b.0)));

    candidates.into_iter().map(|(_, _, path)| path).collect()
}

fn find_icon_in_roots(roots: &[PathBuf], theme: &str, name: &str, size: u32) -> Option<PathBuf> {
    find_icon_candidates_in_roots(roots, theme, name, size)
        .into_iter()
        .next()
}

const USABILITY_ICON_NAMES: [&str; 5] = [
    "folder",
    "inode-directory",
    "text-x-generic",
    "text-plain",
    "application-x-executable",
];

fn theme_is_usable(roots: &[PathBuf], name: &str) -> bool {
    USABILITY_ICON_NAMES
        .iter()
        .any(|icon| find_icon_in_roots(roots, name, icon, 48).is_some())
}

fn list_icon_themes_in_roots(roots: &[PathBuf]) -> Vec<IconThemeEntry> {
    let mut seen: HashSet<std::string::String> = HashSet::new();
    let mut themes: Vec<IconThemeEntry> = Vec::new();

    for root in roots {
        let Ok(entries) = fs::read_dir(root) else {
            continue;
        };

        for entry in entries.flatten() {
            let path = entry.path();

            if !path.join("index.theme").is_file() {
                continue;
            }

            let name = entry.file_name().to_string_lossy().into_owned();
            if name.starts_with('.') || !seen.insert(name.clone()) || !theme_is_usable(roots, &name)
            {
                continue;
            }

            themes.push(IconThemeEntry {
                name,
                path: path.to_string_lossy().into_owned(),
            });
        }
    }

    themes.sort_by_key(|theme| theme.name.to_lowercase());
    themes
}

#[flutter_rust_bridge::frb]
pub fn list_icon_themes() -> Vec<IconThemeEntry> {
    list_icon_themes_in_roots(&icon_search_roots())
}

#[flutter_rust_bridge::frb]
pub fn find_icon(
    theme: std::string::String,
    icon_names: Vec<std::string::String>,
    size: u32,
) -> Option<std::string::String> {
    let roots = icon_search_roots();

    for name in &icon_names {
        if let Some(path) = find_icon_in_roots(&roots, &theme, name, size) {
            return Some(path.to_string_lossy().into_owned());
        }
    }

    None
}

fn render_svg(path: &Path, size: u32) -> Option<Vec<u8>> {
    let data = fs::read(path).ok()?;
    let tree = resvg::usvg::Tree::from_data(&data, &resvg::usvg::Options::default()).ok()?;

    let svg_size = tree.size();
    let scale = (size as f32 / svg_size.width()).min(size as f32 / svg_size.height());
    let dx = (size as f32 - svg_size.width() * scale) / 2.0;
    let dy = (size as f32 - svg_size.height() * scale) / 2.0;

    let mut pixmap = resvg::tiny_skia::Pixmap::new(size, size)?;
    let transform = resvg::tiny_skia::Transform::from_scale(scale, scale).post_translate(dx, dy);
    resvg::render(&tree, transform, &mut pixmap.as_mut());

    pixmap.encode_png().ok()
}

const PNG_SIGNATURE: [u8; 8] = [0x89, b'P', b'N', b'G', 0x0D, 0x0A, 0x1A, 0x0A];

fn icon_png_in_roots(
    roots: &[PathBuf],
    theme: &str,
    icon_names: &[std::string::String],
    size: u32,
) -> Option<Vec<u8>> {
    for name in icon_names {
        for path in find_icon_candidates_in_roots(roots, theme, name, size) {
            let is_svg = path
                .extension()
                .and_then(|ext| ext.to_str())
                .is_some_and(|ext| ext.eq_ignore_ascii_case("svg"));

            if is_svg {
                if let Some(bytes) = render_svg(&path, size) {
                    return Some(bytes);
                }

                continue;
            }

            if let Ok(bytes) = fs::read(&path) {
                if bytes.starts_with(&PNG_SIGNATURE) {
                    return Some(bytes);
                }
            }
        }
    }

    None
}

#[flutter_rust_bridge::frb]
pub fn icon_png(
    theme: std::string::String,
    icon_names: Vec<std::string::String>,
    size: u32,
) -> Option<Vec<u8>> {
    let size = size.clamp(8, 512);
    icon_png_in_roots(&icon_search_roots(), &theme, &icon_names, size)
}

#[flutter_rust_bridge::frb]
pub fn get_icon_theme() -> std::string::String {
    read_setting("icon-theme")
}

#[flutter_rust_bridge::frb]
pub fn set_icon_theme(name: std::string::String) -> Result<(), std::string::String> {
    write_setting("icon-theme", &name)
}

#[cfg(test)]
mod tests {
    use super::*;

    fn write_theme(root: &Path, name: &str, index: &str) {
        let path = root.join(name);
        fs::create_dir_all(&path).unwrap();
        fs::write(path.join("index.theme"), index).unwrap();
    }

    fn write_png(path: &Path) {
        fs::create_dir_all(path.parent().unwrap()).unwrap();
        let mut bytes = PNG_SIGNATURE.to_vec();
        bytes.extend_from_slice(b"data");
        fs::write(path, bytes).unwrap();
    }

    fn write_broken_symlink_dump(path: &Path) {
        fs::create_dir_all(path.parent().unwrap()).unwrap();
        fs::write(path, b"qpdfview.svg").unwrap();
    }

    fn write_svg(path: &Path) {
        fs::create_dir_all(path.parent().unwrap()).unwrap();
        fs::write(
            path,
            "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"16\" height=\"16\"><rect width=\"16\" height=\"16\" fill=\"#e33\"/></svg>",
        )
        .unwrap();
    }

    #[test]
    fn parses_index_theme_sections_and_inherits() {
        let directory =
            std::env::temp_dir().join(format!("defile_index_test_{}", std::process::id()));
        fs::create_dir_all(&directory).unwrap();

        let index = directory.join("index.theme");
        fs::write(
            &index,
            "[Icon Theme]\nName=Test\nInherits=Adwaita, hicolor\n\n[48x48/places]\nSize=48\nType=Fixed\nContext=Places\n\n[scalable/mimetypes]\nSize=128\nType=Scalable\n",
        )
        .unwrap();

        let parsed = parse_index_theme(&index).unwrap();
        assert_eq!(parsed.inherits, vec!["Adwaita", "hicolor"]);
        assert_eq!(parsed.dirs.len(), 2);
        assert_eq!(parsed.dirs[0].rel, "48x48/places");
        assert_eq!(parsed.dirs[0].size, 48);
        assert!(!parsed.dirs[0].scalable);
        assert!(parsed.dirs[1].scalable);

        let _ = fs::remove_dir_all(&directory);
    }

    #[test]
    fn find_icon_prefers_theme_hierarchy_and_inherits_when_missing() {
        let base = std::env::temp_dir().join(format!("defile_icons_test_{}", std::process::id()));
        let root = base.join("icons");
        let roots = vec![root.clone()];

        write_theme(
            &root,
            "Gruvbox-Blue",
            "[Icon Theme]\nName=Gruvbox-Blue\nInherits=Adwaita\n\n[48x48/places]\nSize=48\n\n[16x16/mimetypes]\nSize=16\n\n[scalable/places]\nSize=128\nType=Scalable\n",
        );
        write_theme(
            &root,
            "Adwaita",
            "[Icon Theme]\nName=Adwaita\nInherits=hicolor\n\n[24x24/mimetypes]\nSize=24\n",
        );

        write_png(&root.join("Gruvbox-Blue/48x48/places/folder.png"));
        write_png(&root.join("Gruvbox-Blue/16x16/mimetypes/text-plain.png"));
        write_png(&root.join("Adwaita/24x24/mimetypes/text-plain.png"));
        write_png(&root.join("Adwaita/24x24/mimetypes/audio-x-generic.png"));
        write_svg(&root.join("Gruvbox-Blue/scalable/places/network-workgroup.svg"));

        let folder = find_icon_in_roots(&roots, "Gruvbox-Blue", "folder", 48).unwrap();
        assert!(folder.ends_with("Gruvbox-Blue/48x48/places/folder.png"));

        let local = find_icon_in_roots(&roots, "Gruvbox-Blue", "text-plain", 16).unwrap();
        assert!(local.ends_with("Gruvbox-Blue/16x16/mimetypes/text-plain.png"));

        // If local theme has the icon, local theme must be used even if size differs:
        let local_scaled = find_icon_in_roots(&roots, "Gruvbox-Blue", "text-plain", 24).unwrap();
        assert!(local_scaled.ends_with("Gruvbox-Blue/16x16/mimetypes/text-plain.png"));

        // If local theme does not have the icon, fall back to inherited theme:
        let inherited = find_icon_in_roots(&roots, "Gruvbox-Blue", "audio-x-generic", 24).unwrap();
        assert!(inherited.ends_with("Adwaita/24x24/mimetypes/audio-x-generic.png"));

        let scalable = find_icon_in_roots(&roots, "Gruvbox-Blue", "network-workgroup", 32).unwrap();
        assert!(scalable.ends_with("Gruvbox-Blue/scalable/places/network-workgroup.svg"));

        let missing = find_icon_in_roots(&roots, "Gruvbox-Blue", "unknown-icon", 48);
        assert!(missing.is_none());

        let _ = fs::remove_dir_all(&base);
    }

    #[test]
    fn icon_png_passes_png_and_renders_svg() {
        let base = std::env::temp_dir().join(format!("defile_png_test_{}", std::process::id()));
        let root = base.join("icons");
        let roots = vec![root.clone()];

        write_theme(
            &root,
            "Theme",
            "[Icon Theme]\nName=Theme\n\n[48x48/places]\nSize=48\n\n[scalable/places]\nSize=128\nType=Scalable\n",
        );

        write_png(&root.join("Theme/48x48/places/folder.png"));
        write_svg(&root.join("Theme/scalable/places/network-workgroup.svg"));

        let names = |name: &str| vec![name.to_string()];

        let png = icon_png_in_roots(&roots, "Theme", &names("folder"), 48).unwrap();
        assert!(png.starts_with(&PNG_SIGNATURE));

        let rendered = icon_png_in_roots(&roots, "Theme", &names("network-workgroup"), 32).unwrap();
        assert_eq!(&rendered[..4], &[0x89, b'P', b'N', b'G']);

        let pixmap = resvg::tiny_skia::Pixmap::decode_png(&rendered).unwrap();
        assert_eq!(pixmap.width(), 32);
        assert_eq!(pixmap.height(), 32);

        let _ = fs::remove_dir_all(&base);
    }

    #[test]
    fn icon_png_skips_broken_candidates() {
        let base =
            std::env::temp_dir().join(format!("defile_broken_icon_test_{}", std::process::id()));
        let root = base.join("icons");
        let roots = vec![root.clone()];

        write_theme(
            &root,
            "Rusak",
            "[Icon Theme]\nName=Rusak\n\n[scalable/places]\nSize=128\nType=Scalable\n\n[16x16/places]\nSize=16\n",
        );

        write_broken_symlink_dump(&root.join("Rusak/scalable/places/network-workgroup.svg"));
        write_svg(&root.join("Rusak/16x16/places/network-workgroup.svg"));

        let names = |name: &str| vec![name.to_string()];

        let rendered =
            icon_png_in_roots(&roots, "Rusak", &names("network-workgroup"), 128).unwrap();
        assert!(rendered.starts_with(&[0x89, b'P', b'N', b'G']));

        let pixmap = resvg::tiny_skia::Pixmap::decode_png(&rendered).unwrap();
        assert_eq!(pixmap.width(), 128);

        write_theme(
            &root,
            "PngRusak",
            "[Icon Theme]\nName=PngRusak\n\n[48x48/mimetypes]\nSize=48\n",
        );

        write_broken_symlink_dump(&root.join("PngRusak/48x48/mimetypes/text-plain.png"));

        let fallback = icon_png_in_roots(&roots, "PngRusak", &names("text-plain"), 48);
        assert!(fallback.is_none());

        let _ = fs::remove_dir_all(&base);
    }

    #[test]
    #[ignore]
    fn diag_theme_lookup() {
        let roots = icon_search_roots();
        let names = [
            "folder",
            "inode-directory",
            "text-x-generic",
            "text-plain",
            "application-pdf",
            "image-x-generic",
            "x-office-document",
            "application-zip",
            "text-x-script",
        ];

        for theme in list_icon_themes_in_roots(&roots) {
            for name in names {
                let at_15 = find_icon_candidates_in_roots(&roots, &theme.name, name, 15)
                    .first()
                    .cloned();
                let at_48 = find_icon_candidates_in_roots(&roots, &theme.name, name, 48)
                    .first()
                    .cloned();

                let in_theme = |path: &Option<PathBuf>| {
                    path.as_ref()
                        .map(|p| p.starts_with(&theme.path))
                        .unwrap_or(false)
                };

                if in_theme(&at_15) != in_theme(&at_48) {
                    eprintln!(
                        "{:36} {name:22} 15->{} | 48->{}",
                        theme.name,
                        at_15
                            .map(|p| p.to_string_lossy().into_owned())
                            .unwrap_or_else(|| "<none>".into()),
                        at_48
                            .map(|p| p.to_string_lossy().into_owned())
                            .unwrap_or_else(|| "<none>".into()),
                    );
                }
            }
        }
    }

    #[test]
    #[ignore]
    fn audit_real_themes() {
        let roots = icon_search_roots();
        let names = [
            "folder",
            "inode-directory",
            "text-plain",
            "text-x-generic",
            "image-png",
            "image-x-generic",
            "application-pdf",
            "x-office-document",
            "application-zip",
            "package-x-generic",
            "text-x-script",
            "video-x-generic",
            "audio-x-generic",
            "image-jpeg",
            "application-x-executable",
        ];

        for theme in list_icon_themes_in_roots(&roots) {
            let mut ok = 0;
            let mut missing: Vec<&str> = Vec::new();

            for name in names {
                let result = icon_png_in_roots(&roots, &theme.name, &[name.to_string()], 48);

                if result.is_some() {
                    ok += 1;
                } else {
                    missing.push(name);
                }
            }

            eprintln!(
                "{:48} {:2}/{} missing={:?}",
                theme.name,
                ok,
                names.len(),
                missing
            );
        }
    }

    #[test]
    #[ignore]
    fn audit_real_themes_by_size() {
        let roots = icon_search_roots();
        let sizes = [15u32, 48, 50, 56];
        let names = ["folder", "application-pdf", "application-zip", "text-plain"];

        for theme in list_icon_themes_in_roots(&roots) {
            let mut line = String::new();

            for name in names {
                let mut marks = String::new();

                for size in sizes {
                    let ok =
                        icon_png_in_roots(&roots, &theme.name, &[name.to_string()], size).is_some();
                    marks.push(if ok { 'Y' } else { 'N' });
                }

                line.push_str(&format!(" {name}[{marks}]"));
            }

            eprintln!("{:44}{line}", theme.name);
        }
    }

    #[test]
    fn list_icon_themes_skips_hidden_unusable_and_duplicates() {
        let base = std::env::temp_dir().join(format!("defile_themes_test_{}", std::process::id()));
        let root_a = base.join("a");
        let root_b = base.join("b");

        let index = "[Icon Theme]\nName=Test\n\n[48x48/places]\nSize=48\n";

        write_theme(&root_a, "Breeze", index);
        write_theme(&root_a, "Adwaita", index);
        write_theme(&root_a, ".hidden", index);
        write_theme(&root_b, "Adwaita", index);
        write_theme(&root_a, "Empty", "[Icon Theme]\nName=Empty\n");

        write_png(&root_a.join("Breeze/48x48/places/folder.png"));
        write_png(&root_a.join("Adwaita/48x48/places/folder.png"));
        write_png(&root_a.join(".hidden/48x48/places/folder.png"));
        write_png(&root_b.join("Adwaita/48x48/places/folder.png"));

        fs::create_dir_all(root_a.join("no-index")).unwrap();

        let themes = list_icon_themes_in_roots(&[root_a.clone(), root_b]);
        let names: Vec<&str> = themes.iter().map(|theme| theme.name.as_str()).collect();
        assert_eq!(names, vec!["Adwaita", "Breeze"]);
        assert!(themes[0]
            .path
            .starts_with(root_a.to_string_lossy().as_ref()));

        let _ = fs::remove_dir_all(&base);
    }
}
