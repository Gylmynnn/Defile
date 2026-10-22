import 'package:defile/src/rust/api/system.dart' as rust_system;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../theme/app_theme.dart';
import '../../controllers/file_explorer_controller.dart';
import 'hover_region.dart';

class AppSidebar extends GetView<FileExplorerController> {
  const AppSidebar({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 178,
      color: context.colors.sidebar,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SidebarHeader(),
          Expanded(
            child: Obx(() {
              return ListView(
                padding: const EdgeInsets.only(top: 2, bottom: 12),
                children: [
                  for (final place in controller.quickPlaces)
                    _PlaceTile(
                      place: place,
                      icon: _iconFor(place),
                      active: controller.isPlaceActive(place),
                      onTap: () => controller.openPlace(place),
                    ),
                  if (controller.folderPlaces.isNotEmpty) ...[
                    _SidebarGroupLabel('Places'),
                    for (final place in controller.folderPlaces)
                      _PlaceTile(
                        place: place,
                        icon: CupertinoIcons.folder,
                        iconColor: context.colors.folder,
                        active: controller.isPlaceActive(place),
                        onTap: () => controller.openPlace(place),
                      ),
                  ],
                  if (controller.drivePlaces.isNotEmpty) ...[
                    _SidebarGroupLabel('Drives'),
                    for (final place in controller.drivePlaces)
                      _DriveTile(
                        place: place,
                        usage: controller.driveUsages[place.path],
                        active: controller.isPlaceActive(place),
                        onTap: () => controller.openPlace(place),
                      ),
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
    this.iconColor,
  });

  final rust_system.Place place;
  final IconData icon;
  final Color? iconColor;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return HoverRegion(
      builder: (context, hovered) {
        final Color background = active
            ? context.colors.selection
            : hovered
            ? context.colors.hover
            : Colors.transparent;

        return GestureDetector(
          onTap: onTap,
          child: Container(
            height: 27,
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(5),
              border: Border.all(
                color: active
                    ? context.colors.selectionBorder
                    : Colors.transparent,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 14,
                  color: active
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
                      color: active
                          ? context.colors.textPrimary
                          : context.colors.textSecondary,
                      fontWeight: active ? FontWeight.w500 : FontWeight.w400,
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
  });

  final rust_system.Place place;
  final rust_system.DiskUsage? usage;
  final bool active;
  final VoidCallback onTap;

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
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 7),
            decoration: BoxDecoration(
              color: active
                  ? context.colors.selection
                  : hovered
                  ? context.colors.hover
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(5),
              border: Border.all(
                color: active
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
                      color: active
                          ? context.colors.textPrimary
                          : context.colors.textSecondary,
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        place.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: active
                              ? context.colors.textPrimary
                              : context.colors.textSecondary,
                          fontWeight: active
                              ? FontWeight.w500
                              : FontWeight.w400,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: ratio?.clamp(0.0, 1.0) ?? 0,
                    minHeight: 3.5,
                    color: usageColor(ratio, context.colors),
                    backgroundColor: context.colors.chip,
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

Color usageColor(double? ratio, AppThemeColors colors) {
  if (ratio == null) return colors.fileDefault;
  if (ratio >= 0.9) return colors.danger;
  if (ratio >= 0.75) return colors.warning;
  return colors.success;
}
