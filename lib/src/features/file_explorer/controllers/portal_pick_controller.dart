import 'dart:io';

import 'package:defile/src/rust/api/file_entry.dart' as rust;
import 'package:get/get.dart';
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
  /// Requests waiting for an answer, oldest first. The last one is the
  /// one visible in the UI.
  final RxList<PortalPickRequest> queue = <PortalPickRequest>[].obs;

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

  /// Shows the picker for [request], opening its start folder as a new tab.
  void present(PortalPickRequest request) {
    queue.add(request);
    _revealedByPortal = true;
    _windowWanted = true;

    if (request.currentFolder != null &&
        Get.isRegistered<ExplorerTabsController>()) {
      Get.find<ExplorerTabsController>().addTab(path: request.currentFolder!);
    }
    // Keep the "File Chooser" token stable — the compositor float rule
    // matches on it.
    windowManager.setTitle('${request.title} — File Chooser');
  }

  /// Removes a settled request from the UI and restores the window title.
  void dismiss(PortalPickRequest request) {
    queue.remove(request);
    windowManager.setTitle(
      queue.isEmpty
          ? 'Defile — File Chooser'
          : '${queue.last.title} — File Chooser',
    );
    // Auto-close the dedicated picker window once the last request is
    // settled (confirmed or cancelled); the backend process itself stays
    // alive for the next one.
    if (queue.isEmpty && _revealedByPortal) {
      _revealedByPortal = false;
      _windowWanted = false;
      windowManager.hide();
    }
  }

  /// Confirms the visible request with the selection of the focused tab.
  Future<void> confirm() async {
    final PortalPickRequest? request = visible;
    if (request == null) return;

    final List<String> paths = <String>[];
    if (Get.isRegistered<ExplorerTabsController>()) {
      final explorer = Get.find<ExplorerTabsController>().focusedController;

      if (request.isDirectoryMode) {
        final List<String> dirs = explorer.selectedPaths
            .where((String path) => Directory(path).existsSync())
            .toList();
        if (dirs.isNotEmpty) {
          paths.addAll(dirs);
        } else if (Directory(explorer.currentPath.value).existsSync()) {
          paths.add(explorer.currentPath.value);
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
        message: request.isDirectoryMode
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
  /// confirm button: a file confirms an open-file request, a folder
  /// confirms a choose-folder request. Returns false when no picker is
  /// active or the entry type does not match the request, so the caller
  /// falls back to normal navigation.
  Future<bool> tryConfirmWithEntry(rust.FileEntry entry) async {
    final PortalPickRequest? request = visible;
    if (request == null) return false;

    final bool isDir = Directory(entry.path).existsSync();
    if (request.isDirectoryMode != isDir) return false;

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
