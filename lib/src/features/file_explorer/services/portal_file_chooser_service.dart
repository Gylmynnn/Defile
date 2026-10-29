import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dbus/dbus.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:get/get.dart';
import 'package:window_manager/window_manager.dart';

import '../controllers/portal_pick_controller.dart';

/// Implements the `org.freedesktop.impl.portal.FileChooser` backend
/// interface (xdg-desktop-portal ≥ 1.17 protocol) so the desktop portal
/// routes "Open file" dialogs of other applications into Defile.
///
/// The daemon calls [PortalFileChooserService] with the frontend request
/// path as the handle; the method reply is held open until the user picks
/// or cancels, then completes with `(u response_code, a{sv} results)`.
/// Closing is done by the daemon through `Close()` on the request object
/// we export at that same path.
class PortalFileChooserService {
  static const String busName = 'org.freedesktop.impl.portal.desktop.defile';

  DBusClient? _client;
  bool _started = false;
  final Map<String, PendingFileChooser> _pending =
      <String, PendingFileChooser>{};

  PortalPickController get _picker => Get.isRegistered<PortalPickController>()
      ? Get.find<PortalPickController>()
      : Get.put(PortalPickController());

  /// Connects to the session bus, claims the backend name and exports the
  /// FileChooser interface. Failures degrade silently — the rest of the
  /// app keeps working without the portal.
  ///
  /// Returns true when this instance owns the backend bus name; false when
  /// another instance already does (or startup failed) — the caller decides
  /// whether that is fatal (portal mode) or harmless (normal window).
  Future<bool> start() async {
    if (_started || !Platform.isLinux) return false;
    _started = true;

    try {
      final DBusClient client = DBusClient.session();
      _client = client;
      // Export the object BEFORE claiming the name: the daemon introspects
      // the backend as soon as the name appears on the bus. Registering in
      // the other order races — when introspection wins, it sees no
      // interfaces and never exports FileChooser for the whole session.
      await client.registerObject(_PortalFileChooserObject(this));
      final DBusRequestNameReply reply = await client.requestName(busName);
      return reply == DBusRequestNameReply.primaryOwner;
    } catch (e) {
      debugPrint('Portal FileChooser backend failed to start: $e');
      _client = null;
      return false;
    }
  }

  Future<void> stop() async {
    await _client?.close();
    _client = null;
    _started = false;
  }

  /// Registers the in-flight request and shows it in the picker UI.
  void present(PendingFileChooser pending) {
    _pending[pending.request.handlePath] = pending;
    _picker.present(pending.request);
    // Reveal the window when running as the hidden D-Bus-activated portal
    // backend; harmless (already visible) in a normal session.
    unawaited(windowManager.show());
    unawaited(windowManager.focus());
  }

  /// Replies to the daemon with the chosen files and tears the request down.
  Future<void> completeRequest(
    PortalPickRequest request,
    List<String> paths,
  ) async {
    final PendingFileChooser? pending = _pending[request.handlePath];
    if (pending != null) await complete(pending, paths);
  }

  /// Replies with "cancelled" and tears the request down.
  Future<void> cancelRequest(PortalPickRequest request) async {
    final PendingFileChooser? pending = _pending[request.handlePath];
    if (pending != null) await cancel(pending);
  }

  Future<void> complete(PendingFileChooser pending, List<String> paths) async {
    if (_pending.remove(pending.request.handlePath) == null) return;
    _picker.dismiss(pending.request);

    await pending.finish(
      DBusMethodSuccessResponse(<DBusValue>[
        const DBusUint32(0),
        DBusDict.stringVariant(<String, DBusValue>{
          'uris': DBusArray(
            DBusSignature('s'),
            paths.map((String path) => DBusString(Uri.file(path).toString())),
          ),
          'writable': const DBusBoolean(true),
        }),
      ]),
    );
  }

  /// Replies with "cancelled" and tears the request down.
  Future<void> cancel(PendingFileChooser pending) async {
    if (_pending.remove(pending.request.handlePath) == null) return;
    _picker.dismiss(pending.request);

    await pending.finish(
      DBusMethodSuccessResponse(<DBusValue>[
        const DBusUint32(1),
        DBusDict.stringVariant(<String, DBusValue>{}),
      ]),
    );
  }

  Future<void> _cancelByPath(String handlePath) async {
    final PendingFileChooser? pending = _pending[handlePath];
    if (pending != null) await cancel(pending);
  }

  // ==========================================
  // Portal registration (xdg-desktop-portal side)
  // ==========================================

  String get _portalDir {
    final String home = Platform.environment['HOME'] ?? '~';
    return '$home/.local/share/xdg-desktop-portal/portals';
  }

  String get portalPortalFilePath => '$_portalDir/defile.portal';

  String get _configDir {
    final String configHome =
        Platform.environment['XDG_CONFIG_HOME'] ?? '~/.config';
    return configHome.startsWith('~')
        ? configHome.replaceFirst('~', Platform.environment['HOME'] ?? '~')
        : configHome;
  }

  /// All portal preference files we may touch: the desktop-specific
  /// `<desktop>-portals.conf` first, then the generic one.
  List<String> get _portalConfPaths {
    final List<String> paths = <String>[
      '$_configDir/xdg-desktop-portal/portals.conf',
    ];
    final String? desktop = Platform.environment['XDG_CURRENT_DESKTOP'];
    if (desktop != null && desktop.isNotEmpty) {
      paths.insert(0, '$_configDir/${desktop.toLowerCase()}-portals.conf');
    }
    return paths;
  }

  bool get isRegisteredAsPortal => File(portalPortalFilePath).existsSync();

  /// Installs `defile.portal` and prepends Defile to the FileChooser
  /// preference list of the user's portals.conf, plus the D-Bus activation
  /// file so the daemon can start Defile on demand. Restarts
  /// xdg-desktop-portal so the change takes effect.
  Future<void> registerAsPortal() async {
    final Directory dir = Directory(_portalDir);
    await dir.create(recursive: true);
    await File(portalPortalFilePath).writeAsString(_portalFileContents);

    final File activationFile = File(dbusActivationFilePath);
    await activationFile.parent.create(recursive: true);
    await activationFile.writeAsString(_dbusActivationContents);

    // Backend unit: the toggle starts it eagerly so the bus name is owned
    // before the daemon re-introspects (warm = instant). Crash supervision
    // comes from Restart=on-failure. The daemon must be up FIRST: the
    // backend's GTK layer resolves its settings through
    // org.freedesktop.portal.Settings at boot, and with the daemon down
    // that call blocks for its full 25 s bus timeout — delaying the name
    // claim past the daemon's own activation budget (a mutual wait that
    // only ever resolves by timeouts).
    await _installPortalUnit();
    await Process.run(
      'systemctl',
      <String>['--user', 'start', 'xdg-desktop-portal.service'],
    );
    await Process.run(
      'systemctl',
      <String>['--user', 'start', 'defile-portal.service'],
    );

    for (final String confPath in _portalConfPaths) {
      await File(confPath).parent.create(recursive: true);
      await File(confPath).writeAsString(
        _mergedPortalConf(await _readConf(confPath)),
      );
    }

    // The daemon re-introspects implementations at startup. With our bus
    // name already owned, introspection is warm and instant; without it,
    // the daemon goes through StartServiceByName and blocks until the
    // backend appears (or its 25 s budget expires). Wait for the claim so
    // the bounce below always finds the backend alive.
    for (int attempt = 0; attempt < 70; attempt++) {
      final ProcessResult owner = await Process.run(
        'gdbus',
        <String>[
          'call',
          '--session',
          '--dest',
          'org.freedesktop.DBus',
          '--object-path',
          '/org/freedesktop/DBus',
          '--method',
          'org.freedesktop.DBus.GetNameOwner',
          busName,
        ],
      );
      if (owner.stdout.contains(':1.')) break;
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }

    await _restartPortalDaemon();
  }

  /// Removes the registration. The FileChooser preference reverts to the
  /// previous backend; other lines are left untouched.
  Future<void> unregisterPortal() async {
    final File portalFile = File(portalPortalFilePath);
    if (portalFile.existsSync()) await portalFile.delete();

    final File activationFile = File(dbusActivationFilePath);
    if (activationFile.existsSync()) await activationFile.delete();

    await _removePortalUnit();

    for (final String confPath in _portalConfPaths) {
      final File conf = File(confPath);
      if (!conf.existsSync()) continue;
      final String merged = _mergedPortalConf(await _readConf(confPath));
      // When nothing of ours remains, drop the file we effectively own.
      if (!merged.contains('defile')) {
        await conf.delete();
      } else {
        await conf.writeAsString(merged);
      }
    }

    await _restartPortalDaemon();
  }

  Future<String> _readConf(String path) async {
    final File file = File(path);
    return file.existsSync() ? await file.readAsString() : '';
  }

  /// Rewrites a portals.conf so FileChooser prefers Defile while every
  /// other interface (and the default fallback) keeps its previous value.
  String _mergedPortalConf(String existing) {
    String chooser = existing
        .split('\n')
        .firstWhere(
          (String line) =>
              line.startsWith('org.freedesktop.impl.portal.FileChooser='),
          orElse: () => '',
        );
    chooser = chooser.isEmpty ? 'gtk' : chooser.split('=').last.trim();
    if (chooser.startsWith('defile')) {
      chooser = chooser.substring('defile'.length).replaceAll(
            RegExp(r'^;+'),
            '',
          );
    }
    final String chooserLine = chooser.isEmpty ? 'defile' : 'defile;$chooser';

    String def = existing
        .split('\n')
        .firstWhere(
          (String line) => line.startsWith('default='),
          orElse: () => '',
        );
    def = def.isEmpty ? 'gtk' : def.split('=').last.trim();

    final StringBuffer buffer = StringBuffer('[preferred]\n');
    buffer.writeln('org.freedesktop.impl.portal.FileChooser=$chooserLine');
    buffer.writeln('default=$def');
    return buffer.toString();
  }

  /// Self-healing for the one portal failure mode that survives everything
  /// else: the daemon introspects backends only during its own startup, and
  /// a cold AppImage start (squashfs page-in under disk load) can exceed its
  /// ~25 s activation budget — the daemon then gives up and never exports
  /// FileChooser even though this backend owns the name seconds later. When
  /// that state is detected, bounce the daemon once: it re-introspects the
  /// now-warm backend and the interface comes up in under a second.
  Future<void> ensureFrontendWired() async {
    if (!Platform.isLinux || _client == null) return;

    Future<bool> chooserExported() async {
      try {
        final DBusRemoteObject frontend = DBusRemoteObject(
          _client!,
          name: 'org.freedesktop.portal.Desktop',
          path: DBusObjectPath('/org/freedesktop/portal/desktop'),
        );
        final DBusIntrospectNode node = await frontend.introspect();
        return node.interfaces.any(
          (DBusIntrospectInterface interface) =>
              interface.name == 'org.freedesktop.portal.FileChooser',
        );
      } catch (_) {
        return false;
      }
    }

    // Give a daemon that started before us time to finish its startup
    // introspection, which completes right after our name claim.
    await Future<void>.delayed(const Duration(seconds: 10));
    if (await chooserExported()) return;

    await _restartPortalDaemon();
    await Future<void>.delayed(const Duration(seconds: 8));
    debugPrint(
      await chooserExported()
          ? 'Portal daemon was missing FileChooser; restarted and wired it.'
          : 'Portal daemon still lacks FileChooser after a restart.',
    );
  }

  /// Restarting the portal daemon reliably takes two steps: after a session
  /// crash the daemon can end up running OUTSIDE any systemd unit (spawned
  /// directly by dbus-daemon), and `systemctl --user restart` then only
  /// starts a second instance that loses the name race and exits while the
  /// stale one stays. Kill the process first, then start the unit fresh.
  /// The anchored pattern spares xdg-desktop-portal-gtk / -hyprland.
  Future<void> _restartPortalDaemon() async {
    await Process.run('pkill', <String>[
      '-f',
      '^/usr/lib/xdg-desktop-portal\$',
    ]);
    await Future<void>.delayed(const Duration(milliseconds: 800));
    final ProcessResult result = await Process.run('systemctl', <String>[
      '--user',
      'start',
      'xdg-desktop-portal.service',
    ]);
    if (result.exitCode != 0) {
      debugPrint('xdg-desktop-portal failed to start: ${result.stderr}');
    }
  }

  /// Supervised backend unit: the settings toggle starts it eagerly (warm
  /// name claim before the daemon re-introspects) and Restart=on-failure
  /// revives it after crashes; session logout stops it cleanly (SIGTERM →
  /// our exit handler). No [Install] section: at login the daemon's own
  /// D-Bus activation covers the first start (transient units survive its
  /// 25 s timeout — a bound unit would get stopped with it).
  String get _portalUnitPath => '$_configDir/systemd/user/defile-portal.service';

  String get _portalUnitContents {
    return '''
[Unit]
Description=Defile portal backend (headless file chooser)
# xdg-desktop-portal only wires its FileChooser interface while the backend
# stays reachable, so this unit must never die mid-session; its window stays
# hidden and closing that window merely hides it.
PartOf=graphical-session.target

[Service]
Type=simple
ExecStart="$_escapedLauncherExecutable" --dbus-portal
Restart=on-failure
RestartSec=2s
''';
  }

  Future<void> _installPortalUnit() async {
    final File unit = File(_portalUnitPath);
    await unit.parent.create(recursive: true);
    await unit.writeAsString(_portalUnitContents);
    await Process.run('systemctl', <String>['--user', 'daemon-reload']);
  }

  Future<void> _removePortalUnit() async {
    final File unit = File(_portalUnitPath);
    if (!unit.existsSync()) return;
    await Process.run(
      'systemctl',
      <String>['--user', 'stop', 'defile-portal.service'],
    );
    await unit.delete();
    await Process.run('systemctl', <String>['--user', 'daemon-reload']);
  }

  static const String _portalFileContents = '''
[portal]
DBusName=$busName
Interfaces=org.freedesktop.impl.portal.FileChooser;
''';

  /// Path of the D-Bus activation file for the backend bus name.
  String get dbusActivationFilePath {
    final String home = Platform.environment['HOME'] ?? '~';
    return '$home/.local/share/dbus-1/services/$busName.service';
  }

  /// Lets xdg-desktop-portal auto-start Defile when a dialog is requested
  /// and no instance is running. `$APPIMAGE` is the persistent launcher
  /// path (the /tmp mount point dies with the squashfs). Deliberately
  /// WITHOUT `SystemdService=`: when a cold start exceeds the daemon's 25 s
  /// activation budget, dbus cancels the activation — a bound unit would be
  /// stopped with it, while a transient one survives and the in-app
  /// self-heal ([ensureFrontendWired]) wires everything up once it claims
  /// the name.
  String get _dbusActivationContents {
    return '''
[D-BUS Service]
Name=$busName
Exec="$_escapedLauncherExecutable" --dbus-portal
''';
  }

  static final String _escapedLauncherExecutable =
      (Platform.environment['APPIMAGE'] ?? Platform.resolvedExecutable)
          .replaceAll(r'\', r'\\')
          .replaceAll('"', r'\"');
}

/// One in-flight request: the caller's data plus the machinery to hold the
/// D-Bus method reply open until the user has made a choice.
class PendingFileChooser {
  PendingFileChooser({
    required this.request,
    required this.completer,
    required this.object,
  });

  final PortalPickRequest request;
  final Completer<DBusMethodResponse> completer;
  final DBusObject object;

  /// Completes the held reply and unexports the request object.
  Future<void> finish(DBusMethodResponse response) async {
    if (!completer.isCompleted) {
      completer.complete(response);
    }
    try {
      final DBusClient? client = Get.find<PortalFileChooserService>()._client;
      await client?.unregisterObject(object);
    } catch (_) {}
  }
}

/// The data the picker UI needs about one open dialog request.
class PortalPickRequest {
  PortalPickRequest({
    required this.handlePath,
    required this.appId,
    required this.isDirectoryMode,
    required this.multiple,
    required this.acceptLabel,
    this.currentFolder,
  });

  /// The frontend request object path — also the path of the Close()
  /// object we export for this request.
  final String handlePath;

  /// Bus name of the application that asked for the dialog.
  final String appId;

  /// True when the caller wants a directory (`mode='opendirectory'`).
  final bool isDirectoryMode;

  final bool multiple;

  /// Label for the confirm button, e.g. "Open" / "Select".
  final String acceptLabel;

  /// Directory the caller wants the dialog to start in.
  final String? currentFolder;

  String get title => acceptLabel.isEmpty
      ? (isDirectoryMode ? 'Select Folder' : 'Open File')
      : acceptLabel;
}

/// Exports `org.freedesktop.impl.portal.FileChooser` on the well-known
/// backend object path.
class _PortalFileChooserObject extends DBusObject {
  _PortalFileChooserObject(this._service)
    : super(DBusObjectPath('/org/freedesktop/portal/desktop'));

  final PortalFileChooserService _service;

  static const String _interface = 'org.freedesktop.impl.portal.FileChooser';

  @override
  List<DBusIntrospectInterface> introspect() => <DBusIntrospectInterface>[
    DBusIntrospectInterface(
      _interface,
      methods: <DBusIntrospectMethod>[
        DBusIntrospectMethod('OpenFile'),
        DBusIntrospectMethod('SaveFile'),
      ],
    ),
  ];

  @override
  Future<DBusMethodResponse> handleMethodCall(DBusMethodCall call) async {
    if (call.interface != _interface) {
      return DBusMethodErrorResponse.unknownInterface();
    }

    switch (call.name) {
      case 'OpenFile':
        return _openFile(call);
      case 'SaveFile':
        return DBusMethodErrorResponse.notSupported(
          'Saving through the portal is not implemented yet',
        );
    }
    return DBusMethodErrorResponse.unknownMethod();
  }

  /// OpenFile (o handle, s app_id, s parent_window, s title, a{sv} options)
  ///   → (u response, a{sv} results)   [reply held open]
  ///
  /// The handle IS the frontend request path; we export a Close() object
  /// there and only finish the method call once the user has decided.
  Future<DBusMethodResponse> _openFile(DBusMethodCall call) async {
    final String handlePath =
        (call.values[0] as DBusObjectPath).value;

    String stringArg(int index) {
      if (call.values.length <= index) return '';
      final DBusValue value = call.values[index];
      return value is DBusString ? value.value : '';
    }

    // (handle, app_id, parent_window, title, options)
    final String appId = stringArg(1);
    final String title = stringArg(3);

    final Map<DBusString, DBusVariant> options =
        call.values.length > 4 && call.values[4] is DBusDict
            ? (call.values[4] as DBusDict)
                  .children
                  .cast<DBusString, DBusVariant>()
            : <DBusString, DBusVariant>{};

    bool multiple = false;
    bool directoryMode = false;
    String acceptLabel = title;
    String? currentFolder;

    final DBusVariant? mode = options[const DBusString('mode')];
    if (mode != null) {
      directoryMode = (mode.value as DBusString).value == 'opendirectory';
    }
    final DBusVariant? multi = options[const DBusString('multiple')];
    if (multi != null) {
      multiple = (multi.value as DBusBoolean).value;
    }
    final DBusVariant? label = options[const DBusString('accept_label')];
    if (label != null) {
      acceptLabel = (label.value as DBusString).value;
    }
    final DBusVariant? folder = options[const DBusString('current_folder')];
    if (folder != null) {
      final DBusValue inner = folder.value;
      final List<int> bytes = inner is DBusArray
          ? inner.mapByte().toList()
          : const <int>[];
      final String path = utf8.decode(bytes).replaceAll('\x00', '');
      if (Directory(path).existsSync()) currentFolder = path;
    }

    final PortalPickRequest request = PortalPickRequest(
      handlePath: handlePath,
      appId: appId,
      isDirectoryMode: directoryMode,
      multiple: multiple,
      acceptLabel: acceptLabel,
      currentFolder: currentFolder,
    );

    final _PortalRequestObject object = _PortalRequestObject(
      DBusObjectPath(handlePath),
      request,
      _service,
    );

    final DBusClient? client = _service._client;
    if (client == null) {
      return DBusMethodErrorResponse.failed('No session bus connection');
    }
    await client.registerObject(object);

    final PendingFileChooser pending = PendingFileChooser(
      request: request,
      completer: Completer<DBusMethodResponse>(),
      object: object,
    );
    _service.present(pending);

    // Hold the D-Bus reply open — completing this future later sends the
    // actual (response, results) back to the portal daemon.
    return pending.completer.future;
  }
}

/// The request object the daemon calls `Close()` on to cancel the dialog.
class _PortalRequestObject extends DBusObject {
  _PortalRequestObject(
    super.path,
    this.request,
    this._service,
  );

  final PortalPickRequest request;
  final PortalFileChooserService _service;

  static const String _interface = 'org.freedesktop.impl.portal.Request';

  @override
  List<DBusIntrospectInterface> introspect() => <DBusIntrospectInterface>[
    DBusIntrospectInterface(
      _interface,
      methods: <DBusIntrospectMethod>[DBusIntrospectMethod('Close')],
    ),
  ];

  @override
  Future<DBusMethodResponse> handleMethodCall(DBusMethodCall call) async {
    if (call.interface != _interface || call.name != 'Close') {
      return DBusMethodErrorResponse.unknownMethod();
    }
    await _service._cancelByPath(request.handlePath);
    return DBusMethodSuccessResponse([]);
  }
}
