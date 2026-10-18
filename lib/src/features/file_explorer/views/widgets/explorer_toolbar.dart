import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../theme/app_theme.dart';
import '../../controllers/file_explorer_controller.dart';
import 'settings_dialog.dart';

class ExplorerToolbar extends StatefulWidget {
  const ExplorerToolbar({super.key});

  @override
  State<ExplorerToolbar> createState() => _ExplorerToolbarState();
}

class _ExplorerToolbarState extends State<ExplorerToolbar> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  FileExplorerController get controller => Get.find<FileExplorerController>();

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          Obx(
            () => _ToolbarIconButton(
              icon: Icons.chevron_left,
              tooltip: 'Back',
              onTap: controller.pathHistory.isEmpty ? null : controller.goBack,
            ),
          ),
          Obx(
            () => _ToolbarIconButton(
              icon: Icons.chevron_right,
              tooltip: 'Maju',
              onTap: controller.forwardHistory.isEmpty
                  ? null
                  : controller.goForward,
            ),
          ),
          Obx(
            () => _ToolbarIconButton(
              icon: Icons.keyboard_arrow_up,
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
                icon: Icons.search,
                tooltip: 'Search',
                onTap: () {
                  controller.startSearch();
                  _searchFocus.requestFocus();
                },
              );
            }

            return _SearchField(
              controller: _searchController,
              focusNode: _searchFocus,
              onChanged: controller.updateSearch,
              onClose: () {
                _searchController.clear();
                controller.stopSearch();
              },
            );
          }),
          const SizedBox(width: 6),
          Obx(
            () => _ToolbarIconButton(
              icon: controller.showSidebar.value
                  ? Icons.view_sidebar
                  : Icons.view_sidebar_outlined,
              tooltip: controller.showSidebar.value
                  ? 'Hide sidebar'
                  : 'Show sidebar',
              active: controller.showSidebar.value,
              onTap: controller.toggleSidebar,
            ),
          ),
          Obx(
            () => _ToolbarIconButton(
              icon: Icons.terminal,
              tooltip: 'Open terminal in this folder',
              onTap: controller.location.value == ExplorerLocation.directory
                  ? controller.openTerminal
                  : null,
            ),
          ),
          _ToolbarIconButton(
            icon: Icons.settings_outlined,
            tooltip: 'Settings',
            onTap: () => Get.dialog(SettingsDialog()),
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
              color: AppColors.textSecondary,
            ),
            const SizedBox(width: 8),
            Text(
              recent ? 'Recents' : 'Trash',
              style: TextStyle(
                fontSize: 12.5,
                color: AppColors.textPrimary,
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
              Icons.home_outlined,
              size: 14,
              color: AppColors.textSecondary,
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
                color: isLast ? AppColors.textPrimary : AppColors.textSecondary,
              ),
            ),
          ),
        ),
        if (!isLast)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 7),
            child: Text(
              '/',
              style: TextStyle(fontSize: 12, color: AppColors.textFaint),
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
        color: AppColors.window,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.selectionBorder),
      ),
      child: Row(
        children: [
          Icon(Icons.search, size: 13, color: AppColors.textFaint),
          const SizedBox(width: 6),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              autofocus: true,
              onChanged: onChanged,
              cursorHeight: 13,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textPrimary,
              ),
              decoration: InputDecoration(
                isDense: true,
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                hintText: 'Search items...',
                hintStyle: TextStyle(fontSize: 12, color: AppColors.textFaint),
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
                color: AppColors.textSecondary,
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
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _segment(ExplorerViewMode.grid, Icons.grid_view_rounded, 'Grid'),
          _segment(ExplorerViewMode.list, Icons.view_list_rounded, 'Daftar'),
          _segment(ExplorerViewMode.compact, Icons.view_headline, 'Ringkas'),
        ],
      ),
    );
  }

  Widget _segment(ExplorerViewMode value, IconData icon, String tooltip) {
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
              color: active ? AppColors.accent : Colors.transparent,
              borderRadius: BorderRadius.circular(5),
            ),
            child: Icon(
              icon,
              size: 14,
              color: active ? AppColors.windowDeep : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _ToolbarIconButton extends StatefulWidget {
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
  State<_ToolbarIconButton> createState() => _ToolbarIconButtonState();
}

class _ToolbarIconButtonState extends State<_ToolbarIconButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final bool enabled = widget.onTap != null;

    final Color background = widget.active
        ? AppColors.selection
        : _hovered && enabled
        ? AppColors.hover
        : Colors.transparent;

    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: Container(
            width: 27,
            height: 26,
            margin: const EdgeInsets.symmetric(horizontal: 1),
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(5),
            ),
            child: Icon(
              widget.icon,
              size: 17,
              color: !enabled
                  ? AppColors.textFaint.withValues(alpha: 0.45)
                  : widget.active
                  ? AppColors.textPrimary
                  : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
