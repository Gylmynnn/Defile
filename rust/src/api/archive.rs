use std::fs;
use std::io::{BufReader, Read, Seek, Write};
use std::path::{Component, Path, PathBuf};
use std::process::{Command, Stdio};
use std::time::{Duration, Instant};

use zip::result::ZipError;
use zip::write::SimpleFileOptions;
use zip::ZipWriter;

const MAX_ARCHIVE_DEPTH: usize = 64;
const LZMA_MEM_LIMIT_KB: u32 = 1024 * 1024;
const PROGRESS_EMIT_INTERVAL: Duration = Duration::from_millis(60);

#[derive(Debug, Clone)]
pub struct ArchiveProgress {
    pub percent: u8,
    pub processed_bytes: u64,
    pub total_bytes: u64,
    pub items_completed: u64,
    pub finished: bool,
}

struct ProgressTracker<'a> {
    total_bytes: u64,
    processed_bytes: u64,
    items_completed: u64,
    total_items: u64,
    last_percent: Option<u8>,
    last_emit: Instant,
    on_progress: &'a mut dyn FnMut(ArchiveProgress),
}

impl<'a> ProgressTracker<'a> {
    fn new(
        total_bytes: u64,
        total_items: u64,
        on_progress: &'a mut dyn FnMut(ArchiveProgress),
    ) -> Self {
        Self {
            total_bytes,
            processed_bytes: 0,
            items_completed: 0,
            total_items,
            last_percent: None,
            last_emit: Instant::now() - PROGRESS_EMIT_INTERVAL,
            on_progress,
        }
    }

    fn compute_percent(&self) -> u8 {
        if self.total_bytes > 0 {
            let pct = (self.processed_bytes as u128 * 100) / (self.total_bytes as u128);
            pct.min(100) as u8
        } else if self.total_items > 0 {
            let pct = (self.items_completed as u128 * 100) / (self.total_items as u128);
            pct.min(100) as u8
        } else {
            0
        }
    }

    fn emit(&mut self, force: bool, finished: bool) {
        let percent = if finished { 100 } else { self.compute_percent() };
        let changed = self.last_percent != Some(percent);
        if !force && !finished && !changed && self.last_emit.elapsed() < PROGRESS_EMIT_INTERVAL {
            return;
        }
        self.last_percent = Some(percent);
        self.last_emit = Instant::now();
        (self.on_progress)(ArchiveProgress {
            percent,
            processed_bytes: self.processed_bytes,
            total_bytes: self.total_bytes,
            items_completed: self.items_completed,
            finished,
        });
    }

    fn emit_percent(&mut self, percent: u8) {
        let clamped = percent.min(100);
        if self.last_percent == Some(clamped) && self.last_emit.elapsed() < PROGRESS_EMIT_INTERVAL {
            return;
        }
        self.last_percent = Some(clamped);
        self.last_emit = Instant::now();
        (self.on_progress)(ArchiveProgress {
            percent: clamped,
            processed_bytes: self.processed_bytes,
            total_bytes: self.total_bytes,
            items_completed: self.items_completed,
            finished: false,
        });
    }

    fn add_bytes(&mut self, delta: u64) {
        if delta == 0 {
            return;
        }
        self.processed_bytes = self.processed_bytes.saturating_add(delta);
        self.emit(false, false);
    }

    fn complete_item(&mut self) {
        self.items_completed = self.items_completed.saturating_add(1);
        self.emit(false, false);
    }
}

struct ProgressRead<'a, 'b, R> {
    inner: R,
    tracker: &'a mut ProgressTracker<'b>,
}

impl<'a, 'b, R: Read> ProgressRead<'a, 'b, R> {
    fn new(inner: R, tracker: &'a mut ProgressTracker<'b>) -> Self {
        Self { inner, tracker }
    }
}

impl<R: Read> Read for ProgressRead<'_, '_, R> {
    fn read(&mut self, buf: &mut [u8]) -> std::io::Result<usize> {
        let n = self.inner.read(buf)?;
        self.tracker.add_bytes(n as u64);
        Ok(n)
    }
}

/// Bundles the given files and directories into an archive at [destination].
/// The format is derived from the destination extension: zip, tar and
/// tar.gz/tgz. Each item's relative name lands at the archive root and the
/// directory tree below it is preserved.
pub fn compress_entries(
    paths: Vec<String>,
    destination: String,
) -> Result<(), String> {
    let mut noop = |_| {};
    compress_entries_impl(&paths, &destination, &mut noop)
}

/// Streams progress percentage updates while compressing [paths] into
/// [destination]. Emits a final event with `finished = true` on completion.
pub fn compress_entries_stream(
    paths: Vec<String>,
    destination: String,
    sink: crate::frb_generated::StreamSink<ArchiveProgress>,
) -> Result<(), String> {
    let mut emit = |progress: ArchiveProgress| {
        let _ = sink.add(progress);
    };
    compress_entries_impl(&paths, &destination, &mut emit)
}

fn measure_input_totals(paths: &[String]) -> Result<(u64, u64), String> {
    fn walk(path: &Path, depth: usize, bytes: &mut u64, items: &mut u64) -> Result<(), String> {
        if depth > MAX_ARCHIVE_DEPTH {
            return Err("Directory tree is too deep (possible symlink loop?)".to_string());
        }
        let meta = fs::symlink_metadata(path)
            .map_err(|error| format!("Item not found or not accessible: {error}"))?;
        *items += 1;
        if meta.is_dir() {
            let children = fs::read_dir(path)
                .map_err(|error| format!("Failed to read {}: {error}", path.display()))?;
            for child in children {
                let child = child
                    .map_err(|error| format!("Failed to read {}: {error}", path.display()))?;
                walk(&child.path(), depth + 1, bytes, items)?;
            }
        } else {
            *bytes = bytes.saturating_add(meta.len());
        }
        Ok(())
    }

    let mut total_bytes = 0u64;
    let mut total_items = 0u64;
    for raw in paths {
        walk(Path::new(raw), 0, &mut total_bytes, &mut total_items)?;
    }
    Ok((total_bytes, total_items))
}

fn compress_entries_impl(
    paths: &[String],
    destination: &str,
    on_progress: &mut dyn FnMut(ArchiveProgress),
) -> Result<(), String> {
    if paths.is_empty() {
        return Err("No items selected".to_string());
    }

    let destination_path = PathBuf::from(destination);

    if let Some(parent) = destination_path.parent() {
        if !parent.as_os_str().is_empty() {
            fs::create_dir_all(parent).map_err(|error| {
                format!("Failed to prepare the destination folder: {error}")
            })?;
        }
    }

    let (total_bytes, total_items) = measure_input_totals(paths)?;
    let mut tracker = ProgressTracker::new(total_bytes, total_items, on_progress);
    tracker.emit(true, false);

    let lower = destination.to_lowercase();

    if lower.ends_with(".tar.gz") || lower.ends_with(".tgz") {
        write_tar(paths, &destination_path, true, &mut tracker)?;
    } else if lower.ends_with(".tar") {
        write_tar(paths, &destination_path, false, &mut tracker)?;
    } else {
        write_zip(paths, &destination_path, &mut tracker)?;
    }

    tracker.emit(true, true);
    Ok(())
}

fn write_zip(
    paths: &[String],
    destination: &Path,
    tracker: &mut ProgressTracker<'_>,
) -> Result<(), String> {
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
            tracker,
        )?;
    }

    writer
        .finish()
        .map_err(|error| format!("Failed to write the archive: {error}"))?;

    Ok(())
}

fn write_tar(
    paths: &[String],
    destination: &Path,
    gzip: bool,
    tracker: &mut ProgressTracker<'_>,
) -> Result<(), String> {
    let file = fs::File::create(destination)
        .map_err(|error| format!("Failed to create the archive: {error}"))?;

    if gzip {
        let encoder = flate2::write::GzEncoder::new(file, flate2::Compression::default());
        let mut builder = tar::Builder::new(encoder);
        append_paths(&mut builder, paths, tracker)?;
        let encoder = builder
            .into_inner()
            .map_err(|error| format!("Failed to write the archive: {error}"))?;
        encoder
            .finish()
            .map_err(|error| format!("Failed to write the archive: {error}"))?;
        return Ok(());
    }

    let mut builder = tar::Builder::new(file);
    append_paths(&mut builder, paths, tracker)?;
    builder
        .finish()
        .map_err(|error| format!("Failed to write the archive: {error}"))?;

    Ok(())
}

fn append_paths(
    builder: &mut tar::Builder<impl Write>,
    paths: &[String],
    tracker: &mut ProgressTracker<'_>,
) -> Result<(), String> {
    for path in paths {
        let source = PathBuf::from(path);

        let source_meta = fs::symlink_metadata(&source)
            .map_err(|error| format!("Item not found or not accessible: {error}"))?;

        let root_name = archive_file_name(&source)?;
        append_tar_tree(builder, &source, &root_name, source_meta.is_dir(), 0, tracker)?;
    }

    Ok(())
}

fn append_tar_tree(
    builder: &mut tar::Builder<impl Write>,
    source: &Path,
    archive_name: &str,
    is_dir: bool,
    depth: usize,
    tracker: &mut ProgressTracker<'_>,
) -> Result<(), String> {
    if depth > MAX_ARCHIVE_DEPTH {
        return Err("Directory tree is too deep (possible symlink loop?)".to_string());
    }

    if is_dir {
        builder
            .append_dir(archive_name, source)
            .map_err(|error| format!("Failed to add {archive_name}: {error}"))?;
        tracker.complete_item();

        let children = fs::read_dir(source)
            .map_err(|error| format!("Failed to read {archive_name}: {error}"))?;
        for child in children {
            let child = child.map_err(|error| format!("Failed to read {archive_name}: {error}"))?;
            let child_path = child.path();
            let child_meta = fs::symlink_metadata(&child_path)
                .map_err(|error| format!("Failed to read {archive_name}: {error}"))?;
            let child_name = child.file_name().to_string_lossy().to_string();
            let child_rel = format!("{archive_name}/{child_name}");
            append_tar_tree(
                builder,
                &child_path,
                &child_rel,
                child_meta.is_dir(),
                depth + 1,
                tracker,
            )?;
        }
        return Ok(());
    }

    let meta = fs::metadata(source)
        .map_err(|error| format!("Failed to add {archive_name}: {error}"))?;
    let file =
        fs::File::open(source).map_err(|error| format!("Failed to add {archive_name}: {error}"))?;
    let mut header = tar::Header::new_gnu();
    header.set_metadata(&meta);
    let mut reader = ProgressRead::new(file, tracker);
    builder
        .append_data(&mut header, archive_name, &mut reader)
        .map_err(|error| format!("Failed to add {archive_name}: {error}"))?;
    tracker.complete_item();
    Ok(())
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
enum StreamKind {
    Plain,
    Gz,
    Bz2,
    Xz,
    Lzma,
    Lzip,
    Zst,
    Lz4,
    Brotli,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
enum ArchiveFormat {
    Zip,
    SevenZ,
    Tar(StreamKind),
    SingleFile(StreamKind, &'static str),
    Ar,
    Rar,
    Rpm,
    Cpio,
    TarZ,
    CompressZ(&'static str),
    SystemContainer(&'static str),
}

const EXTENSION_FORMATS: &[(&str, ArchiveFormat)] = &[
    // Compound tar suffixes must precede single-extension suffixes.
    (".tar.gz", ArchiveFormat::Tar(StreamKind::Gz)),
    (".tar.bz2", ArchiveFormat::Tar(StreamKind::Bz2)),
    (".tar.xz", ArchiveFormat::Tar(StreamKind::Xz)),
    (".tar.zst", ArchiveFormat::Tar(StreamKind::Zst)),
    (".tar.lzma", ArchiveFormat::Tar(StreamKind::Lzma)),
    (".tar.lz", ArchiveFormat::Tar(StreamKind::Lzip)),
    (".tar.lz4", ArchiveFormat::Tar(StreamKind::Lz4)),
    (".tar.br", ArchiveFormat::Tar(StreamKind::Brotli)),
    (".tar.z", ArchiveFormat::TarZ),
    // Short tar aliases.
    (".tgz", ArchiveFormat::Tar(StreamKind::Gz)),
    (".tbz2", ArchiveFormat::Tar(StreamKind::Bz2)),
    (".tbz", ArchiveFormat::Tar(StreamKind::Bz2)),
    (".tz2", ArchiveFormat::Tar(StreamKind::Bz2)),
    (".txz", ArchiveFormat::Tar(StreamKind::Xz)),
    (".tzst", ArchiveFormat::Tar(StreamKind::Zst)),
    (".tlz", ArchiveFormat::Tar(StreamKind::Lzma)),
    (".taz", ArchiveFormat::TarZ),
    (".cbt", ArchiveFormat::Tar(StreamKind::Plain)),
    (".tar", ArchiveFormat::Tar(StreamKind::Plain)),
    // Zip family.
    (".zip", ArchiveFormat::Zip),
    (".cbz", ArchiveFormat::Zip),
    (".jar", ArchiveFormat::Zip),
    (".apk", ArchiveFormat::Zip),
    (".war", ArchiveFormat::Zip),
    (".ear", ArchiveFormat::Zip),
    (".whl", ArchiveFormat::Zip),
    (".xpi", ArchiveFormat::Zip),
    // 7z family.
    (".7z", ArchiveFormat::SevenZ),
    (".cb7", ArchiveFormat::SevenZ),
    // Rar family.
    (".rar", ArchiveFormat::Rar),
    (".cbr", ArchiveFormat::Rar),
    // Single-file compressed streams.
    (".gz", ArchiveFormat::SingleFile(StreamKind::Gz, ".gz")),
    (".bz2", ArchiveFormat::SingleFile(StreamKind::Bz2, ".bz2")),
    (".xz", ArchiveFormat::SingleFile(StreamKind::Xz, ".xz")),
    (".zst", ArchiveFormat::SingleFile(StreamKind::Zst, ".zst")),
    (".lzma", ArchiveFormat::SingleFile(StreamKind::Lzma, ".lzma")),
    (".lz", ArchiveFormat::SingleFile(StreamKind::Lzip, ".lz")),
    (".lz4", ArchiveFormat::SingleFile(StreamKind::Lz4, ".lz4")),
    (".br", ArchiveFormat::SingleFile(StreamKind::Brotli, ".br")),
    (".z", ArchiveFormat::CompressZ(".z")),
    // Unix ar / Debian packages / RPM / CPIO.
    (".deb", ArchiveFormat::Ar),
    (".ar", ArchiveFormat::Ar),
    (".a", ArchiveFormat::Ar),
    (".rpm", ArchiveFormat::Rpm),
    (".cpio", ArchiveFormat::Cpio),
    // System-extracted containers and disk images.
    (".iso", ArchiveFormat::SystemContainer(".iso")),
    (".udf", ArchiveFormat::SystemContainer(".udf")),
    (".cab", ArchiveFormat::SystemContainer(".cab")),
    (".lzh", ArchiveFormat::SystemContainer(".lzh")),
    (".lha", ArchiveFormat::SystemContainer(".lha")),
    (".arj", ArchiveFormat::SystemContainer(".arj")),
    (".wim", ArchiveFormat::SystemContainer(".wim")),
    (".swm", ArchiveFormat::SystemContainer(".swm")),
    (".esd", ArchiveFormat::SystemContainer(".esd")),
    (".xar", ArchiveFormat::SystemContainer(".xar")),
    (".pkg", ArchiveFormat::SystemContainer(".pkg")),
    (".dmg", ArchiveFormat::SystemContainer(".dmg")),
    (".msi", ArchiveFormat::SystemContainer(".msi")),
    (".squashfs", ArchiveFormat::SystemContainer(".squashfs")),
    (".ace", ArchiveFormat::SystemContainer(".ace")),
    (".alz", ArchiveFormat::SystemContainer(".alz")),
];

fn detect_format_by_extension(path: &str) -> Option<ArchiveFormat> {
    let lower = path.to_lowercase();
    EXTENSION_FORMATS
        .iter()
        .find(|(suffix, _)| lower.ends_with(suffix))
        .map(|(_, format)| *format)
}

fn has_ustar_header(mut reader: impl Read) -> bool {
    let mut buf = [0u8; 265];
    let mut read_total = 0;
    while read_total < buf.len() {
        match reader.read(&mut buf[read_total..]) {
            Ok(0) => break,
            Ok(n) => read_total += n,
            Err(_) => return false,
        }
    }
    read_total >= 262 && &buf[257..262] == b"ustar"
}

fn detect_compressed_tar_or_single(path: &Path, kind: StreamKind) -> ArchiveFormat {
    if let Ok(file) = fs::File::open(path) {
        if let Ok(stream) = wrap_compressed_reader(BufReader::new(file), kind) {
            if has_ustar_header(stream) {
                return ArchiveFormat::Tar(kind);
            }
        }
    }
    ArchiveFormat::SingleFile(kind, "")
}

fn detect_format_by_magic(path: &Path) -> Option<ArchiveFormat> {
    let mut file = fs::File::open(path).ok()?;
    let mut head = [0u8; 512];
    let n = file.read(&mut head).ok()?;
    let slice = &head[..n];

    if slice.starts_with(&[0x37, 0x7A, 0xBC, 0xAF, 0x27, 0x1C]) {
        return Some(ArchiveFormat::SevenZ);
    }
    if slice.starts_with(b"PK\x03\x04") || slice.starts_with(b"PK\x05\x06") {
        return Some(ArchiveFormat::Zip);
    }
    if slice.starts_with(b"Rar!\x1A\x07") {
        return Some(ArchiveFormat::Rar);
    }
    if slice.starts_with(&[0x1F, 0x8B]) {
        return Some(detect_compressed_tar_or_single(path, StreamKind::Gz));
    }
    if slice.starts_with(b"BZh") {
        return Some(detect_compressed_tar_or_single(path, StreamKind::Bz2));
    }
    if slice.starts_with(&[0xFD, 0x37, 0x7A, 0x58, 0x5A, 0x00]) {
        return Some(detect_compressed_tar_or_single(path, StreamKind::Xz));
    }
    if slice.starts_with(&[0x28, 0xB5, 0x2F, 0xFD]) {
        return Some(detect_compressed_tar_or_single(path, StreamKind::Zst));
    }
    if slice.starts_with(b"LZIP") {
        return Some(detect_compressed_tar_or_single(path, StreamKind::Lzip));
    }
    if slice.starts_with(&[0x04, 0x22, 0x4D, 0x18]) {
        return Some(detect_compressed_tar_or_single(path, StreamKind::Lz4));
    }
    if slice.starts_with(b"!<arch>\n") {
        return Some(ArchiveFormat::Ar);
    }
    if slice.starts_with(&[0xED, 0xAB, 0xEE, 0xDB]) {
        return Some(ArchiveFormat::Rpm);
    }
    if slice.starts_with(b"MSCF") {
        return Some(ArchiveFormat::SystemContainer(".cab"));
    }
    if slice.starts_with(b"xar!") {
        return Some(ArchiveFormat::SystemContainer(".xar"));
    }
    if slice.starts_with(b"MSWIM\0\0\0") {
        return Some(ArchiveFormat::SystemContainer(".wim"));
    }
    if slice.starts_with(b"070701") || slice.starts_with(b"070702") || slice.starts_with(b"070707") {
        return Some(ArchiveFormat::Cpio);
    }
    if slice.starts_with(&[0x1F, 0x9D]) || slice.starts_with(&[0x1F, 0xA0]) {
        return Some(ArchiveFormat::CompressZ(""));
    }
    if n >= 262 && &slice[257..262] == b"ustar" {
        return Some(ArchiveFormat::Tar(StreamKind::Plain));
    }

    if file.seek(std::io::SeekFrom::Start(0x8001)).is_ok() {
        let mut iso_sig = [0u8; 5];
        if file.read_exact(&mut iso_sig).is_ok() && &iso_sig == b"CD001" {
            return Some(ArchiveFormat::SystemContainer(".iso"));
        }
    }

    None
}

/// Extracts an archive into [destination_dir], creating the folder when needed.
/// Supports zip/cbz/jar/apk, 7z/cb7, tar (plain and gz/bz2/xz/zst/lzma/lz/lz4/br),
/// single-file compressed streams, ar/deb, and common system archive formats
/// (rar/cbr, rpm, cpio, iso, cab, lzh/lha, arj, wim, xar, dmg, msi, etc.) when
/// the corresponding system tools are available. Returns the extracted entry count.
pub fn extract_archive(path: String, destination_dir: String) -> Result<u64, String> {
    let mut noop = |_| {};
    extract_archive_impl(&path, &destination_dir, &mut noop)
}

/// Streams progress percentage updates while extracting [path] into
/// [destination_dir]. Emits a final event with `finished = true` carrying
/// `items_completed` on completion.
pub fn extract_archive_stream(
    path: String,
    destination_dir: String,
    sink: crate::frb_generated::StreamSink<ArchiveProgress>,
) -> Result<(), String> {
    let mut emit = |progress: ArchiveProgress| {
        let _ = sink.add(progress);
    };
    extract_archive_impl(&path, &destination_dir, &mut emit)?;
    Ok(())
}

fn extract_archive_impl(
    path: &str,
    destination_dir: &str,
    on_progress: &mut dyn FnMut(ArchiveProgress),
) -> Result<u64, String> {
    let source = PathBuf::from(path);
    if !source.is_file() {
        return Err(format!("Archive file not found: {path}"));
    }

    let format = detect_format_by_extension(path)
        .or_else(|| detect_format_by_magic(&source))
        .ok_or_else(|| format!("Unsupported archive format: {}", source.display()))?;

    let destination = PathBuf::from(destination_dir);
    let destination_existed = destination.exists();
    fs::create_dir_all(&destination)
        .map_err(|error| format!("Failed to create the destination folder: {error}"))?;

    let result = extract_with_format(&source, &destination, format, on_progress);

    if result.is_err() && !destination_existed {
        let _ = fs::remove_dir(&destination);
    }

    result
}

fn extract_with_format(
    source: &Path,
    destination: &Path,
    format: ArchiveFormat,
    on_progress: &mut dyn FnMut(ArchiveProgress),
) -> Result<u64, String> {
    let archive_size = fs::metadata(source).map(|m| m.len()).unwrap_or(0);
    on_progress(ArchiveProgress {
        percent: 0,
        processed_bytes: 0,
        total_bytes: archive_size,
        items_completed: 0,
        finished: false,
    });

    let items = match format {
        ArchiveFormat::Tar(kind) => {
            let mut tracker = ProgressTracker::new(archive_size, 0, on_progress);
            extract_tar(source, destination, kind, &mut tracker)?
        }
        ArchiveFormat::SingleFile(kind, suffix) => {
            let mut tracker = ProgressTracker::new(archive_size, 0, on_progress);
            extract_single_compressed(source, destination, kind, suffix, &mut tracker)?
        }
        ArchiveFormat::Zip => extract_zip(source, destination, on_progress)?,
        ArchiveFormat::SevenZ => extract_7z(source, destination, on_progress)?,
        ArchiveFormat::Ar => {
            let mut tracker = ProgressTracker::new(archive_size, 0, on_progress);
            extract_ar(source, destination, &mut tracker)?
        }
        ArchiveFormat::Rar => {
            let mut tracker = ProgressTracker::new(archive_size, 0, on_progress);
            extract_with_tool_chain(source, destination, ".rar", RAR_TOOLS, &mut tracker)?
        }
        ArchiveFormat::Rpm => {
            let mut tracker = ProgressTracker::new(archive_size, 0, on_progress);
            extract_with_tool_chain(source, destination, ".rpm", RPM_TOOLS, &mut tracker)?
        }
        ArchiveFormat::Cpio => {
            let mut tracker = ProgressTracker::new(archive_size, 0, on_progress);
            extract_with_tool_chain(source, destination, ".cpio", CPIO_TOOLS, &mut tracker)?
        }
        ArchiveFormat::TarZ => {
            let mut tracker = ProgressTracker::new(archive_size, 0, on_progress);
            extract_with_tool_chain(source, destination, ".tar.Z", TAR_Z_TOOLS, &mut tracker)?
        }
        ArchiveFormat::CompressZ(suffix) => {
            let mut tracker = ProgressTracker::new(archive_size, 0, on_progress);
            extract_compress_z(source, destination, suffix, &mut tracker)?
        }
        ArchiveFormat::SystemContainer(ext) => {
            let mut tracker = ProgressTracker::new(archive_size, 0, on_progress);
            extract_with_tool_chain(
                source,
                destination,
                ext,
                GENERIC_CONTAINER_TOOLS,
                &mut tracker,
            )?
        }
    };

    on_progress(ArchiveProgress {
        percent: 100,
        processed_bytes: archive_size,
        total_bytes: archive_size,
        items_completed: items,
        finished: true,
    });
    Ok(items)
}

fn step_err(error: impl std::fmt::Display) -> String {
    format!("Failed to extract the archive: {error}")
}

fn wrap_compressed_reader<'a, R: Read + 'a>(
    reader: R,
    kind: StreamKind,
) -> Result<Box<dyn Read + 'a>, String> {
    let stream: Box<dyn Read + 'a> = match kind {
        StreamKind::Plain => Box::new(reader),
        StreamKind::Gz => Box::new(flate2::read::GzDecoder::new(reader)),
        StreamKind::Bz2 => Box::new(bzip2::read::MultiBzDecoder::new(reader)),
        StreamKind::Xz => Box::new(lzma_rust2::XzReader::new(reader, true)),
        StreamKind::Lzma => Box::new(
            lzma_rust2::LzmaReader::new_mem_limit(reader, LZMA_MEM_LIMIT_KB, None)
                .map_err(step_err)?,
        ),
        StreamKind::Lzip => Box::new(lzma_rust2::LzipReader::new(reader)),
        StreamKind::Zst => Box::new(zstd::stream::Decoder::new(reader).map_err(step_err)?),
        StreamKind::Lz4 => Box::new(lz4_flex::frame::FrameDecoder::new(reader)),
        StreamKind::Brotli => Box::new(brotli::Decompressor::new(reader, 4096)),
    };
    Ok(stream)
}

fn extract_tar(
    source: &Path,
    destination: &Path,
    kind: StreamKind,
    tracker: &mut ProgressTracker<'_>,
) -> Result<u64, String> {
    let file = fs::File::open(source).map_err(step_err)?;
    let counting = ProgressRead::new(BufReader::new(file), tracker);
    let stream = wrap_compressed_reader(counting, kind)?;
    let mut archive = tar::Archive::new(stream);
    let mut items: u64 = 0;

    let entries = match archive.entries() {
        Ok(entries) => entries,
        Err(error) => {
            drop(archive);
            if kind == StreamKind::Lzma {
                if let Ok(count) = extract_with_tool_chain(
                    source,
                    destination,
                    ".tar.lzma",
                    GENERIC_CONTAINER_TOOLS,
                    tracker,
                ) {
                    return Ok(count);
                }
            }
            return Err(step_err(error));
        }
    };

    for entry in entries {
        let mut entry = entry.map_err(step_err)?;
        entry.unpack_in(destination).map_err(step_err)?;
        items += 1;
    }

    Ok(items)
}

fn derive_single_output_name(source: &Path, suffix: &str) -> String {
    let raw_name = source
        .file_name()
        .map(|name| name.to_string_lossy().to_string())
        .unwrap_or_default();

    let stripped = if !suffix.is_empty() && raw_name.to_lowercase().ends_with(suffix) {
        &raw_name[..raw_name.len() - suffix.len()]
    } else {
        raw_name.as_str()
    };

    let clean = Path::new(stripped)
        .file_name()
        .map(|name| name.to_string_lossy().to_string())
        .unwrap_or_default();

    if clean.is_empty() || clean == "." || clean == ".." {
        "extracted".to_string()
    } else {
        clean
    }
}

fn extract_single_compressed(
    source: &Path,
    destination: &Path,
    kind: StreamKind,
    suffix: &str,
    tracker: &mut ProgressTracker<'_>,
) -> Result<u64, String> {
    let file = fs::File::open(source).map_err(step_err)?;
    let counting = ProgressRead::new(BufReader::new(file), tracker);
    let mut stream = wrap_compressed_reader(counting, kind)?;
    let out_name = derive_single_output_name(source, suffix);
    let out_path = destination.join(out_name);
    let mut out_file = fs::File::create(&out_path).map_err(step_err)?;

    if let Err(error) = std::io::copy(&mut stream, &mut out_file) {
        let _ = fs::remove_file(&out_path);
        return Err(step_err(error));
    }

    Ok(1)
}

fn extract_zip(
    source: &Path,
    destination: &Path,
    on_progress: &mut dyn FnMut(ArchiveProgress),
) -> Result<u64, String> {
    let file = fs::File::open(source).map_err(step_err)?;
    let mut fallback_tracker = ProgressTracker::new(0, 0, on_progress);
    let mut archive = match zip::ZipArchive::new(file) {
        Ok(archive) => archive,
        Err(ZipError::UnsupportedArchive(msg)) => {
            if let Ok(count) = extract_with_tool_chain(
                source,
                destination,
                ".zip",
                ZIP_FALLBACK_TOOLS,
                &mut fallback_tracker,
            ) {
                return Ok(count);
            }
            return Err(step_err(msg));
        }
        Err(error) => return Err(step_err(error)),
    };

    let total_items = archive.len() as u64;
    let total_bytes = archive
        .decompressed_size()
        .unwrap_or(0)
        .min(u64::MAX as u128) as u64;
    let mut tracker = ProgressTracker::new(total_bytes, total_items, on_progress);
    tracker.emit(true, false);

    // Delegate symlink-containing zips directly to ZipArchive::extract for full
    // symlink validation, otherwise stream entry-by-entry for real-time %.
    let mut has_symlink = false;
    for i in 0..archive.len() {
        if let Ok(entry) = archive.by_index(i) {
            if entry.is_symlink() {
                has_symlink = true;
                break;
            }
        }
    }

    if has_symlink {
        match archive.extract(destination) {
            Ok(()) => return Ok(total_items),
            Err(ZipError::UnsupportedArchive(msg)) => {
                if msg.to_lowercase().contains("password") {
                    return Err("Failed to extract the archive: archive is password-protected".to_string());
                }
                if let Ok(count) = extract_with_tool_chain(
                    source,
                    destination,
                    ".zip",
                    ZIP_FALLBACK_TOOLS,
                    &mut tracker,
                ) {
                    return Ok(count);
                }
                return Err(step_err(msg));
            }
            Err(error) => return Err(step_err(error)),
        }
    }

    #[cfg(unix)]
    let mut dir_modes: Vec<(PathBuf, u32)> = Vec::new();
    let mut unsupported_fallback_msg: Option<String> = None;

    for i in 0..archive.len() {
        let entry = match archive.by_index(i) {
            Ok(entry) => entry,
            Err(ZipError::UnsupportedArchive(msg)) => {
                if msg.to_lowercase().contains("password") {
                    return Err("Failed to extract the archive: archive is password-protected".to_string());
                }
                unsupported_fallback_msg = Some(msg.to_string());
                break;
            }
            Err(error) => return Err(step_err(error)),
        };

        let Some(rel_path) = entry.enclosed_name() else {
            return Err(format!(
                "Failed to extract the archive: unsafe path '{}'",
                entry.name()
            ));
        };
        let out_path = destination.join(rel_path);

        if entry.is_dir() {
            fs::create_dir_all(&out_path).map_err(step_err)?;
            #[cfg(unix)]
            if let Some(mode) = entry.unix_mode() {
                dir_modes.push((out_path, mode));
            }
            tracker.complete_item();
            continue;
        }

        if let Some(parent) = out_path.parent() {
            fs::create_dir_all(parent).map_err(step_err)?;
        }

        #[cfg(unix)]
        let file_mode = entry.unix_mode();

        let mut outfile = fs::File::create(&out_path).map_err(step_err)?;
        let mut reader = ProgressRead::new(entry, &mut tracker);
        std::io::copy(&mut reader, &mut outfile).map_err(step_err)?;
        drop(reader);

        #[cfg(unix)]
        if let Some(mode) = file_mode {
            use std::os::unix::fs::PermissionsExt;
            let _ = fs::set_permissions(&out_path, fs::Permissions::from_mode(mode & 0o777));
        }

        tracker.complete_item();
    }

    if let Some(msg) = unsupported_fallback_msg {
        drop(archive);
        if let Ok(count) = extract_with_tool_chain(
            source,
            destination,
            ".zip",
            ZIP_FALLBACK_TOOLS,
            &mut tracker,
        ) {
            return Ok(count);
        }
        return Err(step_err(msg));
    }

    #[cfg(unix)]
    {
        use std::os::unix::fs::PermissionsExt;
        for (dir_path, mode) in dir_modes.into_iter().rev() {
            let _ = fs::set_permissions(dir_path, fs::Permissions::from_mode(mode & 0o777));
        }
    }

    Ok(total_items)
}

fn extract_7z(
    source: &Path,
    destination: &Path,
    on_progress: &mut dyn FnMut(ArchiveProgress),
) -> Result<u64, String> {
    let file = fs::File::open(source).map_err(step_err)?;
    let mut reader = match sevenz_rust2::ArchiveReader::new(file, sevenz_rust2::Password::empty()) {
        Ok(reader) => reader,
        Err(sevenz_rust2::Error::PasswordRequired)
        | Err(sevenz_rust2::Error::MaybeBadPassword(_)) => {
            return Err("Failed to extract the archive: archive is password-protected".to_string());
        }
        Err(sevenz_rust2::Error::Unsupported(_))
        | Err(sevenz_rust2::Error::UnsupportedCompressionMethod(_)) => {
            let mut tracker = ProgressTracker::new(0, 0, on_progress);
            return extract_with_tool_chain(
                source,
                destination,
                ".7z",
                SEVENZ_FALLBACK_TOOLS,
                &mut tracker,
            );
        }
        Err(error) => return Err(step_err(format!("{error:?}"))),
    };

    let total_items = reader.archive().files.len() as u64;
    let total_bytes: u64 = reader.archive().files.iter().map(|f| f.size).sum();
    let mut tracker = ProgressTracker::new(total_bytes, total_items, on_progress);
    tracker.emit(true, false);

    let mut items: u64 = 0;
    let extract_result = reader.for_each_entries(|entry, entry_reader| {
        let dest_path = safe_join(destination, entry.name())
            .map_err(std::io::Error::other)?;
        let mut tracked = ProgressRead::new(entry_reader, &mut tracker);
        let keep = sevenz_rust2::default_entry_extract_fn(entry, &mut tracked, &dest_path)?;
        if keep {
            items += 1;
            tracker.complete_item();
        }
        Ok(keep)
    });

    match extract_result {
        Ok(()) => Ok(items),
        Err(sevenz_rust2::Error::PasswordRequired)
        | Err(sevenz_rust2::Error::MaybeBadPassword(_)) => {
            Err("Failed to extract the archive: archive is password-protected".to_string())
        }
        Err(sevenz_rust2::Error::Unsupported(_))
        | Err(sevenz_rust2::Error::UnsupportedCompressionMethod(_)) => extract_with_tool_chain(
            source,
            destination,
            ".7z",
            SEVENZ_FALLBACK_TOOLS,
            &mut tracker,
        ),
        Err(error) => Err(step_err(format!("{error:?}"))),
    }
}

fn extract_ar(
    source: &Path,
    destination: &Path,
    tracker: &mut ProgressTracker<'_>,
) -> Result<u64, String> {
    let mut items: u64 = 0;
    let mut parse_error: Option<String> = None;

    {
        let file = fs::File::open(source).map_err(step_err)?;
        let counting = ProgressRead::new(file, tracker);
        let mut archive = ar::Archive::new(counting);

        while let Some(entry_result) = archive.next_entry() {
            let mut entry = match entry_result {
                Ok(entry) => entry,
                Err(error) => {
                    parse_error = Some(error.to_string());
                    break;
                }
            };

            let raw_name = String::from_utf8_lossy(entry.header().identifier()).to_string();
            let trimmed = raw_name.trim_end_matches('/');
            if trimmed.is_empty() || trimmed == "__.SYMDEF" || trimmed == "__.SYMDEF SORTED" {
                continue;
            }

            let target = safe_join(destination, trimmed)?;
            if let Some(parent) = target.parent() {
                fs::create_dir_all(parent).map_err(step_err)?;
            }

            let mut out = fs::File::create(&target).map_err(step_err)?;
            std::io::copy(&mut entry, &mut out).map_err(step_err)?;
            items += 1;
        }
    }

    if let Some(error) = parse_error {
        if items == 0 {
            if let Ok(count) = extract_with_tool_chain(
                source,
                destination,
                ".ar",
                GENERIC_CONTAINER_TOOLS,
                tracker,
            ) {
                return Ok(count);
            }
        }
        return Err(step_err(error));
    }

    if items == 0 {
        return Err(step_err("archive contains no extractable entries"));
    }

    Ok(items)
}

fn extract_compress_z(
    source: &Path,
    destination: &Path,
    suffix: &str,
    tracker: &mut ProgressTracker<'_>,
) -> Result<u64, String> {
    let out_name = derive_single_output_name(source, suffix);
    let out_path = destination.join(out_name);
    if let Ok(output) = Command::new("gzip")
        .arg("-dc")
        .arg("--")
        .arg(source)
        .stdin(Stdio::null())
        .output()
    {
        if output.status.success() {
            fs::write(&out_path, &output.stdout).map_err(step_err)?;
            return Ok(1);
        }
    }

    extract_with_tool_chain(source, destination, ".Z", GENERIC_CONTAINER_TOOLS, tracker)
}

#[derive(Debug, Clone, Copy)]
enum SystemTool {
    SevenZip(&'static str),
    Bsdtar,
    Unrar,
    Unar,
    Unzip,
    Tar,
    Cpio,
    Rpm2Cpio,
}

const RAR_TOOLS: &[SystemTool] = &[
    SystemTool::Unrar,
    SystemTool::Unar,
    SystemTool::SevenZip("7z"),
    SystemTool::SevenZip("7zz"),
    SystemTool::SevenZip("7za"),
    SystemTool::Bsdtar,
];

const RPM_TOOLS: &[SystemTool] = &[
    SystemTool::Bsdtar,
    SystemTool::Rpm2Cpio,
    SystemTool::SevenZip("7z"),
    SystemTool::SevenZip("7zz"),
    SystemTool::Unar,
];

const CPIO_TOOLS: &[SystemTool] = &[
    SystemTool::Bsdtar,
    SystemTool::Cpio,
    SystemTool::SevenZip("7z"),
    SystemTool::SevenZip("7zz"),
];

const TAR_Z_TOOLS: &[SystemTool] = &[
    SystemTool::Bsdtar,
    SystemTool::Tar,
    SystemTool::SevenZip("7z"),
    SystemTool::SevenZip("7zz"),
];

const ZIP_FALLBACK_TOOLS: &[SystemTool] = &[
    SystemTool::SevenZip("7z"),
    SystemTool::SevenZip("7zz"),
    SystemTool::Unzip,
    SystemTool::Bsdtar,
    SystemTool::Unar,
];

const SEVENZ_FALLBACK_TOOLS: &[SystemTool] = &[
    SystemTool::SevenZip("7z"),
    SystemTool::SevenZip("7zz"),
    SystemTool::SevenZip("7za"),
    SystemTool::Bsdtar,
    SystemTool::Unar,
];

const GENERIC_CONTAINER_TOOLS: &[SystemTool] = &[
    SystemTool::SevenZip("7z"),
    SystemTool::SevenZip("7zz"),
    SystemTool::SevenZip("7za"),
    SystemTool::Bsdtar,
    SystemTool::Unar,
];

enum ToolOutcome {
    Success,
    NotFound,
    Failed(String),
}

fn tool_display_name(tool: SystemTool) -> &'static str {
    match tool {
        SystemTool::SevenZip(bin) => bin,
        SystemTool::Bsdtar => "bsdtar",
        SystemTool::Unrar => "unrar",
        SystemTool::Unar => "unar",
        SystemTool::Unzip => "unzip",
        SystemTool::Tar => "tar",
        SystemTool::Cpio => "cpio",
        SystemTool::Rpm2Cpio => "rpm2cpio/cpio",
    }
}

fn extract_with_tool_chain(
    source: &Path,
    destination: &Path,
    ext: &str,
    tools: &[SystemTool],
    tracker: &mut ProgressTracker<'_>,
) -> Result<u64, String> {
    let mut last_failure: Option<String> = None;
    let mut missing_names: Vec<&'static str> = Vec::new();

    for &tool in tools {
        match run_system_tool(tool, source, destination, tracker) {
            ToolOutcome::Success => {
                return count_extracted_entries(destination);
            }
            ToolOutcome::NotFound => {
                missing_names.push(tool_display_name(tool));
            }
            ToolOutcome::Failed(message) => {
                last_failure = Some(message);
            }
        }
    }

    if let Some(error) = last_failure {
        return Err(step_err(error));
    }

    Err(format!(
        "Cannot extract {ext} archive: install one of ({}) on your system.",
        missing_names.join(", ")
    ))
}

fn parse_latest_percent(chunk: &str) -> Option<u8> {
    let mut latest: Option<u8> = None;
    for part in chunk.split('%') {
        let digits: String = part
            .chars()
            .rev()
            .take_while(|c| c.is_ascii_digit())
            .collect::<String>()
            .chars()
            .rev()
            .collect();
        if !digits.is_empty() {
            if let Ok(val) = digits.parse::<u16>() {
                if val <= 100 {
                    latest = Some(val as u8);
                }
            }
        }
    }
    latest
}

fn run_command_with_percent_stdout(
    command: &mut Command,
    tracker: &mut ProgressTracker<'_>,
) -> ToolOutcome {
    command.stdout(Stdio::piped()).stderr(Stdio::piped());
    let mut child = match command.spawn() {
        Ok(child) => child,
        Err(error) if error.kind() == std::io::ErrorKind::NotFound => return ToolOutcome::NotFound,
        Err(error) => return ToolOutcome::Failed(error.to_string()),
    };

    let mut stdout_text = String::new();
    if let Some(mut stdout) = child.stdout.take() {
        let mut buf = [0u8; 512];
        loop {
            match stdout.read(&mut buf) {
                Ok(0) => break,
                Ok(n) => {
                    let text = String::from_utf8_lossy(&buf[..n]);
                    if let Some(pct) = parse_latest_percent(&text) {
                        tracker.emit_percent(pct);
                    }
                    if stdout_text.len() < 4096 {
                        stdout_text.push_str(&text);
                    }
                }
                Err(_) => break,
            }
        }
    }

    match child.wait_with_output() {
        Ok(output) if output.status.success() => ToolOutcome::Success,
        Ok(output) => {
            ToolOutcome::Failed(format_process_error(&output.stderr, stdout_text.as_bytes()))
        }
        Err(error) => ToolOutcome::Failed(error.to_string()),
    }
}

fn run_system_tool(
    tool: SystemTool,
    source: &Path,
    destination: &Path,
    tracker: &mut ProgressTracker<'_>,
) -> ToolOutcome {
    match tool {
        SystemTool::SevenZip(bin) => {
            let out_flag = format!("-o{}", destination.display());
            run_command_with_percent_stdout(
                Command::new(bin)
                    .args(["x", "-y", "-bsp1", "-bso0", "-p-", &out_flag, "--"])
                    .arg(source)
                    .stdin(Stdio::null()),
                tracker,
            )
        }
        SystemTool::Bsdtar => run_simple_command(
            Command::new("bsdtar")
                .arg("-xf")
                .arg(source)
                .arg("-C")
                .arg(destination)
                .stdin(Stdio::null()),
        ),
        SystemTool::Unrar => {
            let dest_arg = format!("{}/", destination.display());
            run_command_with_percent_stdout(
                Command::new("unrar")
                    .args(["x", "-o+", "-y", "-p-", "--"])
                    .arg(source)
                    .arg(dest_arg)
                    .stdin(Stdio::null()),
                tracker,
            )
        }
        SystemTool::Unar => run_simple_command(
            Command::new("unar")
                .args(["-f", "-q", "-p", "", "-o"])
                .arg(destination)
                .arg("--")
                .arg(source)
                .stdin(Stdio::null()),
        ),
        SystemTool::Unzip => run_simple_command(
            Command::new("unzip")
                .args(["-o", "-q", "-P", ""])
                .arg(source)
                .arg("-d")
                .arg(destination)
                .stdin(Stdio::null()),
        ),
        SystemTool::Tar => run_simple_command(
            Command::new("tar")
                .arg("-xf")
                .arg(source)
                .arg("-C")
                .arg(destination)
                .stdin(Stdio::null()),
        ),
        SystemTool::Cpio => {
            let file = match fs::File::open(source) {
                Ok(file) => file,
                Err(error) => return ToolOutcome::Failed(error.to_string()),
            };
            run_simple_command(
                Command::new("cpio")
                    .args(["-idm", "--no-absolute-filenames", "--quiet"])
                    .current_dir(destination)
                    .stdin(Stdio::from(file)),
            )
        }
        SystemTool::Rpm2Cpio => run_rpm2cpio_pipeline(source, destination),
    }
}

fn run_simple_command(command: &mut Command) -> ToolOutcome {
    match command.output() {
        Ok(output) if output.status.success() => ToolOutcome::Success,
        Ok(output) => ToolOutcome::Failed(format_process_error(&output.stderr, &output.stdout)),
        Err(error) if error.kind() == std::io::ErrorKind::NotFound => ToolOutcome::NotFound,
        Err(error) => ToolOutcome::Failed(error.to_string()),
    }
}

fn run_rpm2cpio_pipeline(source: &Path, destination: &Path) -> ToolOutcome {
    let mut rpm2cpio = match Command::new("rpm2cpio")
        .arg(source)
        .stdin(Stdio::null())
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .spawn()
    {
        Ok(child) => child,
        Err(error) if error.kind() == std::io::ErrorKind::NotFound => return ToolOutcome::NotFound,
        Err(error) => return ToolOutcome::Failed(error.to_string()),
    };

    let Some(rpm_stdout) = rpm2cpio.stdout.take() else {
        let _ = rpm2cpio.kill();
        let _ = rpm2cpio.wait();
        return ToolOutcome::Failed("Failed to pipe rpm2cpio output".to_string());
    };

    let cpio_out = Command::new("cpio")
        .args(["-idm", "--no-absolute-filenames", "--quiet"])
        .current_dir(destination)
        .stdin(Stdio::from(rpm_stdout))
        .output();

    let rpm_out = rpm2cpio.wait_with_output();

    match (rpm_out, cpio_out) {
        (Ok(r), Ok(c)) if r.status.success() && c.status.success() => ToolOutcome::Success,
        (_, Err(error)) if error.kind() == std::io::ErrorKind::NotFound => ToolOutcome::NotFound,
        (Ok(r), Ok(c)) => {
            let msg = if !c.status.success() {
                format_process_error(&c.stderr, &c.stdout)
            } else {
                format_process_error(&r.stderr, &r.stdout)
            };
            ToolOutcome::Failed(msg)
        }
        (Err(error), _) | (_, Err(error)) => ToolOutcome::Failed(error.to_string()),
    }
}

fn format_process_error(stderr: &[u8], stdout: &[u8]) -> String {
    let stderr_str = String::from_utf8_lossy(stderr).trim().to_string();
    if !stderr_str.is_empty() {
        return stderr_str;
    }
    let stdout_str = String::from_utf8_lossy(stdout).trim().to_string();
    if !stdout_str.is_empty() {
        return stdout_str;
    }
    "extractor exited with a non-zero status".to_string()
}

fn count_extracted_entries(destination: &Path) -> Result<u64, String> {
    let mut count: u64 = 0;
    let mut stack = vec![destination.to_path_buf()];

    while let Some(dir) = stack.pop() {
        let entries = fs::read_dir(&dir).map_err(step_err)?;
        for entry in entries {
            let entry = entry.map_err(step_err)?;
            count += 1;
            let meta = fs::symlink_metadata(entry.path()).map_err(step_err)?;
            if meta.is_dir() {
                stack.push(entry.path());
            }
        }
    }

    Ok(count)
}

fn safe_join(destination: &Path, entry_name: &str) -> Result<PathBuf, String> {
    let normalized = entry_name.replace('\\', "/");
    let mut result = destination.to_path_buf();
    let mut has_component = false;

    for component in Path::new(&normalized).components() {
        match component {
            Component::Normal(part) => {
                result.push(part);
                has_component = true;
            }
            Component::CurDir => {}
            Component::ParentDir | Component::RootDir | Component::Prefix(_) => {
                return Err(format!(
                    "Failed to extract the archive: unsafe path '{entry_name}'"
                ));
            }
        }
    }

    if !has_component {
        return Err("Failed to extract the archive: empty entry path".to_string());
    }

    Ok(result)
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
    tracker: &mut ProgressTracker<'_>,
) -> Result<(), String> {
    if depth > MAX_ARCHIVE_DEPTH {
        return Err("Directory tree is too deep (possible symlink loop?)".to_string());
    }

    if is_dir {
        writer
            .add_directory(format!("{name}/"), options)
            .map_err(|error| format!("Failed to add {name}: {error}"))?;
        tracker.complete_item();

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
                tracker,
            )?;
        }

        return Ok(());
    }

    writer
        .start_file(name.to_string(), options)
        .map_err(|error| format!("Failed to add {name}: {error}"))?;

    let file =
        fs::File::open(source).map_err(|error| format!("Failed to add {name}: {error}"))?;
    let mut reader = ProgressRead::new(file, tracker);

    std::io::copy(&mut reader, writer)
        .map_err(|error| format!("Failed to add {name}: {error}"))?;
    tracker.complete_item();

    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    fn workspace(tag: &str) -> PathBuf {
        let dir = std::env::temp_dir().join(format!(
            "defile_archive_test_{tag}_{}",
            std::process::id()
        ));
        let _ = fs::remove_dir_all(&dir);
        dir
    }

    fn build_tar_bytes(files: &[(&str, &[u8])]) -> Vec<u8> {
        let mut buf = Vec::new();
        {
            let mut builder = tar::Builder::new(&mut buf);
            for (name, data) in files {
                let mut header = tar::Header::new_gnu();
                header.set_size(data.len() as u64);
                header.set_mode(0o644);
                header.set_cksum();
                builder.append_data(&mut header, *name, *data).unwrap();
            }
            builder.finish().unwrap();
        }
        buf
    }

    #[test]
    fn zip_roundtrip_preserves_tree_and_reports_progress() {
        let dir = workspace("zip");
        fs::create_dir_all(dir.join("src/sub")).unwrap();
        fs::write(dir.join("src/a.txt"), "hello").unwrap();
        fs::write(dir.join("src/sub/b.txt"), "world").unwrap();

        let archive = dir.join("out.zip");
        let mut compress_events = Vec::new();
        compress_entries_impl(
            &[dir.join("src").display().to_string()],
            &archive.display().to_string(),
            &mut |p| compress_events.push(p),
        )
        .unwrap();
        assert_eq!(compress_events.first().map(|p| p.percent), Some(0));
        assert!(compress_events.last().is_some_and(|p| p.finished && p.percent == 100));

        let extracted = dir.join("extracted");
        let mut extract_events = Vec::new();
        let items = extract_archive_impl(
            &archive.display().to_string(),
            &extracted.display().to_string(),
            &mut |p| extract_events.push(p),
        )
        .unwrap();
        assert!(items >= 2);
        assert_eq!(extract_events.first().map(|p| p.percent), Some(0));
        assert!(extract_events.last().is_some_and(|p| p.finished && p.percent == 100));

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
    fn seven_z_roundtrip_preserves_tree_and_reports_progress() {
        let dir = workspace("7z");
        fs::create_dir_all(dir.join("src/sub")).unwrap();
        fs::write(dir.join("src/a.txt"), "hello 7z").unwrap();
        fs::write(dir.join("src/sub/b.txt"), "nested 7z").unwrap();

        let archive = dir.join("out.7z");
        sevenz_rust2::compress_to_path(dir.join("src"), &archive).unwrap();

        let extracted = dir.join("extracted");
        let mut events = Vec::new();
        let items = extract_archive_impl(
            &archive.display().to_string(),
            &extracted.display().to_string(),
            &mut |p| events.push(p),
        )
        .unwrap_or_else(|error| panic!("7z extract failed: {error}"));
        assert!(items >= 2);
        assert_eq!(events.first().map(|p| p.percent), Some(0));
        assert!(events.last().is_some_and(|p| p.finished && p.percent == 100));
        assert_eq!(
            fs::read_to_string(extracted.join("a.txt")).unwrap(),
            "hello 7z"
        );
        assert_eq!(
            fs::read_to_string(extracted.join("sub/b.txt")).unwrap(),
            "nested 7z"
        );

        fs::remove_dir_all(&dir).ok();
    }

    #[test]
    fn compressed_tar_variants_extract() {
        let dir = workspace("tar_variants");
        fs::create_dir_all(&dir).unwrap();
        let tar_bytes = build_tar_bytes(&[("nested/note.txt", b"hello tar variants")]);

        // .tar.bz2
        let tbz_path = dir.join("bundle.tar.bz2");
        {
            let mut enc = bzip2::write::BzEncoder::new(
                fs::File::create(&tbz_path).unwrap(),
                bzip2::Compression::default(),
            );
            enc.write_all(&tar_bytes).unwrap();
            enc.finish().unwrap();
        }
        let out_bz2 = dir.join("out_bz2");
        assert_eq!(
            extract_archive(tbz_path.display().to_string(), out_bz2.display().to_string()).unwrap(),
            1
        );
        assert_eq!(
            fs::read_to_string(out_bz2.join("nested/note.txt")).unwrap(),
            "hello tar variants"
        );

        // .tar.xz
        let txz_path = dir.join("bundle.tar.xz");
        {
            let mut enc = lzma_rust2::XzWriter::new(
                fs::File::create(&txz_path).unwrap(),
                lzma_rust2::XzOptions::default(),
            )
            .unwrap();
            enc.write_all(&tar_bytes).unwrap();
            enc.finish().unwrap();
        }
        let out_xz = dir.join("out_xz");
        assert_eq!(
            extract_archive(txz_path.display().to_string(), out_xz.display().to_string()).unwrap(),
            1
        );
        assert_eq!(
            fs::read_to_string(out_xz.join("nested/note.txt")).unwrap(),
            "hello tar variants"
        );

        // .tar.zst
        let tzst_path = dir.join("bundle.tar.zst");
        {
            let mut enc = zstd::stream::Encoder::new(fs::File::create(&tzst_path).unwrap(), 0).unwrap();
            enc.write_all(&tar_bytes).unwrap();
            enc.finish().unwrap();
        }
        let out_zst = dir.join("out_zst");
        assert_eq!(
            extract_archive(tzst_path.display().to_string(), out_zst.display().to_string()).unwrap(),
            1
        );
        assert_eq!(
            fs::read_to_string(out_zst.join("nested/note.txt")).unwrap(),
            "hello tar variants"
        );

        // .tar.lz4
        let tlz4_path = dir.join("bundle.tar.lz4");
        {
            let mut enc = lz4_flex::frame::FrameEncoder::new(fs::File::create(&tlz4_path).unwrap());
            enc.write_all(&tar_bytes).unwrap();
            enc.finish().unwrap();
        }
        let out_lz4 = dir.join("out_lz4");
        assert_eq!(
            extract_archive(tlz4_path.display().to_string(), out_lz4.display().to_string()).unwrap(),
            1
        );
        assert_eq!(
            fs::read_to_string(out_lz4.join("nested/note.txt")).unwrap(),
            "hello tar variants"
        );

        // .tar.lzma / .tlz
        let tlzma_path = dir.join("bundle.tlz");
        {
            let mut enc = lzma_rust2::LzmaWriter::new_use_header(
                fs::File::create(&tlzma_path).unwrap(),
                &lzma_rust2::LzmaOptions::default(),
                Some(tar_bytes.len() as u64),
            )
            .unwrap();
            enc.write_all(&tar_bytes).unwrap();
            enc.finish().unwrap();
        }
        let out_lzma = dir.join("out_lzma");
        assert_eq!(
            extract_archive(tlzma_path.display().to_string(), out_lzma.display().to_string()).unwrap(),
            1
        );
        assert_eq!(
            fs::read_to_string(out_lzma.join("nested/note.txt")).unwrap(),
            "hello tar variants"
        );

        // .tar.lz (lzip)
        let tlzip_path = dir.join("bundle.tar.lz");
        {
            let mut enc = lzma_rust2::LzipWriter::new(
                fs::File::create(&tlzip_path).unwrap(),
                lzma_rust2::LzipOptions::default(),
            );
            enc.write_all(&tar_bytes).unwrap();
            enc.finish().unwrap();
        }
        let out_lzip = dir.join("out_lzip");
        assert_eq!(
            extract_archive(tlzip_path.display().to_string(), out_lzip.display().to_string()).unwrap(),
            1
        );
        assert_eq!(
            fs::read_to_string(out_lzip.join("nested/note.txt")).unwrap(),
            "hello tar variants"
        );

        // .tar.br
        let tbr_path = dir.join("bundle.tar.br");
        {
            let mut enc = brotli::CompressorWriter::new(
                fs::File::create(&tbr_path).unwrap(),
                4096,
                5,
                22,
            );
            enc.write_all(&tar_bytes).unwrap();
        }
        let out_br = dir.join("out_br");
        assert_eq!(
            extract_archive(tbr_path.display().to_string(), out_br.display().to_string()).unwrap(),
            1
        );
        assert_eq!(
            fs::read_to_string(out_br.join("nested/note.txt")).unwrap(),
            "hello tar variants"
        );

        fs::remove_dir_all(&dir).ok();
    }

    #[test]
    fn single_file_streams_extract() {
        let dir = workspace("single_streams");
        fs::create_dir_all(&dir).unwrap();

        let gz_path = dir.join("hello.txt.gz");
        {
            let mut enc = flate2::write::GzEncoder::new(
                fs::File::create(&gz_path).unwrap(),
                flate2::Compression::default(),
            );
            enc.write_all(b"single gz").unwrap();
            enc.finish().unwrap();
        }
        let out_gz = dir.join("out_gz");
        assert_eq!(
            extract_archive(gz_path.display().to_string(), out_gz.display().to_string()).unwrap(),
            1
        );
        assert_eq!(fs::read_to_string(out_gz.join("hello.txt")).unwrap(), "single gz");

        let zst_path = dir.join("data.bin.zst");
        {
            let mut enc = zstd::stream::Encoder::new(fs::File::create(&zst_path).unwrap(), 0).unwrap();
            enc.write_all(b"single zst").unwrap();
            enc.finish().unwrap();
        }
        let out_zst = dir.join("out_zst");
        assert_eq!(
            extract_archive(zst_path.display().to_string(), out_zst.display().to_string()).unwrap(),
            1
        );
        assert_eq!(fs::read_to_string(out_zst.join("data.bin")).unwrap(), "single zst");

        let xz_path = dir.join("note.md.xz");
        {
            let mut enc = lzma_rust2::XzWriter::new(
                fs::File::create(&xz_path).unwrap(),
                lzma_rust2::XzOptions::default(),
            )
            .unwrap();
            enc.write_all(b"single xz").unwrap();
            enc.finish().unwrap();
        }
        let out_xz = dir.join("out_xz");
        assert_eq!(
            extract_archive(xz_path.display().to_string(), out_xz.display().to_string()).unwrap(),
            1
        );
        assert_eq!(fs::read_to_string(out_xz.join("note.md")).unwrap(), "single xz");

        fs::remove_dir_all(&dir).ok();
    }

    #[test]
    fn ar_and_deb_extract_and_reject_traversal() {
        let dir = workspace("ar");
        fs::create_dir_all(&dir).unwrap();

        let deb_path = dir.join("pkg.deb");
        {
            let mut builder = ar::Builder::new(fs::File::create(&deb_path).unwrap());
            let payload = b"2.0\n";
            let header = ar::Header::new(b"debian-binary".to_vec(), payload.len() as u64);
            builder.append(&header, &payload[..]).unwrap();
        }
        let out_deb = dir.join("out_deb");
        assert_eq!(
            extract_archive(deb_path.display().to_string(), out_deb.display().to_string()).unwrap(),
            1
        );
        assert_eq!(
            fs::read_to_string(out_deb.join("debian-binary")).unwrap(),
            "2.0\n"
        );

        let unsafe_ar = dir.join("evil.ar");
        {
            let mut builder = ar::Builder::new(fs::File::create(&unsafe_ar).unwrap());
            let payload = b"bad";
            let header = ar::Header::new(b"../escape.txt".to_vec(), payload.len() as u64);
            builder.append(&header, &payload[..]).unwrap();
        }
        let out_evil = dir.join("out_evil");
        let res = extract_archive(unsafe_ar.display().to_string(), out_evil.display().to_string());
        assert!(res.is_err());
        assert!(!dir.join("escape.txt").exists());

        fs::remove_dir_all(&dir).ok();
    }

    #[test]
    fn encrypted_7z_returns_clear_error_without_blocking() {
        let dir = workspace("enc_7z");
        fs::create_dir_all(&dir).unwrap();
        fs::write(dir.join("secret.txt"), "top secret").unwrap();

        let archive = dir.join("secret.7z");
        sevenz_rust2::compress_to_path_encrypted(
            dir.join("secret.txt"),
            &archive,
            sevenz_rust2::Password::from("hunter2"),
        )
        .unwrap();

        let out = dir.join("out");
        let err = extract_archive(archive.display().to_string(), out.display().to_string())
            .unwrap_err();
        assert!(err.to_lowercase().contains("password"), "unexpected error: {err}");
        assert!(!out.exists());

        fs::remove_dir_all(&dir).ok();
    }

    #[test]
    fn magic_bytes_detect_extensionless_archive() {
        let dir = workspace("magic");
        fs::create_dir_all(&dir).unwrap();
        fs::write(dir.join("payload.txt"), "magic ok").unwrap();

        let archive = dir.join("mystery_blob");
        sevenz_rust2::compress_to_path(dir.join("payload.txt"), &archive).unwrap();

        let out = dir.join("extracted");
        let items = extract_archive(archive.display().to_string(), out.display().to_string()).unwrap();
        assert_eq!(items, 1);
        assert_eq!(fs::read_to_string(out.join("payload.txt")).unwrap(), "magic ok");

        fs::remove_dir_all(&dir).ok();
    }

    #[test]
    fn parses_cli_percent_output() {
        assert_eq!(parse_latest_percent("  0%"), Some(0));
        assert_eq!(parse_latest_percent("\r 42% 12\r 87%"), Some(87));
        assert_eq!(parse_latest_percent("100%"), Some(100));
        assert_eq!(parse_latest_percent("no percent"), None);
    }

    #[test]
    fn rejects_unsupported_format() {
        let dir = workspace("reject");
        fs::create_dir_all(&dir).unwrap();
        let fake = dir.join("nope.unknown");
        fs::write(&fake, b"junk").unwrap();

        let result = extract_archive(fake.display().to_string(), dir.join("out").display().to_string());
        assert!(result.is_err());

        fs::remove_dir_all(&dir).ok();
    }
}
