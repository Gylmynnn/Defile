import 'package:defile/src/rust/api/file_entry.dart' as rust;
import 'package:defile/src/rust/api/system.dart' as rust_system;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../theme/app_theme.dart';
import '../../controllers/explorer_tabs_controller.dart';
import '../../controllers/file_explorer_controller.dart';
import 'context_menu.dart';
import 'explorer_scope.dart';
import 'hover_region.dart';

class AppSidebar extends StatelessWidget {
  const AppSidebar({super.key, this.controller});

  final FileExplorerController? controller;

  FileExplorerController _getController(BuildContext context) =>
      controller ?? ExplorerScope.of(context);

  void _openPlaceInNewTab(rust_system.Place place) {
    if (Get.isRegistered<ExplorerTabsController>()) {
      final tabs = Get.find<ExplorerTabsController>();
      if (place.kind == rust_system.PlaceKind.recent) {
        tabs.addTab(location: ExplorerLocation.recent);
      } else if (place.kind == rust_system.PlaceKind.trash) {
        tabs.addTab(location: ExplorerLocation.trash);
      } else if (place.path.isNotEmpty) {
        tabs.addTab(path: place.path);
      }
    }
  }

  void _showPlaceMenu(
    BuildContext context,
    rust_system.Place place,
    Offset position,
  ) {
    if (place.kind == rust_system.PlaceKind.network) return;

    showAppContextMenu(
      context: context,
      position: position,
      entries: [
        ContextMenuActionEntry(
          ContextMenuAction(
            icon: Icons.tab,
            label: 'Open in New Tab',
            onSelected: () => _openPlaceInNewTab(place),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = _getController(context);

    return Container(
      width: 178,
      color: context.colors.sidebar,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _SidebarHeader(),
          Expanded(
            child: Obx(() {
              return ListView(
                padding: const EdgeInsets.only(top: 2, bottom: 12),
                children: [
                  for (final place in c.quickPlaces)
                    _placeTile(context, c, place, icon: _iconFor(place)),
                  if (c.folderPlaces.isNotEmpty) ...[
                    const _SidebarGroupLabel('Places'),
                    for (final place in c.folderPlaces)
                      _placeTile(
                        context,
                        c,
                        place,
                        icon: CupertinoIcons.folder,
                        iconColor: context.colors.folder,
                      ),
                  ],
                  if (c.drivePlaces.isNotEmpty) ...[
                    const _SidebarGroupLabel('Drives'),
                    for (final place in c.drivePlaces)
                      _driveTile(context, c, place),
                  ],
                ],
              );
            }),
          ),
        ],
      ),
    );
  }

  IconData _iconFor(rust_system.Place place) {
    switch (place.kind) {
      case rust_system.PlaceKind.home:
        return CupertinoIcons.home;
      case rust_system.PlaceKind.recent:
        return CupertinoIcons.time;
      case rust_system.PlaceKind.trash:
        return CupertinoIcons.trash;
      case rust_system.PlaceKind.network:
        return CupertinoIcons.wifi;
      case rust_system.PlaceKind.folder:
        return Icons.folder;
      case rust_system.PlaceKind.drive:
        return Icons.storage;
    }
  }

  Widget _placeTile(
    BuildContext context,
    FileExplorerController c,
    rust_system.Place place, {
    required IconData icon,
    Color? iconColor,
  }) {
    Widget tile(bool dropping) => _PlaceTile(
      place: place,
      icon: icon,
      iconColor: iconColor,
      active: c.isPlaceActive(place),
      dropping: dropping,
      onTap: () => c.openPlace(place),
      onMiddleClick: () => _openPlaceInNewTab(place),
      onSecondaryTap: (pos) => _showPlaceMenu(context, place, pos),
    );

    if (!_acceptsDrop(place)) return tile(false);

    return _dropTarget(context, c, place.path, (dropping) => tile(dropping));
  }

  Widget _driveTile(
    BuildContext context,
    FileExplorerController c,
    rust_system.Place place,
  ) {
    return _dropTarget(
      context,
      c,
      place.path,
      (dropping) => _DriveTile(
        place: place,
        usage: c.driveUsages[place.path],
        active: c.isPlaceActive(place),
        dropping: dropping,
        onTap: () => c.openPlace(place),
        onMiddleClick: () => _openPlaceInNewTab(place),
        onSecondaryTap: (pos) => _showPlaceMenu(context, place, pos),
      ),
    );
  }

  bool _acceptsDrop(rust_system.Place place) {
    return place.kind == rust_system.PlaceKind.home ||
        place.kind == rust_system.PlaceKind.folder ||
        place.kind == rust_system.PlaceKind.drive;
  }

  Widget _dropTarget(
    BuildContext context,
    FileExplorerController c,
    String path,
    Widget Function(bool dropping) builder,
  ) {
    return DragTarget<List<rust.FileEntry>>(
      onWillAcceptWithDetails: (details) =>
          c.canDropEntries(details.data, path),
      onAcceptWithDetails: (details) => c.moveEntries(
        entries: details.data,
        destinationDirectory: path,
      ),
      builder: (context, candidateData, rejectedData) {
        final bool dropping = candidateData.any(
          (data) => data != null && c.canDropEntries(data, path),
        );

        return builder(dropping);
      },
    );
  }
}

class _SidebarHeader extends StatelessWidget {
  const _SidebarHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      child: Row(
        children: [
          Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              color: context.colors.folder,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Icon(
              Icons.folder_copy_outlined,
              size: 12,
              color: context.colors.windowDeep,
            ),
          ),
          const SizedBox(width: 9),
          Text(
            'Defile',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: context.colors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarGroupLabel extends StatelessWidget {
  const _SidebarGroupLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 5),
      child: Row(
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              letterSpacing: 0.8,
              fontWeight: FontWeight.w600,
              color: context.colors.textFaint,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Divider(height: 1, color: context.colors.divider)),
        ],
      ),
    );
  }
}

class _PlaceTile extends StatelessWidget {
  const _PlaceTile({
    required this.place,
    required this.icon,
    required this.active,
    required this.onTap,
    this.onMiddleClick,
    this.onSecondaryTap,
    this.iconColor,
    this.dropping = false,
  });

  final rust_system.Place place;
  final IconData icon;
  final Color? iconColor;
  final bool active;
  final bool dropping;
  final VoidCallback onTap;
  final VoidCallback? onMiddleClick;
  final void Function(Offset position)? onSecondaryTap;

  @override
  Widget build(BuildContext context) {
    return HoverRegion(
      builder: (context, hovered) {
        final Color background = dropping || active
            ? context.colors.selection
            : hovered
            ? context.colors.hover
            : Colors.transparent;

        return GestureDetector(
          onTap: onTap,
          onTertiaryTapUp: (_) => onMiddleClick?.call(),
          onSecondaryTapDown: (details) =>
              onSecondaryTap?.call(details.globalPosition),
          child: Container(
            height: 27,
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(5),
              border: Border.all(
                color: dropping || active
                    ? context.colors.selectionBorder
                    : Colors.transparent,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 14,
                  color: dropping || active
                      ? context.colors.textPrimary
                      : (iconColor ?? context.colors.textSecondary),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    place.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: dropping || active
                          ? context.colors.textPrimary
                          : context.colors.textSecondary,
                      fontWeight: dropping || active
                          ? FontWeight.w500
                          : FontWeight.w400,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _DriveTile extends StatelessWidget {
  const _DriveTile({
    required this.place,
    required this.usage,
    required this.active,
    required this.onTap,
    this.onMiddleClick,
    this.onSecondaryTap,
    this.dropping = false,
  });

  final rust_system.Place place;
  final rust_system.DiskUsage? usage;
  final bool active;
  final bool dropping;
  final VoidCallback onTap;
  final VoidCallback? onMiddleClick;
  final void Function(Offset position)? onSecondaryTap;

  @override
  Widget build(BuildContext context) {
    final rust_system.DiskUsage? usage = this.usage;
    final double? ratio = usage == null || usage.totalBytes == BigInt.zero
        ? null
        : usage.usedBytes.toDouble() / usage.totalBytes.toDouble();

    return HoverRegion(
      builder: (context, hovered) {
        return GestureDetector(
          onTap: onTap,
          onTertiaryTapUp: (_) => onMiddleClick?.call(),
          onSecondaryTapDown: (details) =>
              onSecondaryTap?.call(details.globalPosition),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 7),
            decoration: BoxDecoration(
              color: dropping || active
                  ? context.colors.selection
                  : hovered
                  ? context.colors.hover
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(5),
              border: Border.all(
                color: dropping || active
                    ? context.colors.selectionBorder
                    : Colors.transparent,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      CupertinoIcons.device_desktop,
                      size: 14,
                      color: dropping || active
                          ? context.colors.textPrimary
                          : context.colors.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        place.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: dropping || active
                              ? context.colors.textPrimary
                              : context.colors.textSecondary,
                          fontWeight: dropping || active
                              ? FontWeight.w500
                              : FontWeight.w400,
                        ),
                      ),
                    ),
                  ],
                ),
                if (ratio != null) ...[
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: ratio,
                      minHeight: 3,
                      backgroundColor: context.colors.divider,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        context.colors.accent,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
