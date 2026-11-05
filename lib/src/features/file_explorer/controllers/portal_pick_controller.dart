import 'dart:async';
import 'dart:io';

import 'package:defile/src/rust/api/file_entry.dart' as rust;
import 'package:get/get.dart';
import 'package:path/path.dart' as p;
import 'package:window_manager/window_manager.dart';

import '../services/portal_file_chooser_service.dart';
import '../utils/app_toast.dart';
import 'explorer_tabs_controller.dart';

/// Drives the in-app "portal picker" state: while a portal FileChooser
/// request is pending, the main window doubles as the dialog. The explorer
/// itself is reused for browsing and selecting; this controller only tracks
/// the active request, steers the initial folder and forwards the final
/// selection back to the D-Bus service.
class PortalPickController extends GetxController {
  PortalPickController({this.idleExitAfter});

  /// Dedicated `--dbus-portal` backends auto-exit after this idle time: no
  /// pending request and no revealed window for that long means nothing is
  /// using us, and the next FileChooser call re-activates the process via
  /// D-Bus. GUI instances pass null and never exit on their own.
  final Duration? idleExitAfter;

  /// Requests waiting for an answer, oldest first. The last one is the
  /// one visible in the UI.
  final RxList<PortalPickRequest> queue = <PortalPickRequest>[].obs;

  /// File name typed for the visible SaveFile request. Reset when a
  /// request is presented (prefilled from its suggested name).
  final RxString saveName = ''.obs;

  Timer? _idleExitTimer;

  /// The request whose picker UI is currently shown. Only meaningful when
  /// read inside an Obx that also reads [queue] — it is not reactive
  /// itself, the queue is.
  PortalPickRequest? get visible => queue.isEmpty ? null : queue.last;

  /// Whether this window was revealed by a portal request rather than by a
  /// FileManager1 (xdg-open) reveal: only a portal-revealed picker window
  /// hides itself again once the queue drains — an xdg-open reveal belongs
  /// to the user, not to the dialog.
  bool _revealedByPortal = false;

  /// Whether the window is wanted on screen right now: a pending picker
  /// request or a user-facing FileManager1 reveal. The backend window
  /// listener puts the window back to sleep whenever the GTK embedder
  /// remaps it while this is false (its first frame beats the early
  /// hide() calls depending on boot timing).
  bool _windowWanted = false;

  bool get windowWanted => _windowWanted;

  /// Marks the window as intentionally visible (FileManager1 reveal path).
  void markWindowWanted() => _windowWanted = true;

  /// Marks the window as headless again (picker settled or user closed it).
  void markWindowUnwanted() => _windowWanted = false;

  @override
  void onInit() {
    super.onInit();
    if (idleExitAfter != null) _armIdleExit();
  }

  /// (Re)starts the idle-exit countdown. Called when the backend goes back
  /// to sleep after a request settles, and once at startup so an unused
  /// activated backend does not linger either.
  void _armIdleExit() {
    _idleExitTimer?.cancel();
    _idleExitTimer = Timer(idleExitAfter!, () {
      if (queue.isEmpty && !_windowWanted) exit(0);
    });
  }

  /// Window-side focus return. The backend window is hidden between
  /// requests, so a fresh request re-shows it; some compositors keep the
  /// old focus (or none) on the newly mapped window and the dialog would
  /// ignore both the keyboard and the first click. Re-asserting focus here
  /// makes the picker behave like the real save dialog it stands in for.
  Future<void> _focusWindow() async {
    try {
      if (!await windowManager.isVisible()) await windowManager.show();
      await windowManager.focus();
    } catch (_) {
      // The window may already be gone (backend shutting down).
    }
  }

  /// Shows the picker for [request], opening its start folder as a new tab.
  void present(PortalPickRequest request) {
    _idleExitTimer?.cancel();
    queue.add(request);
    _revealedByPortal = true;
    _windowWanted = true;
    saveName.value = request.suggestedName ?? '';

    if (request.currentFolder != null &&
        Get.isRegistered<ExplorerTabsController>()) {
      request.tabId = Get.find<ExplorerTabsController>()
          .addTab(path: request.currentFolder!)
          .id;
    }
    // Keep the "File Chooser" token stable — the compositor float rule
    // matches on it.
    windowManager.setTitle('${request.title} — File Chooser');
    unawaited(_focusWindow());
  }

  /// Removes a settled request from the UI and restores the window title.
  void dismiss(PortalPickRequest request) {
    queue.remove(request);
    // The tab this request opened must go with it, otherwise every portal
    // use leaves a tab (with its directory listing and thumbnails) behind
    // in the long-lived backend process. When it is the only tab left,
    // closing it is not allowed — that residual tab is small and reused by
    // the next request's navigation.
    final int? tabId = request.tabId;
    request.tabId = null;
    if (tabId != null && Get.isRegistered<ExplorerTabsController>()) {
      final ExplorerTabsController tabs = Get.find<ExplorerTabsController>();
      final int index = tabs.tabs.indexWhere((t) => t.id == tabId);
      if (index >= 0 && tabs.tabs.length > 1) tabs.closeTab(index);
    }
    windowManager.setTitle(
      queue.isEmpty
          ? 'Defile — File Chooser'
          : '${queue.last.title} — File Chooser',
    );
    // Auto-close the dedicated picker window once the last request is
    // settled (confirmed or cancelled). The backend process itself goes
    // into the idle-exit countdown instead of living forever — the next
    // FileChooser call re-activates it via D-Bus.
    if (queue.isEmpty && _revealedByPortal) {
      _revealedByPortal = false;
      _windowWanted = false;
      windowManager.hide();
    }
    if (queue.isEmpty && idleExitAfter != null) {
      saveName.value = '';
      _armIdleExit();
    }
  }

  @override
  void onClose() {
    _idleExitTimer?.cancel();
    super.onClose();
  }

  /// Confirms the visible request with the selection of the focused tab.
  Future<void> confirm() async {
    final PortalPickRequest? request = visible;
    if (request == null) return;

    final List<String> paths = <String>[];
    if (Get.isRegistered<ExplorerTabsController>()) {
      final explorer = Get.find<ExplorerTabsController>().focusedController;

      if (request.saveMode) {
        String currentDir = explorer.currentPath.value;
        if (currentDir.isEmpty || !Directory(currentDir).existsSync()) {
          currentDir = request.currentFolder ?? explorer.homePath.value;
        }
        if (currentDir.isEmpty || !Directory(currentDir).existsSync()) {
          currentDir = Platform.environment['HOME'] ?? '/';
        }

        final String name = saveName.value.trim();
        if (name.isEmpty ||
            name == '.' ||
            name == '..' ||
            name.contains('/') ||
            name.contains('\\')) {
          showAppToast(
            title: request.title,
            message: 'Enter a valid file name first.',
            variant: AppToastVariant.info,
          );
          return;
        }
        final String target = p.join(currentDir, name);
        if (Directory(target).existsSync()) {
          showAppToast(
            title: request.title,
            message: '"$name" is a folder — pick a file name.',
            variant: AppToastVariant.info,
          );
          return;
        }
        paths.add(target);
      } else if (request.isDirectoryMode) {
        final List<String> dirs = explorer.selectedPaths
            .where((String path) => Directory(path).existsSync())
            .toList();
        if (dirs.isNotEmpty) {
          paths.addAll(dirs);
        } else if (Directory(explorer.currentPath.value).existsSync()) {
          paths.add(explorer.currentPath.value);
        } else if (request.currentFolder != null &&
            Directory(request.currentFolder!).existsSync()) {
          paths.add(request.currentFolder!);
        }
      } else {
        paths.addAll(
          explorer.selectedPaths.where(
            (String path) => File(path).existsSync(),
          ),
        );
      }
    }

    if (paths.isEmpty) {
      showAppToast(
        title: request.title,
        message: request.saveMode
            ? 'Choose a save location first.'
            : request.isDirectoryMode
            ? 'Select a folder first.'
            : 'Select a file first.',
        variant: AppToastVariant.info,
      );
      return;
    }

    await Get.find<PortalFileChooserService>().completeRequest(
      request,
      request.multiple ? paths : paths.sublist(0, 1),
    );
  }

  /// Double-click on an entry while a picker is open acts as the dialog's
  /// confirm button: a file confirms an open-file request or a save-as
  /// overwrite. Double-clicking a folder always navigates into it. Returns
  /// false when no picker is active or the entry type does not match the
  /// request, so the caller falls back to normal navigation.
  Future<bool> tryConfirmWithEntry(rust.FileEntry entry) async {
    final PortalPickRequest? request = visible;
    if (request == null) return false;

    final bool isDir = Directory(entry.path).existsSync();
    // Double-clicking a directory should always navigate into it.
    if (isDir) return false;

    // A file cannot confirm a directory-picker request.
    if (request.isDirectoryMode) return false;

    if (request.saveMode) {
      saveName.value = entry.name;
    }

    await Get.find<PortalFileChooserService>().completeRequest(
      request,
      <String>[entry.path],
    );
    return true;
  }

  /// Cancels the visible request.
  Future<void> cancelVisible() async {
    final PortalPickRequest? request = visible;
    if (request == null) return;
    await Get.find<PortalFileChooserService>().cancelRequest(request);
  }
}
