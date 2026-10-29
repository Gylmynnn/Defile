import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dbus/dbus.dart';
import 'package:get/get.dart';

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
  Future<void> start() async {
    if (_started || !Platform.isLinux) return;
    _started = true;

    try {
      final DBusClient client = DBusClient.session();
      _client = client;
      await client.requestName(busName);
      await client.registerObject(_PortalFileChooserObject(this));
    } catch (_) {
      _client = null;
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

    for (final String confPath in _portalConfPaths) {
      await File(confPath).parent.create(recursive: true);
      await File(confPath).writeAsString(
        _mergedPortalConf(await _readConf(confPath)),
      );
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

  Future<void> _restartPortalDaemon() async {
    final ProcessResult result = await Process.run('systemctl', <String>[
      '--user',
      'restart',
      'xdg-desktop-portal.service',
    ]);
    if (result.exitCode != 0) {
      await Process.run('pkill', <String>['-f', 'xdg-desktop-portal']);
    }
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
  /// path (the /tmp mount point dies with the squashfs).
  String get _dbusActivationContents {
    final String executable = Platform.environment['APPIMAGE'] ??
        Platform.resolvedExecutable;
    final String escaped = executable
        .replaceAll(r'\', r'\\')
        .replaceAll('"', r'\"');

    return '''
[D-BUS Service]
Name=$busName
Exec="$escaped" --dbus-portal
''';
  }
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

  /// OpenFile (o handle, s app_id, s parent_window, a{sv} options)
  ///   → (u response, a{sv} results)   [reply held open]
  ///
  /// The handle IS the frontend request path; we export a Close() object
  /// there and only finish the method call once the user has decided.
  Future<DBusMethodResponse> _openFile(DBusMethodCall call) async {
    final String handlePath =
        (call.values[0] as DBusObjectPath).value;
    final String appId = call.values.length > 1
        ? (call.values[1] as DBusString).value
        : '';

    final Map<DBusString, DBusVariant> options = call.values.length > 3
        ? (call.values[3] as DBusDict).children.cast<DBusString, DBusVariant>()
        : <DBusString, DBusVariant>{};

    bool multiple = false;
    bool directoryMode = false;
    String acceptLabel = '';
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
