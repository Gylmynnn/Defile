import 'package:defile/src/rust/api/system.dart' as rust_system;
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../theme/app_theme.dart';
import '../../controllers/file_explorer_controller.dart';

class AppSidebar extends GetView<FileExplorerController> {
  const AppSidebar({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 178,
      color: AppColors.sidebar,
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
                        icon: Icons.folder,
                        iconColor: AppColors.folder,
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
        return Icons.home_outlined;
      case rust_system.PlaceKind.recent:
        return Icons.schedule;
      case rust_system.PlaceKind.trash:
        return Icons.delete_outline;
      case rust_system.PlaceKind.network:
        return Icons.public;
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
              color: AppColors.folder,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Icon(
              Icons.folder_copy_outlined,
              size: 12,
              color: AppColors.windowDeep,
            ),
          ),
          const SizedBox(width: 9),
          Text(
            'Defile',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
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
              color: AppColors.textFaint,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Divider(height: 1, color: AppColors.divider)),
        ],
      ),
    );
  }
}

class _PlaceTile extends StatefulWidget {
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
  State<_PlaceTile> createState() => _PlaceTileState();
}

class _PlaceTileState extends State<_PlaceTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final bool active = widget.active;

    final Color background = active
        ? AppColors.selection
        : _hovered
        ? AppColors.hover
        : Colors.transparent;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          height: 27,
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(5),
            border: Border.all(
              color: active ? AppColors.selectionBorder : Colors.transparent,
            ),
          ),
          child: Row(
            children: [
              Icon(
                widget.icon,
                size: 14,
                color: active ? AppColors.textPrimary : (widget.iconColor ?? AppColors.textSecondary),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  widget.place.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: active
                        ? AppColors.textPrimary
                        : AppColors.textSecondary,
                    fontWeight: active ? FontWeight.w500 : FontWeight.w400,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DriveTile extends StatefulWidget {
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
  State<_DriveTile> createState() => _DriveTileState();
}

class _DriveTileState extends State<_DriveTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final usage = widget.usage;
    final double? ratio = usage == null || usage.totalBytes == BigInt.zero
        ? null
        : usage.usedBytes.toDouble() / usage.totalBytes.toDouble();

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
          padding: const EdgeInsets.fromLTRB(8, 6, 8, 7),
          decoration: BoxDecoration(
            color: widget.active
                ? AppColors.selection
                : _hovered
                ? AppColors.hover
                : Colors.transparent,
            borderRadius: BorderRadius.circular(5),
            border: Border.all(
              color: widget.active
                  ? AppColors.selectionBorder
                  : Colors.transparent,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.storage,
                    size: 14,
                    color: widget.active
                        ? AppColors.textPrimary
                        : AppColors.textSecondary,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      widget.place.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: widget.active
                            ? AppColors.textPrimary
                            : AppColors.textSecondary,
                        fontWeight: widget.active
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
                  color: usageColor(ratio),
                  backgroundColor: AppColors.chip,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Color usageColor(double? ratio) {
  if (ratio == null) return AppColors.fileDefault;
  if (ratio >= 0.9) return AppColors.danger;
  if (ratio >= 0.75) return AppColors.warning;
  return AppColors.success;
}
