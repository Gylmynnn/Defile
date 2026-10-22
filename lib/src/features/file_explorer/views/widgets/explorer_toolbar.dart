import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../theme/app_theme.dart';
import '../../controllers/file_explorer_controller.dart';
import '../../services/theme_service.dart';
import '../../utils/app_dialog_route.dart';
import 'hover_region.dart';
import 'settings_dialog.dart';

class ExplorerToolbar extends StatefulWidget {
  const ExplorerToolbar({super.key});

  @override
  State<ExplorerToolbar> createState() => _ExplorerToolbarState();
}

class _ExplorerToolbarState extends State<ExplorerToolbar> {
  final TextEditingController _searchController = TextEditingController();

  FileExplorerController get controller => Get.find<FileExplorerController>();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: context.colors.surface,
        border: Border(bottom: BorderSide(color: context.colors.divider)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          Obx(
            () => _ToolbarIconButton(
              icon: controller.showSidebar.value
                  ? CupertinoIcons.sidebar_right
                  : CupertinoIcons.sidebar_left,
              tooltip: controller.showSidebar.value
                  ? 'Hide sidebar'
                  : 'Show sidebar',
              active: controller.showSidebar.value,
              onTap: controller.toggleSidebar,
            ),
          ),
          Obx(
            () => _ToolbarIconButton(
              icon: CupertinoIcons.arrow_left,
              tooltip: 'Back',
              onTap: controller.pathHistory.isEmpty ? null : controller.goBack,
            ),
          ),
          Obx(
            () => _ToolbarIconButton(
              icon: CupertinoIcons.arrow_right,
              tooltip: 'Forward',
              onTap: controller.forwardHistory.isEmpty
                  ? null
                  : controller.goForward,
            ),
          ),
          Obx(
            () => _ToolbarIconButton(
              icon: CupertinoIcons.arrow_turn_left_up,
              tooltip: 'Parent folder',
              onTap: controller.canGoToParent ? controller.goToParent : null,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(child: _buildLocation()),
          const SizedBox(width: 6),
          Obx(
            () => _ViewModeSwitch(
              mode: controller.viewMode.value,
              onChanged: controller.setViewMode,
            ),
          ),
          const SizedBox(width: 6),
          Obx(() {
            if (!controller.isSearching.value) {
              return _ToolbarIconButton(
                icon: CupertinoIcons.search,
                tooltip: 'Search',
                onTap: () {
                  controller.startSearch();
                  controller.searchFocusNode.requestFocus();
                },
              );
            }

            return _SearchField(
              controller: _searchController,
              focusNode: controller.searchFocusNode,
              onChanged: controller.updateSearch,
              onClose: () {
                _searchController.clear();
                controller.stopSearch();
              },
            );
          }),
          // const SizedBox(width: 6),
          // Obx(
          //   () => _ToolbarIconButton(
          //     icon: Icons.terminal,
          //     tooltip: 'Open terminal in this folder',
          //     onTap: controller.location.value == ExplorerLocation.directory
          //         ? controller.openTerminal
          //         : null,
          //   ),
          // ),
          Obx(() {
            final themeService = Get.find<ThemeService>();
            return _ToolbarIconButton(
              icon: themeService.previewEnabled.value
                  ? CupertinoIcons.eye_solid
                  : CupertinoIcons.eye,
              tooltip: themeService.previewEnabled.value
                  ? 'Hide preview'
                  : 'Show preview',
              active: themeService.previewEnabled.value,
              onTap: () => themeService.previewEnabled.value =
                  !themeService.previewEnabled.value,
            );
          }),
          _ToolbarIconButton(
            icon: Icons.settings_outlined,
            tooltip: 'Settings',
            onTap: () => showAppDialog(builder: (BuildContext _) => const SettingsDialog()),
          ),
        ],
      ),
    );
  }

  Widget _buildLocation() {
    return Obx(() {
      if (controller.location.value != ExplorerLocation.directory) {
        final bool recent =
            controller.location.value == ExplorerLocation.recent;

        return Row(
          children: [
            Icon(
              recent ? Icons.schedule : Icons.delete_outline,
              size: 14,
              color: context.colors.textSecondary,
            ),
            const SizedBox(width: 8),
            Text(
              recent ? 'Recents' : 'Trash',
              style: TextStyle(
                fontSize: 12.5,
                color: context.colors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        );
      }

      final List<String> breadcrumbs = controller.breadcrumbs;

      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (int index = 0; index < breadcrumbs.length; index++)
              _Breadcrumb(
                label: controller.crumbLabel(breadcrumbs[index]),
                isHome: breadcrumbs[index] == controller.homePath.value,
                isLast: index == breadcrumbs.length - 1,
                onTap: () => controller.navigateTo(breadcrumbs[index]),
              ),
          ],
        ),
      );
    });
  }
}

class _Breadcrumb extends StatelessWidget {
  const _Breadcrumb({
    required this.label,
    required this.isHome,
    required this.isLast,
    required this.onTap,
  });

  final String label;
  final bool isHome;
  final bool isLast;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isHome)
          Padding(
            padding: EdgeInsets.only(right: 6),
            child: Icon(
              CupertinoIcons.home,
              size: 14,
              color: context.colors.textSecondary,
            ),
          ),
        MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: isLast ? null : onTap,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                color: isLast
                    ? context.colors.textPrimary
                    : context.colors.textSecondary,
              ),
            ),
          ),
        ),
        if (!isLast)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 7),
            child: Text(
              '/',
              style: TextStyle(fontSize: 12, color: context.colors.textFaint),
            ),
          ),
      ],
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onClose,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 190,
      height: 26,
      padding: const EdgeInsets.only(left: 8, right: 4),
      decoration: BoxDecoration(
        color: context.colors.window,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: context.colors.selectionBorder),
      ),
      child: Row(
        children: [
          Icon(Icons.search, size: 13, color: context.colors.textFaint),
          const SizedBox(width: 6),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              autofocus: true,
              onChanged: onChanged,
              cursorHeight: 13,
              style: TextStyle(fontSize: 12, color: context.colors.textPrimary),
              decoration: InputDecoration(
                isDense: true,
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                hintText: 'Search items...',
                hintStyle: TextStyle(
                  fontSize: 12,
                  color: context.colors.textFaint,
                ),
              ),
            ),
          ),
          InkWell(
            onTap: onClose,
            borderRadius: BorderRadius.circular(4),
            child: Padding(
              padding: EdgeInsets.all(3),
              child: Icon(
                Icons.close,
                size: 13,
                color: context.colors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ViewModeSwitch extends StatelessWidget {
  const _ViewModeSwitch({required this.mode, required this.onChanged});

  final ExplorerViewMode mode;
  final ValueChanged<ExplorerViewMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: context.colors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _segment(
            context,
            ExplorerViewMode.grid,
            CupertinoIcons.rectangle_grid_3x2_fill,
            'Grid',
          ),
          _segment(
            context,
            ExplorerViewMode.list,
            CupertinoIcons.list_number,
            'List',
          ),
          _segment(
            context,
            ExplorerViewMode.compact,
            CupertinoIcons.rectangle_grid_1x2_fill,
            'Compact',
          ),
        ],
      ),
    );
  }

  Widget _segment(
    BuildContext context,
    ExplorerViewMode value,
    IconData icon,
    String tooltip,
  ) {
    final bool active = mode == value;

    return Tooltip(
      message: tooltip,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () => onChanged(value),
          child: Container(
            width: 27,
            height: 23,
            decoration: BoxDecoration(
              color: active ? context.colors.accent : Colors.transparent,
              borderRadius: BorderRadius.circular(5),
            ),
            child: Icon(
              icon,
              size: 14,
              color: active
                  ? context.colors.accentContent
                  : context.colors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _ToolbarIconButton extends StatelessWidget {
  const _ToolbarIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.active = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final bool enabled = onTap != null;

    return Tooltip(
      message: tooltip,
      child: HoverRegion(
        cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        builder: (context, hovered) {
          final Color background = active
              ? context.colors.selection
              : hovered && enabled
              ? context.colors.hover
              : Colors.transparent;

          return GestureDetector(
            onTap: onTap,
            child: Container(
              width: 27,
              height: 26,
              margin: const EdgeInsets.symmetric(horizontal: 1),
              decoration: BoxDecoration(
                color: background,
                borderRadius: BorderRadius.circular(5),
              ),
              child: Icon(
                icon,
                size: 17,
                color: !enabled
                    ? context.colors.textFaint.withValues(alpha: 0.45)
                    : active
                    ? context.colors.textPrimary
                    : context.colors.textSecondary,
              ),
            ),
          );
        },
      ),
    );
  }
}
