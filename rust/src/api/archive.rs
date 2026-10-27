use std::fs;
use std::io::{Read, Seek, Write};
use std::path::{Path, PathBuf};

use zip::write::SimpleFileOptions;
use zip::ZipWriter;

const MAX_ARCHIVE_DEPTH: usize = 64;

/// Bundles the given files and directories into an archive at [destination].
/// The format is derived from the destination extension: zip, tar and
/// tar.gz/tgz. Each item's relative name lands at the archive root and the
/// directory tree below it is preserved.
pub fn compress_entries(
    paths: Vec<String>,
    destination: String,
) -> Result<(), String> {
    if paths.is_empty() {
        return Err("No items selected".to_string());
    }

    let destination_path = PathBuf::from(&destination);

    if let Some(parent) = destination_path.parent() {
        if !parent.as_os_str().is_empty() {
            fs::create_dir_all(parent).map_err(|error| {
                format!("Failed to prepare the destination folder: {error}")
            })?;
        }
    }

    let lower = destination.to_lowercase();

    if lower.ends_with(".tar.gz") || lower.ends_with(".tgz") {
        return write_tar(&paths, &destination_path, true);
    }

    if lower.ends_with(".tar") {
        return write_tar(&paths, &destination_path, false);
    }

    write_zip(&paths, &destination_path)
}

fn write_zip(paths: &[String], destination: &Path) -> Result<(), String> {
    let archive_file = fs::File::create(destination)
        .map_err(|error| format!("Failed to create the archive: {error}"))?;

    let mut writer = ZipWriter::new(archive_file);
    let options = SimpleFileOptions::default();

    for path in paths {
        let source = PathBuf::from(path);

        let source_meta = fs::metadata(&source)
            .map_err(|error| format!("Item not found or not accessible: {error}"))?;

        let root_name = archive_file_name(&source)?;

        add_path(
            &mut writer,
            &source,
            &root_name,
            options,
            source_meta.is_dir(),
            0,
        )?;
    }

    writer
        .finish()
        .map_err(|error| format!("Failed to write the archive: {error}"))?;

    Ok(())
}

fn write_tar(paths: &[String], destination: &Path, gzip: bool) -> Result<(), String> {
    let file = fs::File::create(destination)
        .map_err(|error| format!("Failed to create the archive: {error}"))?;

    if gzip {
        let encoder = flate2::write::GzEncoder::new(file, flate2::Compression::default());
        let mut builder = tar::Builder::new(encoder);
        append_paths(&mut builder, paths)?;
        let encoder = builder
            .into_inner()
            .map_err(|error| format!("Failed to write the archive: {error}"))?;
        encoder
            .finish()
            .map_err(|error| format!("Failed to write the archive: {error}"))?;
        return Ok(());
    }

    let mut builder = tar::Builder::new(file);
    append_paths(&mut builder, paths)?;
    builder
        .finish()
        .map_err(|error| format!("Failed to write the archive: {error}"))?;

    Ok(())
}

fn append_paths(builder: &mut tar::Builder<impl Write>, paths: &[String]) -> Result<(), String> {
    for path in paths {
        let source = PathBuf::from(path);

        let source_meta = fs::metadata(&source)
            .map_err(|error| format!("Item not found or not accessible: {error}"))?;

        let root_name = archive_file_name(&source)?;

        if source_meta.is_dir() {
            builder
                .append_dir_all(&root_name, &source)
                .map_err(|error| format!("Failed to add {root_name}: {error}"))?;
        } else {
            let mut file = fs::File::open(&source)
                .map_err(|error| format!("Failed to add {root_name}: {error}"))?;
            builder
                .append_file(&root_name, &mut file)
                .map_err(|error| format!("Failed to add {root_name}: {error}"))?;
        }
    }

    Ok(())
}

/// Extracts an archive (zip, tar, tar.gz, tgz) into [destination_dir],
/// creating the folder when needed. Returns the entry count.
pub fn extract_archive(path: String, destination_dir: String) -> Result<u64, String> {
    let destination = PathBuf::from(&destination_dir);
    let lower = path.to_lowercase();
    let is_tgz = lower.ends_with(".tar.gz") || lower.ends_with(".tgz");

    let step = |error: String| format!("Failed to extract the archive: {error}");

    fs::create_dir_all(&destination)
        .map_err(|error| format!("Failed to create the destination folder: {error}"))?;

    if is_tgz || lower.ends_with(".tar") {
        let file = fs::File::open(&path).map_err(|e| step(e.to_string()))?;

        let stream: Box<dyn Read> = if is_tgz {
            Box::new(flate2::read::GzDecoder::new(file))
        } else {
            Box::new(file)
        };
        let mut archive = tar::Archive::new(stream);
        let mut items: u64 = 0;

        for entry in archive
            .entries()
            .map_err(|error| step(error.to_string()))?
        {
            let mut entry = entry.map_err(|error| step(error.to_string()))?;
            entry
                .unpack_in(&destination)
                .map_err(|error| step(error.to_string()))?;
            items += 1;
        }

        return Ok(items);
    }

    if lower.ends_with(".zip") {
        let file = fs::File::open(&path).map_err(|e| step(e.to_string()))?;
        let mut archive =
            zip::ZipArchive::new(file).map_err(|error| step(error.to_string()))?;

        archive
            .extract(&destination)
            .map_err(|error| step(error.to_string()))?;

        return Ok(archive.len() as u64);
    }

    Err("Unsupported archive format. Zip, tar and tar.gz are supported.".to_string())
}

fn archive_file_name(source: &Path) -> Result<String, String> {
    let name = source
        .file_name()
        .map(|name| name.to_string_lossy().to_string())
        .ok_or_else(|| format!("Invalid item name: {}", source.display()))?;

    Ok(name)
}

/// Recursively writes [source] into the archive at the relative [name],
/// depth-limited so symlink loops cannot run away.
fn add_path<W: Write + Seek>(
    writer: &mut ZipWriter<W>,
    source: &Path,
    name: &str,
    options: SimpleFileOptions,
    is_dir: bool,
    depth: usize,
) -> Result<(), String> {
    if depth > MAX_ARCHIVE_DEPTH {
        return Err("Directory tree is too deep (possible symlink loop?)".to_string());
    }

    if is_dir {
        writer
            .add_directory(format!("{name}/"), options)
            .map_err(|error| format!("Failed to add {name}: {error}"))?;

        let children = fs::read_dir(source)
            .map_err(|error| format!("Failed to read {name}: {error}"))?;

        for child in children {
            let child = child.map_err(|error| format!("Failed to read {name}: {error}"))?;
            let child_path = child.path();
            let child_meta = fs::symlink_metadata(&child_path)
                .map_err(|error| format!("Failed to read {name}: {error}"))?;
            let child_name = child.file_name().to_string_lossy().to_string();
            let child_rel = format!("{name}/{child_name}");

            add_path(
                writer,
                &child_path,
                &child_rel,
                options,
                child_meta.is_dir(),
                depth + 1,
            )?;
        }

        return Ok(());
    }

    writer
        .start_file(name.to_string(), options)
        .map_err(|error| format!("Failed to add {name}: {error}"))?;

    let mut file =
        fs::File::open(source).map_err(|error| format!("Failed to add {name}: {error}"))?;

    std::io::copy(&mut file, writer)
        .map_err(|error| format!("Failed to add {name}: {error}"))?;

    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    fn workspace(tag: &str) -> PathBuf {
        std::env::temp_dir().join(format!(
            "defile_archive_test_{tag}_{}",
            std::process::id()
        ))
    }

    #[test]
    fn zip_roundtrip_preserves_tree() {
        let dir = workspace("zip");
        fs::create_dir_all(dir.join("src/sub")).unwrap();
        fs::write(dir.join("src/a.txt"), "hello").unwrap();
        fs::write(dir.join("src/sub/b.txt"), "world").unwrap();

        let archive = dir.join("out.zip");
        compress_entries(
            vec![dir.join("src").display().to_string()],
            archive.display().to_string(),
        )
        .unwrap();

        let extracted = dir.join("extracted");
        let items = extract_archive(archive.display().to_string(), extracted.display().to_string());
        assert!(items.is_ok());

        assert!(extracted.join("src/a.txt").is_file());
        assert!(extracted.join("src/sub/b.txt").is_file());
        assert_eq!(
            fs::read_to_string(extracted.join("src/sub/b.txt")).unwrap(),
            "world"
        );

        fs::remove_dir_all(&dir).ok();
    }

    #[test]
    fn tar_gz_roundtrip() {
        let dir = workspace("targz");
        fs::create_dir_all(dir.join("src/sub")).unwrap();
        fs::write(dir.join("src/a.txt"), "hello").unwrap();

        let archive = dir.join("out.tar.gz");
        compress_entries(
            vec![dir.join("src").display().to_string()],
            archive.display().to_string(),
        )
        .unwrap();

        let extracted = dir.join("textracted");
        let items =
            extract_archive(archive.display().to_string(), extracted.display().to_string());
        let items = items.unwrap_or_else(|error| panic!("extract failed: {error}"));
        assert!(items >= 1);
        assert_eq!(
            fs::read_to_string(extracted.join("src/a.txt")).unwrap(),
            "hello"
        );

        fs::remove_dir_all(&dir).ok();
    }

    #[test]
    fn tar_roundtrip() {
        let dir = workspace("tar");
        fs::create_dir_all(dir.join("src/sub")).unwrap();
        fs::write(dir.join("src/a.txt"), "hello").unwrap();

        let archive = dir.join("out.tar");
        compress_entries(
            vec![dir.join("src").display().to_string()],
            archive.display().to_string(),
        )
        .unwrap();

        let extracted = dir.join("textracted");
        let items =
            extract_archive(archive.display().to_string(), extracted.display().to_string());
        let items = items.unwrap_or_else(|error| panic!("extract failed: {error}"));
        assert!(items >= 1);
        assert!(extracted.join("src/sub").is_dir());
        assert_eq!(
            fs::read_to_string(extracted.join("src/a.txt")).unwrap(),
            "hello"
        );

        fs::remove_dir_all(&dir).ok();
    }

    #[test]
    fn rejects_unsupported_format() {
        let dir = workspace("reject");
        fs::create_dir_all(&dir).unwrap();
        let fake = dir.join("nope.7z");
        fs::write(&fake, b"junk").unwrap();

        let result = extract_archive(fake.display().to_string(), dir.join("out").display().to_string());
        assert!(result.is_err());

        fs::remove_dir_all(&dir).ok();
    }
}
