import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../controllers/explorer_tabs_controller.dart';
import '../../controllers/file_explorer_controller.dart';

/// Exposes the [FileExplorerController] of the active tab to the explorer
/// widgets below it.
///
/// Because every tab has its own controller, widgets must resolve it from the
/// widget tree instead of a global GetX key. Overlays (context menus, dialogs)
/// live in the app [Overlay] and are not descendants of this scope, so [of]
/// falls back to the currently active tab for those cases.
class ExplorerScope extends InheritedWidget {
  const ExplorerScope({
    super.key,
    required this.controller,
    required super.child,
  });

  final FileExplorerController controller;

  static FileExplorerController of(BuildContext context) {
    final ExplorerScope? scope = context
        .dependOnInheritedWidgetOfExactType<ExplorerScope>();

    if (scope != null) return scope.controller;

    if (Get.isRegistered<ExplorerTabsController>()) {
      return Get.find<ExplorerTabsController>().activeController;
    }

    return Get.find<FileExplorerController>();
  }

  @override
  bool updateShouldNotify(covariant ExplorerScope oldWidget) =>
      controller != oldWidget.controller;
}
