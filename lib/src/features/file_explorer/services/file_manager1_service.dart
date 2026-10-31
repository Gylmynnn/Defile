import 'dart:async';
import 'dart:io';

import 'package:defile/src/rust/api/file_entry.dart' as rust;
import 'package:dbus/dbus.dart';
import 'package:get/get.dart';
import 'package:window_manager/window_manager.dart';

import '../controllers/explorer_tabs_controller.dart';
import '../controllers/file_explorer_controller.dart';
import '../controllers/portal_pick_controller.dart';

/// Owns the `org.freedesktop.FileManager1` session-bus name and serves the
/// methods browsers and desktop environments call for "Show in folder" /
/// "Open folder" actions. Claiming this name makes Defile the target of
/// D-Bus activation for that interface; its activation file is installed by
/// the [DefaultFileManagerService].
class FileManager1Service {
  static const String busName = 'org.freedesktop.FileManager1';

  DBusClient? _client;
  bool _started = false;

  /// Connects to the session bus, claims the name and exports the object.
  /// Returns true when this instance owns the name; false when another
  /// instance already does (or startup failed). Failures degrade silently —
  /// xdg-open based flows keep working without D-Bus.
  Future<bool> start() async {
    if (_started || !Platform.isLinux) return false;
    _started = true;

    try {
      final DBusClient client = DBusClient.session();
      _client = client;
      // Same ordering as the portal service: object first, name second, so
      // the activation-time introspection always sees the interface.
      await client.registerObject(_FileManager1Object());
      final DBusRequestNameReply reply = await client.requestName(busName);
      return reply == DBusRequestNameReply.primaryOwner;
    } catch (_) {
      _client = null;
      return false;
    }
  }

  /// Disconnects from the session bus (shutdown / tests).
  Future<void> stop() async {
    await _client?.close();
    _client = null;
    _started = false;
  }
}

/// Dispatches the two FileManager1 methods onto the tab controller: every
/// URI opens its own new tab, files additionally get highlighted once their
/// parent listing has loaded.
class _FileManager1Object extends DBusObject {
  _FileManager1Object()
    : super(DBusObjectPath('/org/freedesktop/FileManager1'));

  static const String _interface = 'org.freedesktop.FileManager1';

  @override
  Future<DBusMethodResponse> handleMethodCall(DBusMethodCall call) async {
    if (call.interface != _interface) {
      return DBusMethodErrorResponse.unknownInterface();
    }

    switch (call.name) {
      case 'ShowItems':
        return _handle(call, openFolders: false);
      case 'OpenFolder':
        return _handle(call, openFolders: true);
    }
    return DBusMethodErrorResponse.unknownMethod();
  }

  Future<DBusMethodResponse> _handle(
    DBusMethodCall call, {
    required bool openFolders,
  }) async {
    // Signature of both methods: (as uris, s startup_id). The startup id is
    // only meaningful for window focus stealing, which this app skips.
    final List<String> uris = call.values.isEmpty
        ? const <String>[]
        : call.values.first
              .asArray()
              .map((DBusValue value) => value.asString())
              .toList();

    if (uris.isEmpty || !Get.isRegistered<ExplorerTabsController>()) {
      return DBusMethodSuccessResponse([]);
    }
    final ExplorerTabsController tabs = Get.find<ExplorerTabsController>();
    bool opened = false;

    for (final String uri in uris) {
      String path;
      try {
        path = Uri.parse(uri).toFilePath();
      } on FormatException {
        continue;
      }

      if (!openFolders && File(path).existsSync()) {
        // "Show in folder": open the parent directory, highlight the file.
        final ExplorerTab tab = tabs.addTab(path: File(path).parent.path);
        unawaited(_selectWhenLoaded(tab.controller, path));
        opened = true;
      } else if (Directory(path).existsSync()) {
        tabs.addTab(path: path);
        opened = true;
      }
    }

    // The instance serving this call may be the hidden portal backend;
    // reveal it so the user actually sees the tabs that just opened. Mark
    // the window wanted first — the backend listener re-hides stray
    // mappings and must not swallow this reveal.
    if (opened) {
      if (Get.isRegistered<PortalPickController>()) {
        Get.find<PortalPickController>().markWindowWanted();
      }
      unawaited(windowManager.show());
      unawaited(windowManager.focus());
    }

    return DBusMethodSuccessResponse([]);
  }

  /// Waits for the directory listing to arrive (navigation is async), then
  /// highlights the target entry like a real "reveal" would.
  Future<void> _selectWhenLoaded(
    FileExplorerController controller,
    String path,
  ) async {
    for (int attempt = 0; attempt < 50; attempt++) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
      try {
        final rust.FileEntry entry = controller.entries.firstWhere(
          (rust.FileEntry entry) => entry.path == path,
        );
        controller.selectedPaths
          ..clear()
          ..add(path);
        controller.selection
          ..clear()
          ..add(entry);
        controller.selectionAnchor.value = path;
        return;
      } on StateError {
        // Entry not in the listing yet — keep polling briefly.
      }
    }
  }
}

