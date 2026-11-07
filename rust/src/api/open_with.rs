use std::{
    env, fs,
    path::{Path, PathBuf},
};

use crate::api::paths::home_dir;
use crate::api::system::OpenWithApp;

pub(crate) fn list_open_with_apps(path: std::string::String) -> Vec<OpenWithApp> {
    let mime = detect_mime_type(&path);
    let text_like = is_text_like(mime.as_deref(), &path);
    let mut apps: Vec<(bool, OpenWithApp)> = Vec::new();
    let mut seen: std::collections::HashSet<std::string::String> = std::collections::HashSet::new();

    for dir in desktop_entry_dirs() {
        let Ok(entries) = fs::read_dir(&dir) else {
            continue;
        };

        for entry in entries.flatten() {
            let desktop_file = entry.path();
            if desktop_file.extension().and_then(|value| value.to_str()) != Some("desktop") {
                continue;
            }

            let Ok(content) = fs::read_to_string(&desktop_file) else {
                continue;
            };

            let Some(entry) = parse_desktop_entry(&content) else {
                continue;
            };

            if entry.hidden || entry.app_type != "Application" {
                continue;
            }

            let mime_supported = mime.as_ref().is_none_or(|mime| {
                entry
                    .mime_types
                    .iter()
                    .any(|candidate| mime_matches(candidate, mime))
            });

            // Code/text files frequently have no precise MIME association in
            // the editor's desktop file (Zed only declares text/plain, Neovim
            // does not declare text/html, ...), so text editors and IDEs are
            // offered for any plain-text file even without a MIME match.
            if !mime_supported && !(text_like && entry.is_editor()) {
                continue;
            }

            if !seen.insert(entry.name.clone()) {
                continue;
            }

            apps.push((
                mime_supported,
                OpenWithApp {
                    id: desktop_file.to_string_lossy().into_owned(),
                    name: entry.name,
                    exec: entry.exec,
                    comment: entry.comment,
                    icon: entry.icon,
                },
            ));
        }
    }

    // Apps that explicitly declare the MIME type come first; editor fallbacks
    // follow, each group alphabetically.
    apps.sort_by(|a, b| {
        b.0.cmp(&a.0).then_with(|| {
            a.1.name
                .to_lowercase()
                .cmp(&b.1.name.to_lowercase())
        })
    });
    apps.into_iter().map(|(_, app)| app).collect()
}

pub(crate) fn open_with(
    path: std::string::String,
    desktop_file: std::string::String,
) -> Result<(), std::string::String> {
    if !Path::new(&path).exists() {
        return Err(format!("File not found: {path}"));
    }

    let content = fs::read_to_string(&desktop_file)
        .map_err(|error| format!("Failed to read {desktop_file}: {error}"))?;

    let Some(entry) = parse_desktop_entry(&content) else {
        return gio_launch(&path, &desktop_file);
    };

    // Terminal applications (Neovim, Vim, ...) cannot be spawned directly:
    // `gio launch` refuses them without `xdg-terminal-exec`. Run them inside
    // the terminal configured in Settings instead.
    if entry.terminal {
        #[cfg(all(unix, not(target_os = "macos")))]
        {
            return launch_in_terminal(&path, &desktop_file, &entry);
        }

        #[cfg(not(all(unix, not(target_os = "macos"))))]
        {
            return Err(
                "Terminal applications are not supported on this platform".to_string(),
            );
        }
    }

    gio_launch(&path, &desktop_file)
}

fn gio_launch(path: &str, desktop_file: &str) -> Result<(), std::string::String> {
    let status = std::process::Command::new("gio")
        .args(["launch", desktop_file, path])
        .status()
        .map_err(|error| format!("Failed to run gio: {error}"))?;

    if status.success() {
        Ok(())
    } else {
        Err(format!("Failed to open with {desktop_file}"))
    }
}

#[cfg(all(unix, not(target_os = "macos")))]
fn launch_in_terminal(
    file_path: &str,
    desktop_file: &str,
    entry: &DesktopEntryInfo,
) -> Result<(), std::string::String> {
    use crate::api::terminal;
    let (terminal_program, argv) = terminal_launch_argv(file_path, desktop_file, entry)?;
    let command_line = argv
        .iter()
        .map(|arg| terminal::shell_quote(arg))
        .collect::<Vec<_>>()
        .join(" ");

    std::process::Command::new("sh")
        .args(["-c", &format!("setsid {command_line} >/dev/null 2>&1 &")])
        .status()
        .map_err(|error| format!("Failed to launch {terminal_program}: {error}"))?;

    Ok(())
}

/// Builds the terminal emulator argv for a `Terminal=true` desktop entry.
#[cfg(all(unix, not(target_os = "macos")))]
fn terminal_launch_argv(
    file_path: &str,
    desktop_file: &str,
    entry: &DesktopEntryInfo,
) -> Result<(&'static str, Vec<std::string::String>), std::string::String> {
    use crate::api::terminal;
    let (terminal_program, _) = terminal::terminal_spec(&terminal::get_terminal())?;
    if !terminal::is_installed(terminal_program) {
        return Err(format!("{terminal_program} is not installed"));
    }

    terminal_launch_argv_for(terminal_program, file_path, desktop_file, entry)
}

/// Terminal-agnostic argv builder, separated from [terminal_launch_argv] so it
/// can be tested without depending on installed terminals.
#[cfg(all(unix, not(target_os = "macos")))]
fn terminal_launch_argv_for(
    terminal_program: &'static str,
    file_path: &str,
    desktop_file: &str,
    entry: &DesktopEntryInfo,
) -> Result<(&'static str, Vec<std::string::String>), std::string::String> {
    use crate::api::terminal;
    let program = expand_exec(&entry.exec, file_path, desktop_file, &entry.name);
    if program.is_empty() {
        return Err("This application has no launch command".to_string());
    }

    let (_, dir_args) = terminal::terminal_spec(terminal_program)?;
    let directory = Path::new(file_path)
        .parent()
        .map(|parent| parent.to_string_lossy().into_owned())
        .unwrap_or_else(|| "/".to_string());

    let mut argv: Vec<std::string::String> = vec![terminal_program.to_string()];
    argv.extend(dir_args.iter().map(|arg| arg.to_string()));
    argv.push(directory);

    match terminal_exec_style(terminal_program) {
        TerminalExecStyle::Argv(extra) => {
            argv.extend(extra.iter().map(|arg| arg.to_string()));
            argv.extend(program);
        }
        TerminalExecStyle::CommandString(flag) => {
            argv.push(flag.to_string());
            argv.push(
                program
                    .iter()
                    .map(|arg| terminal::shell_quote(arg))
                    .collect::<Vec<_>>()
                    .join(" "),
            );
        }
    }

    Ok((terminal_program, argv))
}

/// How a terminal emulator expects the command it should run.
enum TerminalExecStyle {
    /// Extra argv tokens (if any) followed by the program and its arguments.
    Argv(&'static [&'static str]),
    /// A flag taking one shell command string.
    CommandString(&'static str),
}

#[cfg(all(unix, not(target_os = "macos")))]
fn terminal_exec_style(terminal: &str) -> TerminalExecStyle {
    match terminal {
        "gnome-terminal" => TerminalExecStyle::Argv(&["--"]),
        "wezterm" => TerminalExecStyle::Argv(&["--"]),
        "kitty" | "foot" => TerminalExecStyle::Argv(&[]),
        "ghostty" | "alacritty" => TerminalExecStyle::Argv(&["-e"]),
        "konsole" | "urxvt" | "xterm" | "x-terminal-emulator" => {
            TerminalExecStyle::Argv(&["-e"])
        }
        "xfce4-terminal" | "terminator" => TerminalExecStyle::Argv(&["-x"]),
        "tilix" | "qterminal" => TerminalExecStyle::CommandString("-e"),
        _ => TerminalExecStyle::Argv(&["-e"]),
    }
}

/// Expands the desktop entry `Exec` line for [file_path]: tokenizes shell-like
/// quoting and substitutes the file field codes (`%f`/`%F`/`%u`/`%U`).
fn expand_exec(
    exec: &str,
    file_path: &str,
    desktop_file: &str,
    app_name: &str,
) -> Vec<std::string::String> {
    let mut argv: Vec<std::string::String> = Vec::new();
    let mut had_file_placeholder = false;

    for token in split_exec_line(exec) {
        let mut expanded = std::string::String::new();
        let mut chars = token.chars().peekable();

        while let Some(character) = chars.next() {
            if character != '%' {
                expanded.push(character);
                continue;
            }

            let Some(code) = chars.next() else {
                expanded.push('%');
                break;
            };

            match code {
                'f' | 'F' | 'u' | 'U' => {
                    expanded.push_str(file_path);
                    had_file_placeholder = true;
                }
                'c' => expanded.push_str(app_name),
                'k' => expanded.push_str(desktop_file),
                '%' => expanded.push('%'),
                // %i (icon) and unknown/obsolete codes carry no command text.
                _ => {}
            }
        }

        if !expanded.is_empty() {
            argv.push(expanded);
        }
    }

    if !had_file_placeholder {
        argv.push(file_path.to_string());
    }

    argv
}

/// Minimal shell-like tokenizer for desktop entry `Exec` lines: whitespace
/// separates arguments, single quotes are literal, double quotes and
/// backslashes escape the next character.
fn split_exec_line(exec: &str) -> Vec<std::string::String> {
    let mut args: Vec<std::string::String> = Vec::new();
    let mut current = std::string::String::new();
    let mut token_started = false;
    let mut quote: Option<char> = None;
    let mut chars = exec.chars();

    while let Some(character) = chars.next() {
        match quote {
            Some(quote_character) => {
                if character == quote_character {
                    quote = None;
                } else if character == '\\' && quote_character == '"' {
                    if let Some(escaped) = chars.next() {
                        current.push(escaped);
                    } else {
                        current.push(character);
                    }
                } else {
                    current.push(character);
                }
            }
            None => match character {
                '\'' | '"' => {
                    quote = Some(character);
                    token_started = true;
                }
                '\\' => {
                    if let Some(escaped) = chars.next() {
                        current.push(escaped);
                        token_started = true;
                    }
                }
                character if character.is_whitespace() => {
                    if token_started {
                        args.push(std::mem::take(&mut current));
                        token_started = false;
                    }
                }
                character => {
                    current.push(character);
                    token_started = true;
                }
            },
        }
    }

    if token_started {
        args.push(current);
    }

    args
}

struct DesktopEntryInfo {
    name: std::string::String,
    exec: std::string::String,
    comment: std::string::String,
    icon: std::string::String,
    mime_types: Vec<std::string::String>,
    categories: Vec<std::string::String>,
    hidden: bool,
    terminal: bool,
    app_type: std::string::String,
}

impl DesktopEntryInfo {
    /// Whether this app is a text editor or an IDE, so it can be offered for
    /// text files even when it does not advertise their exact MIME type.
    fn is_editor(&self) -> bool {
        self.categories
            .iter()
            .any(|category| category == "TextEditor" || category == "IDE")
    }
}

fn desktop_entry_dirs() -> Vec<PathBuf> {
    let mut dirs: Vec<PathBuf> = Vec::new();

    if let Ok(data_home) = env::var("XDG_DATA_HOME") {
        if !data_home.is_empty() {
            dirs.push(PathBuf::from(data_home).join("applications"));
        }
    } else {
        dirs.push(home_dir().join(".local/share/applications"));
    }

    if let Ok(data_dirs) = env::var("XDG_DATA_DIRS") {
        for dir in data_dirs.split(':').filter(|value| !value.is_empty()) {
            dirs.push(PathBuf::from(dir).join("applications"));
        }
    } else {
        dirs.push(PathBuf::from("/usr/local/share/applications"));
        dirs.push(PathBuf::from("/usr/share/applications"));
    }

    dirs
}

fn parse_desktop_entry(content: &str) -> Option<DesktopEntryInfo> {
    let mut in_desktop_entry = false;
    let mut name: Option<std::string::String> = None;
    let mut exec = std::string::String::new();
    let mut comment = std::string::String::new();
    let mut icon = std::string::String::new();
    let mut mime_types: Vec<std::string::String> = Vec::new();
    let mut categories: Vec<std::string::String> = Vec::new();
    let mut hidden = false;
    let mut terminal = false;
    let mut app_type = std::string::String::new();

    for line in content.lines() {
        let line = line.trim();

        if line.starts_with('[') {
            in_desktop_entry = line == "[Desktop Entry]";
            continue;
        }

        if !in_desktop_entry || line.starts_with('#') {
            continue;
        }

        let Some((key, value)) = line.split_once('=') else {
            continue;
        };

        let key = key.trim();
        let value = value.trim();

        match key {
            "Name" => name = Some(value.to_string()),
            "Exec" => exec = value.to_string(),
            "Comment" => comment = value.to_string(),
            "Icon" => icon = value.to_string(),
            "MimeType" => {
                mime_types = value
                    .split(';')
                    .filter(|item| !item.is_empty())
                    .map(|item| item.to_string())
                    .collect();
            }
            "Categories" => {
                categories = value
                    .split(';')
                    .filter(|item| !item.is_empty())
                    .map(|item| item.to_string())
                    .collect();
            }
            "Hidden" => hidden = value.eq_ignore_ascii_case("true"),
            "Terminal" => terminal = value.eq_ignore_ascii_case("true"),
            "Type" => app_type = value.to_string(),
            _ => {}
        }
    }

    name.map(|name| DesktopEntryInfo {
        name,
        exec,
        comment,
        icon,
        mime_types,
        categories,
        hidden,
        terminal,
        app_type,
    })
}

fn detect_mime_type(path: &str) -> Option<std::string::String> {
    let output = std::process::Command::new("xdg-mime")
        .args(["query", "filetype", path])
        .output()
        .ok()?;

    if !output.status.success() {
        return None;
    }

    let mime = String::from_utf8_lossy(&output.stdout).trim().to_string();
    if mime.is_empty() {
        None
    } else {
        Some(mime)
    }
}

fn mime_matches(declared: &str, actual: &str) -> bool {
    if declared == "*/*" {
        return true;
    }

    if let Some(prefix) = declared.strip_suffix("/*") {
        return actual.starts_with(prefix);
    }

    declared == actual
}

/// Source-code and plain-text extensions. Used as a fallback for files whose
/// MIME type gives nothing useful away (`text/x-c` for `.rs`/`.dart`, or
/// `inode/x-empty` for freshly created empty files).
const TEXT_EXTENSIONS: &[&str] = &[
    "bash", "bat", "c", "cc", "cfg", "cjs", "clj", "cljc", "cljs", "cmake", "conf", "cpp",
    "cs", "css", "csv", "cxx", "dart", "dockerfile", "edn", "el", "env", "erl", "ex", "exs",
    "fish", "fs", "fsx", "go", "gql", "gradle", "graphql", "h", "hpp", "hrl", "hs", "htm",
    "html", "hxx", "ini", "java", "js", "json", "jsonc", "jsx", "kt", "kts", "less", "lhs",
    "lisp", "log", "lua", "m", "markdown", "md", "mjs", "mm", "php", "pl", "pm", "proto",
    "ps1", "py", "pyw", "r", "rb", "rkt", "rs", "rst", "sass", "scala", "scm", "scss",
    "sh", "sql", "swift", "toml", "ts", "tsx", "txt", "vb", "xhtml", "xml", "yaml", "yml",
    "zsh",
];

/// Text-ish MIME types that are not under `text/` but are still edited as
/// plain text (configuration files, scripts, markup, ...).
const TEXT_APPLICATION_MIMES: &[&str] = &[
    "application/graphql",
    "application/javascript",
    "application/json",
    "application/sql",
    "application/toml",
    "application/x-httpd-php",
    "application/x-javascript",
    "application/x-perl",
    "application/x-php",
    "application/x-python",
    "application/x-ruby",
    "application/x-shellscript",
    "application/x-yaml",
    "application/xml",
    "application/yaml",
    "image/svg+xml",
];

/// MIME types reported for zero-byte files. Whether such a file is text
/// depends on its name, not on its (empty) contents.
const EMPTY_MIMES: &[&str] = &["inode/x-empty", "application/x-empty", "application/x-zerosize"];

fn is_text_like(mime: Option<&str>, path: &str) -> bool {
    if let Some(mime) = mime {
        if mime.starts_with("text/") || TEXT_APPLICATION_MIMES.contains(&mime) {
            return true;
        }
    }

    let path = Path::new(path);
    let is_empty = mime.is_some_and(|mime| EMPTY_MIMES.contains(&mime));

    if let Some(extension) = path.extension().and_then(|value| value.to_str()) {
        let extension = extension.to_ascii_lowercase();
        return TEXT_EXTENSIONS.contains(&extension.as_str());
    }

    let Some(name) = path.file_name().and_then(|value| value.to_str()) else {
        return false;
    };

    // Dotfiles (.bashrc, .gitignore) and common extension-less build files.
    if name.starts_with('.') {
        return true;
    }

    // An extension-less empty file (a freshly created "notes") is almost
    // certainly meant to hold text.
    if is_empty {
        return true;
    }

    matches!(
        name.to_ascii_lowercase().as_str(),
        "dockerfile" | "justfile" | "makefile" | "cmakelists.txt" | "meson.build" | "rakefile"
    )
}

#[cfg(test)]
mod tests {
    use super::*;

    fn entry(content: &str) -> DesktopEntryInfo {
        parse_desktop_entry(content).unwrap()
    }

    #[test]
    fn editor_categories_are_detected() {
        let zed = entry(
            "[Desktop Entry]\nName=Zed\nType=Application\nCategories=Utility;TextEditor;Development;IDE;\n",
        );
        assert!(zed.is_editor());

        let neovide = entry(
            "[Desktop Entry]\nName=Neovide\nType=Application\nCategories=Utility;TextEditor;\n",
        );
        assert!(neovide.is_editor());

        let browser = entry(
            "[Desktop Entry]\nName=Browser\nType=Application\nCategories=Network;WebBrowser;\n",
        );
        assert!(!browser.is_editor());
    }

    #[test]
    fn code_files_are_text_like_even_with_coarse_mime_types() {
        // xdg-mime reports text/x-c for many source extensions.
        assert!(is_text_like(Some("text/x-c"), "/tmp/main.rs"));
        assert!(is_text_like(Some("text/html"), "/tmp/index.html"));
        assert!(is_text_like(Some("application/json"), "/tmp/data.json"));
        assert!(is_text_like(Some("inode/x-empty"), "/tmp/main.dart"));
        assert!(is_text_like(Some("inode/x-empty"), "/tmp/notes"));
        assert!(is_text_like(Some("inode/x-empty"), "/tmp/.bashrc"));
        assert!(is_text_like(None, "/tmp/Makefile"));
        // Extension fallback for formats without a useful MIME association.
        assert!(is_text_like(Some("application/octet-stream"), "/tmp/app.dart"));
    }

    #[test]
    fn binary_files_are_not_text_like() {
        assert!(!is_text_like(Some("image/png"), "/tmp/photo.png"));
        assert!(!is_text_like(Some("application/zip"), "/tmp/archive.zip"));
        assert!(!is_text_like(Some("application/pdf"), "/tmp/doc.pdf"));
        assert!(!is_text_like(Some("inode/x-empty"), "/tmp/blob.bin"));
    }

    #[test]
    fn parses_categories_alongside_mime_types() {
        let info = entry(
            "[Desktop Entry]\nName=Editor\nType=Application\n\
             Categories=Utility;TextEditor;\nMimeType=text/plain;\n",
        );
        assert_eq!(info.categories, vec!["Utility", "TextEditor"]);
        assert_eq!(info.mime_types, vec!["text/plain"]);
    }

    #[test]
    fn terminal_flag_is_parsed() {
        let nvim = entry(
            "[Desktop Entry]\nName=Neovim\nType=Application\nTerminal=true\nExec=nvim %F\n",
        );
        assert!(nvim.terminal);

        let zed = entry("[Desktop Entry]\nName=Zed\nType=Application\nExec=zed %F\n");
        assert!(!zed.terminal);
    }

    #[test]
    fn exec_field_codes_are_expanded() {
        assert_eq!(
            expand_exec("nvim %F", "/tmp/main.rs", "/usr/share/applications/nvim.desktop", "Neovim"),
            vec!["nvim", "/tmp/main.rs"]
        );
        assert_eq!(
            expand_exec(
                "code --goto %f",
                "/tmp/a b.dart",
                "/usr/share/applications/code.desktop",
                "Code"
            ),
            vec!["code", "--goto", "/tmp/a b.dart"]
        );
        assert_eq!(
            expand_exec(
                "\"/opt/My Editor/editor\" --file=%U %i",
                "/tmp/x.html",
                "/usr/share/applications/editor.desktop",
                "Editor"
            ),
            vec!["/opt/My Editor/editor", "--file=/tmp/x.html"]
        );
        // No field code at all: the file is appended.
        assert_eq!(
            expand_exec("gvim", "/tmp/x.txt", "/usr/share/applications/gvim.desktop", "GVim"),
            vec!["gvim", "/tmp/x.txt"]
        );
    }

    #[test]
    fn exec_line_tokenizer_handles_quotes_and_escapes() {
        assert_eq!(
            split_exec_line("nvim --cmd \"set nu\" %F"),
            vec!["nvim", "--cmd", "set nu", "%F"]
        );
        assert_eq!(
            split_exec_line("'/opt/my editor/bin/editor' --new"),
            vec!["/opt/my editor/bin/editor", "--new"]
        );
        assert_eq!(
            split_exec_line("editor escaped\\ space"),
            vec!["editor", "escaped space"]
        );
    }

    #[cfg(all(unix, not(target_os = "macos")))]
    #[test]
    fn terminal_entries_launch_inside_the_terminal() {
        const DESKTOP: &str = "/usr/share/applications/nvim.desktop";
        let nvim = entry(
            "[Desktop Entry]\nName=Neovim\nType=Application\nTerminal=true\nExec=nvim %F\n",
        );

        let (program, argv) = terminal_launch_argv_for("kitty", "/tmp/main.rs", DESKTOP, &nvim)
            .unwrap();
        assert_eq!(program, "kitty");
        assert_eq!(
            argv,
            vec!["kitty", "--directory", "/tmp", "nvim", "/tmp/main.rs"]
        );

        let (_, argv) =
            terminal_launch_argv_for("gnome-terminal", "/tmp/main.rs", DESKTOP, &nvim).unwrap();
        assert_eq!(
            argv,
            vec![
                "gnome-terminal",
                "--working-directory",
                "/tmp",
                "--",
                "nvim",
                "/tmp/main.rs"
            ]
        );

        // Terminals taking a single command string get a shell-quoted one.
        let (_, argv) =
            terminal_launch_argv_for("tilix", "/tmp/main.rs", DESKTOP, &nvim).unwrap();
        assert_eq!(
            argv,
            vec![
                "tilix",
                "--working-directory",
                "/tmp",
                "-e",
                "'nvim' '/tmp/main.rs'"
            ]
        );
    }
}


