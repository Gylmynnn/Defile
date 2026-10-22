use std::path::Path;

use crate::api::settings::{read_setting, write_setting};

#[cfg(all(unix, not(target_os = "macos")))]
const TERMINALS: [(&str, &[&str]); 14] = [
    ("gnome-terminal", &["--working-directory"]),
    ("konsole", &["--workdir"]),
    ("xfce4-terminal", &["--working-directory"]),
    ("kitty", &["--directory"]),
    ("ghostty", &["--working-directory"]),
    ("alacritty", &["--working-directory"]),
    ("wezterm", &["start", "--cwd"]),
    ("foot", &["--working-directory"]),
    ("tilix", &["--working-directory"]),
    ("qterminal", &["--workdir"]),
    ("terminator", &["--working-directory"]),
    ("x-terminal-emulator", &[]),
    ("urxvt", &[]),
    ("xterm", &[]),
];

pub(crate) fn get_terminal() -> std::string::String {
    read_setting("terminal")
}

pub(crate) fn set_terminal(terminal: &str) -> Result<(), std::string::String> {
    let terminal = terminal.trim();

    if !terminal.is_empty() && !is_supported(terminal) {
        return Err(format!("Unsupported terminal: {terminal}"));
    }

    write_setting("terminal", terminal)
}

pub(crate) fn available_terminals() -> Vec<std::string::String> {
    #[cfg(all(unix, not(target_os = "macos")))]
    {
        return TERMINALS
            .iter()
            .filter(|(program, _)| is_installed(program))
            .map(|(program, _)| program.to_string())
            .collect();
    }

    #[cfg(not(all(unix, not(target_os = "macos"))))]
    Vec::new()
}

pub(crate) fn open_in_terminal(
    path: std::string::String,
    terminal: std::string::String,
) -> Result<(), std::string::String> {
    let directory = Path::new(&path);

    if !directory.is_dir() {
        return Err(format!("Directory not found: {path}"));
    }

    #[cfg(target_os = "macos")]
    {
        let _ = terminal;
        std::process::Command::new("open")
            .arg("-a")
            .arg("Terminal")
            .arg(directory)
            .status()
            .map_err(|error| format!("Failed to open Terminal: {error}"))?;

        return Ok(());
    }

    #[cfg(windows)]
    {
        let _ = terminal;
        std::process::Command::new("cmd")
            .args(["/C", "start", "cmd", "/K"])
            .arg(format!("cd /d {}", directory.display()))
            .spawn()
            .map_err(|error| format!("Failed to open Command Prompt: {error}"))?;

        return Ok(());
    }

    #[cfg(all(unix, not(target_os = "macos")))]
    {
        let (program, args) = terminal_spec(&terminal)?;

        if !is_installed(program) {
            return Err(format!("{program} is not installed"));
        }

        let quoted = shell_quote(&path);
        let argument = args.join(" ");
        let launch = if argument.is_empty() {
            program.to_string()
        } else {
            format!("{program} {argument} {quoted}")
        };

        std::process::Command::new("sh")
            .args([
                "-c",
                &format!("cd {quoted} && setsid {launch} >/dev/null 2>&1 &"),
            ])
            .status()
            .map_err(|error| format!("Failed to run {program}: {error}"))?;

        return Ok(());
    }

    #[allow(unreachable_code)]
    Err("Terminal is not supported on this platform".to_string())
}

#[cfg(all(unix, not(target_os = "macos")))]
fn terminal_spec(terminal: &str) -> Result<(&'static str, &'static [&'static str]), String> {
    if terminal.is_empty() {
        return TERMINALS
            .iter()
            .find(|(program, _)| is_installed(program))
            .map(|(program, args)| (*program, *args))
            .ok_or_else(|| {
                format!(
                    "No terminal installed ({})",
                    TERMINALS
                        .iter()
                        .map(|(program, _)| *program)
                        .collect::<Vec<_>>()
                        .join(", ")
                )
            });
    }

    TERMINALS
        .iter()
        .find(|(program, _)| *program == terminal)
        .map(|(program, args)| (*program, *args))
        .ok_or_else(|| format!("Unsupported terminal: {terminal}"))
}

fn is_supported(terminal: &str) -> bool {
    #[cfg(all(unix, not(target_os = "macos")))]
    {
        return TERMINALS.iter().any(|(program, _)| *program == terminal);
    }

    #[cfg(not(all(unix, not(target_os = "macos"))))]
    false
}

#[cfg(all(unix, not(target_os = "macos")))]
fn is_installed(program: &str) -> bool {
    std::process::Command::new("sh")
        .args(["-c", &format!("command -v {program} >/dev/null 2>&1")])
        .status()
        .map(|status| status.success())
        .unwrap_or(false)
}

#[cfg(all(unix, not(target_os = "macos")))]
fn shell_quote(value: &str) -> std::string::String {
    format!("'{}'", value.replace('\'', "'\\''"))
}

#[cfg(test)]
mod tests {
    #[test]
    fn get_and_set_terminal_setting() {
        crate::api::settings::with_temp_config(|| {
            super::set_terminal("").unwrap();
            assert_eq!(super::get_terminal(), "");

            super::set_terminal("kitty").unwrap();
            assert_eq!(super::get_terminal(), "kitty");

            assert!(super::set_terminal("not-a-terminal").is_err());
        });
    }
}
