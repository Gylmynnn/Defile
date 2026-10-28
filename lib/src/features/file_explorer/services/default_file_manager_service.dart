import 'dart:io';

/// Registers Defile as the system's folder handler so `xdg-open <directory>`
/// launches it. Works entirely at the user level: a desktop entry is written
/// to `~/.local/share/applications` and associated with `inode/directory`
/// through `xdg-mime` — no root required.
class DefaultFileManagerService {
  static const String desktopFileName = 'defile.desktop';
  static const String _mimeType = 'inode/directory';

  /// Only meaningful on Linux; callers hide the controls elsewhere.
  bool get isSupported => Platform.isLinux;

  String get desktopFilePath {
    final String home = Platform.environment['HOME'] ?? '~';
    return '$home/.local/share/applications/$desktopFileName';
  }

  /// Name of the .desktop currently handling folders, or null when the query
  /// fails (xdg-mime missing, non-Linux, …).
  Future<String?> queryDefault() async {
    if (!isSupported) return null;
    try {
      final ProcessResult result = await Process.run('xdg-mime', <String>[
        'query',
        'default',
        _mimeType,
      ]);
      if (result.exitCode != 0) return null;
      final String value = (result.stdout as String).trim();
      return value.isEmpty ? null : value;
    } on ProcessException {
      return null;
    }
  }

  Future<bool> isDefault() async => await queryDefault() == desktopFileName;

  /// Writes the desktop entry pointing at the running executable and
  /// associates it with the directory mime type. Also installs the
  /// org.freedesktop.FileManager1 D-Bus activation file so browsers'
  /// "Show in folder" actions land in Defile. Throws when the association
  /// step fails so callers can surface an error toast.
  Future<void> setAsDefault() async {
    final File file = File(desktopFilePath);
    await file.parent.create(recursive: true);
    await file.writeAsString(entryContents(_executableForEntry()));

    final File dbusServiceFile = File(fileManager1ServiceFilePath);
    await dbusServiceFile.parent.create(recursive: true);
    await dbusServiceFile.writeAsString(
      fileManager1ServiceContents(_executableForEntry()),
    );

    // GLib resolves handlers through mimeinfo.cache; without regenerating it
    // defile.desktop stays invisible and the lookup falls through to the
    // previous handler even though the mimeapps.list entry is correct.
    await Process.run('update-desktop-database', <String>[
      file.parent.path,
    ]);

    final ProcessResult result = await Process.run('xdg-mime', <String>[
      'default',
      desktopFileName,
      _mimeType,
    ]);
    if (result.exitCode != 0) {
      throw Exception('xdg-mime failed: ${result.stderr}');
    }

    // Pick up the new activation file without logging out.
    await Process.run('dbus-send', <String>[
      '--session',
      '--type=method_call',
      '--dest=org.freedesktop.DBus',
      '/org/freedesktop/DBus',
      'org.freedesktop.DBus.ReloadConfig',
    ]);

    // Verify the association actually took. When it did not, surface the
    // handler that is still owning folders instead of a false success.
    final String? current = await queryDefault();
    if (current != desktopFileName) {
      throw Exception('still handled by ${current ?? 'no handler'}');
    }
  }

  /// The launcher path written into the desktop entry. AppImage sets $APPIMAGE
  /// to the .AppImage file itself — the mount-point binary inside /tmp dies
  /// with the squashfs, so prefer the persistent AppImage path.
  String _executableForEntry() {
    return Platform.environment['APPIMAGE'] ?? Platform.resolvedExecutable;
  }

  /// D-Bus activation file for the FileManager1 interface. The user-level
  /// services directory overrides the system one (Nautilus & co.), so the
  /// "Show in folder" buttons of browsers route to Defile.
  String get fileManager1ServiceFilePath {
    final String home = Platform.environment['HOME'] ?? '~';
    return '$home/.local/share/dbus-1/services/org.freedesktop.FileManager1.service';
  }

  String fileManager1ServiceContents(String executablePath) {
    final String escaped = executablePath
        .replaceAll(r'\', r'\\')
        .replaceAll('"', r'\"');

    return '''
[D-BUS Service]
Name=org.freedesktop.FileManager1
Exec="$escaped" --dbus-file-manager1
''';
  }

  /// The desktop entry handed to `xdg-mime`. `%u` forwards the opened path
  /// (URI or plain) to Defile's CLI arguments.
  String entryContents(String executablePath) {
    final String escaped = executablePath
        .replaceAll(r'\', r'\\')
        .replaceAll('"', r'\"');

    return '''
[Desktop Entry]
Type=Application
Name=Defile
GenericName=File Manager
Comment=Browse and manage files and folders
Exec="$escaped" %u
Terminal=false
Categories=System;FileTools;FileManager;
MimeType=inode/directory;
StartupWMClass=defile
''';
  }
}
