import 'dart:io';

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

  /// Shows the picker for [request], opening its start folder as a new tab.
  void present(PortalPickRequest request) {
    queue.add(request);

    if (request.currentFolder != null &&
        Get.isRegistered<ExplorerTabsController>()) {
      Get.find<ExplorerTabsController>().addTab(path: request.currentFolder!);
    }
    windowManager.setTitle('${request.title} — Defile');
  }

  /// Removes a settled request from the UI and restores the window title.
  void dismiss(PortalPickRequest request) {
    queue.remove(request);
    windowManager.setTitle(
      queue.isEmpty ? 'Defile' : '${queue.last.title} — Defile',
    );
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

  /// Cancels the visible request.
  Future<void> cancelVisible() async {
    final PortalPickRequest? request = visible;
    if (request == null) return;
    await Get.find<PortalFileChooserService>().cancelRequest(request);
  }
}
