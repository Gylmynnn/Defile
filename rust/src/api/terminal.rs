use std::path::Path;

pub(crate) fn open_in_terminal(path: std::string::String) -> Result<(), std::string::String> {
    let directory = Path::new(&path);

    if !directory.is_dir() {
        return Err(format!("Directory not found: {path}"));
    }

    #[cfg(target_os = "macos")]
    {
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
        std::process::Command::new("cmd")
            .args(["/C", "start", "cmd", "/K"])
            .arg(format!("cd /d {}", directory.display()))
            .spawn()
            .map_err(|error| format!("Failed to open Command Prompt: {error}"))?;

        return Ok(());
    }

    #[cfg(all(unix, not(target_os = "macos")))]
    {
        const TERMINALS: [(&str, &[&str]); 9] = [
            ("gnome-terminal", &["--working-directory"]),
            ("konsole", &["--workdir"]),
            ("xfce4-terminal", &["--working-directory"]),
            ("kitty", &["--directory"]),
            ("alacritty", &["--working-directory"]),
            ("qterminal", &["--workdir"]),
            ("terminator", &["--working-directory"]),
            ("x-terminal-emulator", &["--working-directory"]),
            ("xterm", &[]),
        ];

        let quoted = shell_quote(&path);

        for (program, args) in TERMINALS {
            let available = std::process::Command::new("sh")
                .args(["-c", &format!("command -v {program} >/dev/null 2>&1")])
                .status()
                .map(|status| status.success())
                .unwrap_or(false);

            if !available {
                continue;
            }

            let argument = args.join(" ");
            let command = if argument.is_empty() {
                format!("cd {quoted} && exec {program}")
            } else {
                format!("exec {program} {argument} {quoted}")
            };

            std::process::Command::new("sh")
                .args(["-c", &format!("setsid {command} >/dev/null 2>&1 &")])
                .status()
                .map_err(|error| format!("Failed to run {program}: {error}"))?;

            return Ok(());
        }

        return Err("No terminal installed (gnome-terminal, konsole, xterm, ...)".to_string());
    }

    #[allow(unreachable_code)]
    Err("Terminal is not supported on this platform".to_string())
}

#[cfg(all(unix, not(target_os = "macos")))]
fn shell_quote(value: &str) -> std::string::String {
    format!("'{}'", value.replace('\'', "'\\''"))
}
