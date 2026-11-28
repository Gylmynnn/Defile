import 'package:defile/src/rust/api/file_entry.dart' as rust;
import 'package:defile/src/rust/api/system.dart' as rust_system;
import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:get/get.dart';
import 'package:path/path.dart' as p;
import 'package:super_drag_and_drop/super_drag_and_drop.dart';

import '../../../../theme/app_theme.dart';
import '../../controllers/explorer_tabs_controller.dart';
import '../../controllers/file_explorer_controller.dart';
import '../../services/drive_service.dart';
import '../../services/favorites_service.dart';
import '../../services/theme_service.dart';
import '../../utils/app_toast.dart';
import '../../utils/formatters.dart';
import '../../utils/place_icons.dart';
import 'context_menu.dart';
import 'entry_views.dart' show entriesFromLocalData;
import 'explorer_scope.dart';
import 'hover_region.dart';

class AppSidebar extends StatelessWidget {
  const AppSidebar({super.key, this.controller, this.collapsed = false});

  final FileExplorerController? controller;

  /// Icon-rail mode: entries render as bare icons (tooltips carry the
  /// labels) so collapsing the sidebar keeps quick access reachable.
  final bool collapsed;

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

    final List<ContextMenuEntry> entries = <ContextMenuEntry>[
      ContextMenuActionEntry(
        ContextMenuAction(
          icon: Icons.tab,
          label: 'Open in New Tab',
          onSelected: () => _openPlaceInNewTab(place),
        ),
      ),
    ];

    final DriveService? drives = _driveService;
    if (place.kind == rust_system.PlaceKind.drive && drives != null) {
      final bool canUnmount = drives.canUnmount(place.path);
      final bool removable = drives.isRemovable(place.path);

      if (canUnmount || removable) {
        entries.add(ContextMenuSeparator());
      }
      if (canUnmount) {
        entries.add(
          ContextMenuActionEntry(
            ContextMenuAction(
              icon: CupertinoIcons.xmark_circle,
              label: 'Unmount',
              onSelected: () => _runDriveCommand(
                drives.unmount(place.path),
              ),
            ),
          ),
        );
      }
      if (removable) {
        entries.add(
          ContextMenuActionEntry(
            ContextMenuAction(
              icon: CupertinoIcons.eject,
              label: 'Eject',
              onSelected: () => _runDriveCommand(
                drives.eject(place.path),
              ),
            ),
          ),
        );
      }
    }

    showAppContextMenu(
      context: context,
      position: position,
      entries: entries,
    );
  }

  DriveService? get _driveService =>
      Get.isRegistered<DriveService>() ? Get.find<DriveService>() : null;

  Future<void> _runDriveCommand(Future<DriveCommandResult> command) async {
    final DriveCommandResult result = await command;
    showAppToast(
      title: 'Drives',
      message: result.message,
      variant: result.ok ? AppToastVariant.success : AppToastVariant.error,
    );
  }

  // ==========================================
  // Favorites
  // ==========================================

  List<Widget> _favoritesSection(
    BuildContext context,
    FileExplorerController c,
    FavoritesService favorites,
  ) {
    return [
      Obx(() {
        final List<String> paths = favorites.paths.toList(growable: false);

        if (collapsed) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _RailGroupDivider(),
              _FavoritesDropZone(
                onDirectories: (dropped) => _addFavorites(favorites, dropped),
                builder: (context, hovering) => _FavoritesRailHeader(
                  dropping: hovering,
                  empty: paths.isEmpty,
                ),
              ),
              for (final path in paths)
                _favoriteTile(context, c, favorites, path),
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _FavoritesDropZone(
              onDirectories: (dropped) => _addFavorites(favorites, dropped),
              builder: (context, hovering) => _SidebarGroupLabel(
                'Favorites',
                icon: CupertinoIcons.heart_fill,
                dropping: hovering,
              ),
            ),
            // The drop placeholder stays pinned above the pinned folders, so
            // adding another favorite is always one drag away.
            _FavoritesDropZone(
              onDirectories: (dropped) => _addFavorites(favorites, dropped),
              builder: (context, hovering) =>
                  _FavoritesEmptyTile(dropping: hovering),
            ),
            for (final path in paths)
              _favoriteTile(context, c, favorites, path),
          ],
        );
      }),
    ];
  }

  Widget _favoriteTile(
    BuildContext context,
    FileExplorerController c,
    FavoritesService favorites,
    String path,
  ) {
    final rust_system.Place place = rust_system.Place(
      label: _favoriteLabel(path),
      path: path,
      kind: rust_system.PlaceKind.folder,
    );

    Widget tile(bool dropping) => _PlaceTile(
      place: place,
      icon: CupertinoIcons.heart_fill,
      collapsed: collapsed,
      active: c.isPlaceActive(place),
      dropping: dropping,
      onTap: () => c.openPlace(place),
      onMiddleClick: () => _openPlaceInNewTab(place),
      onSecondaryTap: (pos) =>
          _showFavoriteMenu(context, c, place, favorites, pos),
    );

    // Favorites are real directories, so they can also receive file moves.
    return _dropTarget(context, c, path, (dropping) => tile(dropping));
  }

  String _favoriteLabel(String path) {
    final String normalized = p.normalize(path);
    final String base = p.basename(normalized);
    return base.isEmpty ? normalized : base;
  }

  void _showFavoriteMenu(
    BuildContext context,
    FileExplorerController c,
    rust_system.Place place,
    FavoritesService favorites,
    Offset position,
  ) {
    showAppContextMenu(
      context: context,
      position: position,
      entries: [
        ContextMenuActionEntry(
          ContextMenuAction(
            icon: CupertinoIcons.goforward,
            label: 'Open',
            onSelected: () => c.openPlace(place),
          ),
        ),
        ContextMenuActionEntry(
          ContextMenuAction(
            icon: Icons.tab,
            label: 'Open in New Tab',
            onSelected: () => _openPlaceInNewTab(place),
          ),
        ),
        ContextMenuSeparator(),
        ContextMenuActionEntry(
          ContextMenuAction(
            icon: CupertinoIcons.heart_slash,
            label: 'Remove from Favorites',
            onSelected: () => _removeFavorite(favorites, place.path),
          ),
        ),
      ],
    );
  }

  Future<void> _addFavorites(
    FavoritesService favorites,
    List<String> paths,
  ) async {
    final List<String> added = await favorites.addAll(paths);

    if (added.isEmpty) {
      showAppToast(
        title: 'Favorites',
        message: 'Already in Favorites.',
      );
      return;
    }

    showAppToast(
      title: 'Added to Favorites',
      message: added.length == 1
          ? _favoriteLabel(added.first)
          : '${added.length} folders added.',
      variant: AppToastVariant.success,
    );
  }

  Future<void> _removeFavorite(FavoritesService favorites, String path) async {
    await favorites.remove(path);
    showAppToast(
      title: 'Favorites',
      message: '${_favoriteLabel(path)} removed from Favorites.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = _getController(context);
    final FavoritesService? favorites = Get.isRegistered<FavoritesService>()
        ? Get.find<FavoritesService>()
        : null;

    return Obx(() {
      final double width = collapsed
          ? 52
          : (Get.isRegistered<ThemeService>()
                ? Get.find<ThemeService>().sidebarWidth.value
                : ThemeService.defaultSidebarWidth);

      return Container(
        width: width,
        color: context.colors.sidebar,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SidebarHeader(collapsed: collapsed),
            Expanded(
              child: Obx(() {
                return ListView(
                  padding: const EdgeInsets.only(top: 2, bottom: 12),
                  children: [
                    for (final place in c.quickPlaces)
                      _placeTile(context, c, place, icon: placeIcon(place)),
                    if (favorites != null)
                      ..._favoritesSection(context, c, favorites),
                    if (c.folderPlaces.isNotEmpty) ...[
                      if (collapsed)
                        const _RailGroupDivider()
                      else
                        const _SidebarGroupLabel('Places'),
                      for (final place in c.folderPlaces)
                        _placeTile(
                          context,
                          c,
                          place,
                          icon: folderPlaceIcon(place),
                          // iconColor: context.colors.folder,
                        ),
                    ],
                    if (c.drivePlaces.isNotEmpty) ...[
                      if (collapsed)
                        const _RailGroupDivider()
                      else
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
    });
  }

  Widget _placeTile(
    BuildContext context,
    FileExplorerController c,
    rust_system.Place place, {
    required IconData icon,
    Color? iconColor,
  }) {
    // Read the reactive state here, during the enclosing Obx build. The
    // DragTarget builder below runs later with no Obx proxy, so an Rx read
    // inside it would not subscribe the sidebar to changes.
    final bool active = c.isPlaceActive(place);

    Widget tile(bool dropping) => _PlaceTile(
      place: place,
      icon: icon,
      iconColor: iconColor,
      collapsed: collapsed,
      active: active,
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
    // Read the reactive state during the enclosing Obx build. The DragTarget
    // builder below is invoked later, outside the Obx proxy, so reading
    // `driveUsages[...]` (or `isPlaceActive`) inside it would never subscribe
    // the sidebar — the tile would keep showing just the name until some
    // unrelated rebuild.
    final rust_system.DiskUsage? usage = c.driveUsages[place.path];
    final bool active = c.isPlaceActive(place);

    return _dropTarget(
      context,
      c,
      place.path,
      (dropping) => _DriveTile(
        place: place,
        usage: usage,
        collapsed: collapsed,
        active: active,
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
      onAcceptWithDetails: (details) =>
          c.moveEntries(entries: details.data, destinationDirectory: path),
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
  const _SidebarHeader({this.collapsed = false});

  final bool collapsed;

  @override
  Widget build(BuildContext context) {
    // Trimmed logo mark (the raw asset has wide transparent margins around
    // the folder glyph, which renders it near-invisible at header size).
    final Widget logo = SizedBox(
      width: collapsed ? 20 : 24,
      height: collapsed ? 18 : 22,
      child: Image.asset(
        'assets/defile-mark.png',
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
      ),
    );

    if (collapsed) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(11, 12, 11, 12),
        child: Center(child: logo),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      child: Row(
        children: [
          logo,
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

/// Thin separator standing in for a group label while the sidebar is a
/// collapsed icon rail.
class _RailGroupDivider extends StatelessWidget {
  const _RailGroupDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Divider(height: 1, color: context.colors.divider),
    );
  }
}

class _SidebarGroupLabel extends StatelessWidget {
  const _SidebarGroupLabel(
    this.label, {
    this.dropping = false,
    this.icon,
  });

  final String label;
  final bool dropping;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final Color foreground = dropping
        ? context.colors.accent
        : context.colors.textFaint;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 5),
      decoration: dropping
          ? BoxDecoration(
              color: context.colors.selection.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(5),
            )
          : null,
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: foreground),
            const SizedBox(width: 5),
          ],
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              letterSpacing: 0.8,
              fontWeight: FontWeight.w600,
              color: foreground,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Divider(
              height: 1,
              color: dropping ? context.colors.accent : context.colors.divider,
            ),
          ),
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
    this.collapsed = false,
    this.onMiddleClick,
    this.onSecondaryTap,
    this.iconColor,
    this.dropping = false,
  });

  final rust_system.Place place;
  final IconData icon;
  final Color? iconColor;
  final bool collapsed;
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

        Widget tile = GestureDetector(
          onTap: onTap,
          onTertiaryTapUp: (_) => onMiddleClick?.call(),
          onSecondaryTapDown: (details) =>
              onSecondaryTap?.call(details.globalPosition),
          child: Container(
            height: 27,
            margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 1),
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
            child: collapsed
                ? Center(
                    child: Icon(
                      icon,
                      size: 15,
                      color: dropping || active
                          ? context.colors.textPrimary
                          : (iconColor ?? context.colors.textSecondary),
                    ),
                  )
                : Row(
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

        // The rail drops the label, so the tooltip carries it instead.
        if (collapsed) {
          tile = Tooltip(message: place.label, child: tile);
        }
        return tile;
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
    this.collapsed = false,
    this.onMiddleClick,
    this.onSecondaryTap,
    this.dropping = false,
  });

  final rust_system.Place place;
  final rust_system.DiskUsage? usage;
  final bool collapsed;
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
        final Color background = dropping || active
            ? context.colors.selection
            : hovered
            ? context.colors.hover
            : Colors.transparent;

        Widget tile = GestureDetector(
          onTap: onTap,
          onTertiaryTapUp: (_) => onMiddleClick?.call(),
          onSecondaryTapDown: (details) =>
              onSecondaryTap?.call(details.globalPosition),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            padding: const EdgeInsets.fromLTRB(10, 9, 10, 10),
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: dropping || active
                    ? context.colors.selectionBorder
                    : context.colors.divider,
              ),
            ),
            child: collapsed
                ? Center(
                    child: Icon(
                      sidebarDriveIcon,
                      size: 15,
                      color: dropping || active
                          ? context.colors.textPrimary
                          : context.colors.textSecondary,
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              place.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12.5,
                                color: context.colors.textPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (ratio != null)
                            Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: Text(
                                '${(ratio * 100).round()}%',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: context.colors.textSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                        ],
                      ),
                      if (usage != null) ...[
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: ratio,
                            minHeight: 6,
                            backgroundColor: context.colors.divider,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              context.colors.accent,
                            ),
                          ),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          '${formatStorageSize(usage.usedBytes)} of '
                          '${formatStorageSize(usage.totalBytes)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: context.colors.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
          ),
        );

        // The rail drops the label and usage bar; the tooltip carries them.
        if (collapsed) {
          final String usageText = usage == null
              ? ''
              : ' · ${formatStorageSize(usage.usedBytes)} of '
                    '${formatStorageSize(usage.totalBytes)}';
          tile = Tooltip(message: '${place.label}$usageText', child: tile);
        }
        return tile;
      },
    );
  }
}

/// Accepts in-app directory drags aimed at the Favorites group.
///
/// The dragged paths travel in the drag item's local data, so no filesystem
/// probing is needed while hovering. Empty [DropRegion.formats] restricts the
/// zone to sessions started inside this app, matching how entry drops behave.
class _FavoritesDropZone extends StatefulWidget {
  const _FavoritesDropZone({
    required this.onDirectories,
    required this.builder,
  });

  final Future<void> Function(List<String> paths) onDirectories;
  final Widget Function(BuildContext context, bool hovering) builder;

  @override
  State<_FavoritesDropZone> createState() => _FavoritesDropZoneState();
}

class _FavoritesDropZoneState extends State<_FavoritesDropZone> {
  bool _hovering = false;

  List<rust.FileEntry> _directories(DropSession session) {
    final List<String> paths = <String>[];

    for (final item in session.items) {
      final Object? local = item.localData;
      if (local is List) paths.addAll(local.whereType<String>());
    }

    return entriesFromLocalData(
      paths,
    ).where((entry) => entry.isDirectory).toList();
  }

  @override
  Widget build(BuildContext context) {
    return DropRegion(
      formats: const <DataFormat>[],
      hitTestBehavior: HitTestBehavior.opaque,
      onDropOver: (DropOverEvent event) {
        final bool accepts = _directories(event.session).isNotEmpty;
        if (accepts != _hovering) {
          setState(() => _hovering = accepts);
        }
        return accepts ? DropOperation.copy : DropOperation.none;
      },
      onDropLeave: (_) {
        if (_hovering) setState(() => _hovering = false);
      },
      onPerformDrop: (PerformDropEvent event) async {
        if (_hovering) setState(() => _hovering = false);

        final List<String> paths = _directories(
          event.session,
        ).map((entry) => entry.path).toList();
        if (paths.isNotEmpty) await widget.onDirectories(paths);
      },
      child: widget.builder(context, _hovering),
    );
  }
}

/// Placeholder shown while no favorite is pinned; doubles as a drop target.
class _FavoritesEmptyTile extends StatelessWidget {
  const _FavoritesEmptyTile({required this.dropping});

  final bool dropping;

  @override
  Widget build(BuildContext context) {
    final Color foreground = dropping
        ? context.colors.textPrimary
        : context.colors.textFaint;

    return Container(
      height: 27,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: dropping
            ? context.colors.selection
            : context.colors.chip.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(
          color: dropping
              ? context.colors.selectionBorder
              : context.colors.chipBorder,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Drag here',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11.5, color: foreground),
            ),
          ),
        ],
      ),
    );
  }
}

/// Collapsed-sidebar stand-in for the Favorites group label. Keeps a drop
/// target reachable while the rail hides all labels.
class _FavoritesRailHeader extends StatelessWidget {
  const _FavoritesRailHeader({required this.dropping, required this.empty});

  final bool dropping;
  final bool empty;

  @override
  Widget build(BuildContext context) {
    final Color foreground = dropping
        ? context.colors.textPrimary
        : context.colors.textFaint;

    return Tooltip(
      message: empty
          ? 'Favorites — drag folders here'
          : 'Favorites — drop folders here to pin them',
      child: Container(
        height: 27,
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
        decoration: BoxDecoration(
          color: dropping ? context.colors.selection : Colors.transparent,
          borderRadius: BorderRadius.circular(5),
          border: Border.all(
            color: dropping
                ? context.colors.selectionBorder
                : Colors.transparent,
          ),
        ),
        child: Center(
          child: Icon(CupertinoIcons.heart, size: 15, color: foreground),
        ),
      ),
    );
  }
}
