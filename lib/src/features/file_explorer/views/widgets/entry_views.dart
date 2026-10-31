import 'dart:io';

import 'package:defile/src/rust/api/file_entry.dart' as rust;
import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:path/path.dart' as p;
import 'package:super_clipboard/super_clipboard.dart'
    show SimplePlatformCodec, SimpleValueFormat;
import 'package:super_drag_and_drop/super_drag_and_drop.dart';

import '../../../../theme/app_theme.dart';
import '../../services/theme_service.dart';
import '../../utils/file_types.dart';
import '../../utils/formatters.dart';
import 'entry_glyphs.dart';
import 'hover_region.dart';
import 'image_thumbnail.dart';
import 'themed_icon.dart';

typedef EntryOpenCallback = void Function(rust.FileEntry entry);
typedef EntryMenuCallback = void Function(
  rust.FileEntry entry,
  Offset position,
);
typedef EntryDragEntriesCallback = List<rust.FileEntry> Function(
  rust.FileEntry entry,
);
typedef EntryCanDropCallback = bool Function(
  List<rust.FileEntry> entries,
  String destinationDirectory,
);
typedef EntryDropCallback = void Function(
  List<rust.FileEntry> entries,
  String destinationDirectory,
);

final Map<String, GlobalKey> _entryKeys = <String, GlobalKey>{};

// ponytail: keys cached per path to avoid re-allocating a GlobalKey on every
// tile build. Never pruned; harmless for typical sessions. Add pruning keyed on
// the live entry set if enormous unique trees get visited.
//
// The optional [owner] (the pane's controller) namespaces the keys because
// split view can show the very same file in two panes at once, and a GlobalKey
// must never appear on two widgets simultaneously.
GlobalKey entryTileKey(String path, {Object? owner}) => _entryKeys.putIfAbsent(
  '${identityHashCode(owner)}\u001f$path',
  GlobalKey.new,
);

Duration get _selectionAnimationDuration {
  if (!Get.isRegistered<ThemeService>()) {
    return const Duration(milliseconds: 120);
  }
  return Get.find<ThemeService>().animationsEnabled.value
      ? const Duration(milliseconds: 120)
      : Duration.zero;
}

class EntryGridView extends StatelessWidget {
  const EntryGridView({
    super.key,
    required this.entries,
    required this.selectedPaths,
    required this.onPress,
    required this.onTap,
    required this.onOpen,
    required this.onMenu,
    this.onMiddleClick,
    this.dragEntries,
    this.canDrop,
    this.onDrop,
    this.paneOwner,
  });

  final List<rust.FileEntry> entries;
  final RxSet<String> selectedPaths;
  final EntryOpenCallback onPress;
  final EntryOpenCallback onTap;
  final EntryOpenCallback onOpen;
  final EntryMenuCallback onMenu;
  final EntryOpenCallback? onMiddleClick;
  final EntryDragEntriesCallback? dragEntries;
  final EntryCanDropCallback? canDrop;
  final EntryDropCallback? onDrop;
  final Object? paneOwner;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 132,
        mainAxisExtent: 104,
        crossAxisSpacing: 6,
        mainAxisSpacing: 10,
      ),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];

        return _EntryDragWrapper(
          entry: entry,
          dragEntries: dragEntries,
          canDrop: canDrop,
          onDrop: onDrop,
          child: _GridTile(
            entry: entry,
            selectedPaths: selectedPaths,
            onPress: () => onPress(entry),
            onTap: () => onTap(entry),
            onOpen: () => onOpen(entry),
            onMenu: (position) => onMenu(entry, position),
            onMiddleClick: onMiddleClick == null
                ? null
                : () => onMiddleClick!(entry),
            paneOwner: paneOwner,
          ),
        );
      },
    );
  }
}

class _GridTile extends StatelessWidget {
  const _GridTile({
    required this.entry,
    required this.selectedPaths,
    required this.onPress,
    required this.onTap,
    required this.onOpen,
    required this.onMenu,
    this.onMiddleClick,
    this.paneOwner,
  });

  final rust.FileEntry entry;
  final RxSet<String> selectedPaths;
  final VoidCallback onPress;
  final VoidCallback onTap;
  final VoidCallback onOpen;
  final ValueChanged<Offset> onMenu;
  final VoidCallback? onMiddleClick;
  final Object? paneOwner;

  @override
  Widget build(BuildContext context) {
    final Widget content = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          height: 62,
          child: Center(child: _EntryGlyph(entry: entry)),
        ),
        const SizedBox(height: 6),
        Text(
          entry.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11.5,
            color: context.colors.textPrimary,
            height: 1.2,
          ),
        ),
      ],
    );

    return HoverRegion(
      key: entryTileKey(entry.path, owner: paneOwner),
      builder: (context, hovered) {
        // A slow frame can stretch a plain left-click past the long-press
        // deadline; hold-to-menu is meant for touch/stylus only, so remember
        // which kind of pointer went down and ignore mouse long-presses.
        PointerDeviceKind? pressKind;
        return Listener(
          onPointerDown: (event) {
            pressKind = event.kind;
            if (event.buttons == kPrimaryButton) onPress();
          },
          child: GestureDetector(
            onTap: onTap,
            onDoubleTap: onOpen,
            onTertiaryTapUp: (_) => onMiddleClick?.call(),
            onSecondaryTapDown: (details) => onMenu(details.globalPosition),
            onLongPressStart: (details) {
              if (pressKind == PointerDeviceKind.mouse) return;
              onMenu(details.globalPosition);
            },
            child: Obx(() {
              final bool selected = selectedPaths.contains(entry.path);

              return AnimatedContainer(
                duration: _selectionAnimationDuration,
                curve: Curves.easeOut,
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                decoration: BoxDecoration(
                  color: selected
                      ? context.colors.selection
                      : hovered
                      ? context.colors.hover
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(
                    color: selected
                        ? context.colors.selectionBorder
                        : hovered
                        ? context.colors.border
                        : Colors.transparent,
                  ),
                ),
                child: content,
              );
            }),
          ),
        );
      },
    );
  }
}

class EntryListView extends StatelessWidget {
  const EntryListView({
    super.key,
    required this.entries,
    required this.selectedPaths,
    required this.onPress,
    required this.onTap,
    required this.onOpen,
    required this.onMenu,
    this.onMiddleClick,
    this.dragEntries,
    this.canDrop,
    this.onDrop,
    this.paneOwner,
  });

  final List<rust.FileEntry> entries;
  final RxSet<String> selectedPaths;
  final EntryOpenCallback onPress;
  final EntryOpenCallback onTap;
  final EntryOpenCallback onOpen;
  final EntryMenuCallback onMenu;
  final EntryOpenCallback? onMiddleClick;
  final EntryDragEntriesCallback? dragEntries;
  final EntryCanDropCallback? canDrop;
  final EntryDropCallback? onDrop;
  final Object? paneOwner;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: 28,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: context.colors.divider)),
          ),
          child: Row(
            children: [
              SizedBox(width: 24),
              Expanded(child: Text('Name', style: _headerStyle(context))),
              SizedBox(
                width: 92,
                child: Text('Size', style: _headerStyle(context)),
              ),
              SizedBox(
                width: 158,
                child: Text('Modified', style: _headerStyle(context)),
              ),
              SizedBox(
                width: 64,
                child: Text('Type', style: _headerStyle(context)),
              ),
              SizedBox(width: 30),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 4),
            itemCount: entries.length,
            itemBuilder: (context, index) {
              final entry = entries[index];

              return _EntryDragWrapper(
                entry: entry,
                dragEntries: dragEntries,
                canDrop: canDrop,
                onDrop: onDrop,
                child: _ListRow(
                  entry: entry,
                  selectedPaths: selectedPaths,
                  onPress: () => onPress(entry),
                  onTap: () => onTap(entry),
                  onOpen: () => onOpen(entry),
                  onMenu: (position) => onMenu(entry, position),
                  onMiddleClick: onMiddleClick == null
                      ? null
                      : () => onMiddleClick!(entry),
                  paneOwner: paneOwner,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

TextStyle _headerStyle(BuildContext context) => TextStyle(
  fontSize: 11.5,
  fontWeight: FontWeight.w600,
  color: context.colors.textFaint,
);

class _ListRow extends StatelessWidget {
  const _ListRow({
    required this.entry,
    required this.selectedPaths,
    required this.onPress,
    required this.onTap,
    required this.onOpen,
    required this.onMenu,
    this.onMiddleClick,
    this.paneOwner,
  });

  final rust.FileEntry entry;
  final RxSet<String> selectedPaths;
  final VoidCallback onPress;
  final VoidCallback onTap;
  final VoidCallback onOpen;
  final ValueChanged<Offset> onMenu;
  final VoidCallback? onMiddleClick;
  final Object? paneOwner;

  @override
  Widget build(BuildContext context) {
    return HoverRegion(
      key: entryTileKey(entry.path, owner: paneOwner),
      builder: (context, hovered) {
        final Widget content = Row(
          children: [
            SizedBox(width: 24, child: _EntryMiniIcon(entry: entry)),
            Expanded(
              child: Text(
                entry.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  color: context.colors.textPrimary,
                ),
              ),
            ),
            SizedBox(
              width: 92,
              child: Text(
                entry.isFile ? formatBytes(entry.sizeBytes) : '—',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11.5,
                  color: context.colors.textSecondary,
                ),
              ),
            ),
            SizedBox(
              width: 158,
              child: Text(
                formatDate(entry.modifiedSeconds.toInt()),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11.5,
                  color: context.colors.textSecondary,
                ),
              ),
            ),
            SizedBox(
              width: 64,
              child: Text(
                entry.isDirectory ? 'Folder' : fileTypeShortLabel(entry.name),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11.5,
                  color: context.colors.textSecondary,
                ),
              ),
            ),
            SizedBox(
              width: 26,
              child: hovered
                  ? InkWell(
                      onTap: () {
                        final RenderBox box =
                            context.findRenderObject()! as RenderBox;
                        onMenu(box.localToGlobal(box.size.center(Offset.zero)));
                      },
                      borderRadius: BorderRadius.circular(4),
                      child: Icon(
                        Icons.more_horiz,
                        size: 16,
                        color: context.colors.textSecondary,
                      ),
                    )
                  : null,
            ),
          ],
        );

        return Listener(
          onPointerDown: (event) {
            if (event.buttons == kPrimaryButton) onPress();
          },
          child: GestureDetector(
            onTap: onTap,
            onDoubleTap: onOpen,
            onTertiaryTapUp: (_) => onMiddleClick?.call(),
            onSecondaryTapDown: (details) => onMenu(details.globalPosition),
            child: Obx(() {
              final bool selected = selectedPaths.contains(entry.path);

              return AnimatedContainer(
                duration: _selectionAnimationDuration,
                curve: Curves.easeOut,
                height: 29,
                margin: const EdgeInsets.symmetric(horizontal: 8),
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: selected
                      ? context.colors.selection
                      : hovered
                      ? context.colors.hover
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(
                    color: selected
                        ? context.colors.selectionBorder
                        : Colors.transparent,
                  ),
                ),
                child: content,
              );
            }),
          ),
        );
      },
    );
  }
}

class EntryCompactView extends StatelessWidget {
  const EntryCompactView({
    super.key,
    required this.entries,
    required this.selectedPaths,
    required this.onPress,
    required this.onTap,
    required this.onOpen,
    required this.onMenu,
    this.onMiddleClick,
    this.dragEntries,
    this.canDrop,
    this.onDrop,
    this.paneOwner,
  });

  final List<rust.FileEntry> entries;
  final RxSet<String> selectedPaths;
  final EntryOpenCallback onPress;
  final EntryOpenCallback onTap;
  final EntryOpenCallback onOpen;
  final EntryMenuCallback onMenu;
  final EntryOpenCallback? onMiddleClick;
  final EntryDragEntriesCallback? dragEntries;
  final EntryCanDropCallback? canDrop;
  final EntryDropCallback? onDrop;
  final Object? paneOwner;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 3),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];

        return _EntryDragWrapper(
          entry: entry,
          dragEntries: dragEntries,
          canDrop: canDrop,
          onDrop: onDrop,
          child: _CompactRow(
            entry: entry,
            selectedPaths: selectedPaths,
            onPress: () => onPress(entry),
            onTap: () => onTap(entry),
            onOpen: () => onOpen(entry),
            onMenu: (position) => onMenu(entry, position),
            onMiddleClick: onMiddleClick == null
                ? null
                : () => onMiddleClick!(entry),
            paneOwner: paneOwner,
          ),
        );
      },
    );
  }
}

class _CompactRow extends StatelessWidget {
  const _CompactRow({
    required this.entry,
    required this.selectedPaths,
    required this.onPress,
    required this.onTap,
    required this.onOpen,
    required this.onMenu,
    this.onMiddleClick,
    this.paneOwner,
  });

  final rust.FileEntry entry;
  final RxSet<String> selectedPaths;
  final VoidCallback onPress;
  final VoidCallback onTap;
  final VoidCallback onOpen;
  final ValueChanged<Offset> onMenu;
  final VoidCallback? onMiddleClick;
  final Object? paneOwner;

  @override
  Widget build(BuildContext context) {
    final Widget content = Row(
      children: [
        SizedBox(width: 20, child: _EntryMiniIcon(entry: entry)),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            entry.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, color: context.colors.textPrimary),
          ),
        ),
      ],
    );

    return HoverRegion(
      key: entryTileKey(entry.path, owner: paneOwner),
      builder: (context, hovered) {
        return Listener(
          onPointerDown: (event) {
            if (event.buttons == kPrimaryButton) onPress();
          },
          child: GestureDetector(
            onTap: onTap,
            onDoubleTap: onOpen,
            onTertiaryTapUp: (_) => onMiddleClick?.call(),
            onSecondaryTapDown: (details) => onMenu(details.globalPosition),
            child: Obx(() {
              final bool selected = selectedPaths.contains(entry.path);

              return AnimatedContainer(
                duration: _selectionAnimationDuration,
                curve: Curves.easeOut,
                height: 22,
                margin: const EdgeInsets.symmetric(horizontal: 8),
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: selected
                      ? context.colors.selection
                      : hovered
                      ? context.colors.hover
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: selected
                        ? context.colors.selectionBorder
                        : Colors.transparent,
                  ),
                ),
                child: content,
              );
            }),
          ),
        );
      },
    );
  }
}

class _EntryDragWrapper extends StatefulWidget {
  const _EntryDragWrapper({
    required this.entry,
    required this.child,
    this.dragEntries,
    this.canDrop,
    this.onDrop,
  });

  final rust.FileEntry entry;
  final Widget child;
  final EntryDragEntriesCallback? dragEntries;
  final EntryCanDropCallback? canDrop;
  final EntryDropCallback? onDrop;

  @override
  State<_EntryDragWrapper> createState() => _EntryDragWrapperState();
}

/// text/uri-list carrying the whole selection in a single item so external
/// applications receive every dragged file in one drop.
const SimpleValueFormat<List<Uri>> _fileUriListFormat =
    SimpleValueFormat<List<Uri>>(
      linux: SimplePlatformCodec<List<Uri>>(
        formats: ['text/uri-list'],
        onEncode: _uriListToSystem,
      ),
      fallback: SimplePlatformCodec<List<Uri>>(
        formats: ['text/uri-list'],
        onEncode: _uriListToSystem,
      ),
    );

String _uriListToSystem(List<Uri> uris, PlatformFormat format) =>
    uris.map((Uri uri) => uri.toString()).join('\r\n');

/// Builds the native drag payload for a selection. The full path list rides
/// along as [DragItem.localData] so an in-app drop target can reconstruct the
/// entries without touching the filesystem. Returns null for an empty
/// selection, which cancels the drag before it starts.
Future<DragItem?> buildEntryDragItem(List<rust.FileEntry> entries) async {
  if (entries.isEmpty) return null;

  final List<String> paths = entries
      .map((rust.FileEntry entry) => entry.path)
      .toList();

  final DragItem item = DragItem(localData: paths);
  // text/uri-list is what other applications read on drop; plain text is
  // a readable fallback for apps that don't handle uri lists.
  item.add(_fileUriListFormat(paths.map(Uri.file).toList()));
  item.add(Formats.plainText(paths.join('\n')));
  return item;
}

/// Reconstructs dropped entries from an in-app drag session's local data.
/// Size/mtime are not needed for move/copy decisions, only paths.
List<rust.FileEntry> entriesFromLocalData(Object? localData) {
  if (localData is! List) return const <rust.FileEntry>[];
  return localData
      .whereType<String>()
      .map(entryFromPath)
      .toList(growable: false);
}

rust.FileEntry entryFromPath(String path) {
  final bool isDirectory = Directory(path).existsSync();
  return rust.FileEntry(
    name: p.basename(path),
    path: path,
    isDirectory: isDirectory,
    isFile: !isDirectory,
    sizeBytes: BigInt.zero,
    modifiedSeconds: 0,
  );
}

class _EntryDragWrapperState extends State<_EntryDragWrapper> {
  bool _dropHovering = false;

  List<rust.FileEntry> _resolveEntries() =>
      widget.dragEntries?.call(widget.entry) ?? <rust.FileEntry>[widget.entry];

  Future<DragItem?> _provideDragItem(DragItemRequest request) =>
      buildEntryDragItem(_resolveEntries());

  List<rust.FileEntry> _internalEntries(DropSession session) =>
      entriesFromLocalData(
        session.items.isEmpty ? null : session.items.first.localData,
      );

  @override
  Widget build(BuildContext context) {
    final Widget source = DragItemWidget(
      dragItemProvider: _provideDragItem,
      allowedOperations: () => const <DropOperation>[
        DropOperation.copy,
        DropOperation.move,
      ],
      // Native drag image: the same "N items" chip the old Flutter
      // Draggable used as feedback.
      dragBuilder: (BuildContext context, Widget child) =>
          _EntryDragFeedback(entries: _resolveEntries()),
      child: DraggableWidget(child: widget.child),
    );

    if (!widget.entry.isDirectory ||
        widget.canDrop == null ||
        widget.onDrop == null) {
      return source;
    }

    // Empty formats = only accept drag sessions started inside this app,
    // same behavior as the previous Flutter-internal Draggable/DragTarget.
    return DropRegion(
      formats: const <DataFormat>[],
      hitTestBehavior: HitTestBehavior.opaque,
      onDropOver: (DropOverEvent event) {
        final List<rust.FileEntry> entries = _internalEntries(event.session);
        final bool accept =
            entries.isNotEmpty && widget.canDrop!(entries, widget.entry.path);
        if (accept != _dropHovering) {
          setState(() => _dropHovering = accept);
        }
        return accept ? DropOperation.move : DropOperation.none;
      },
      onDropLeave: (DropEvent event) {
        if (_dropHovering) setState(() => _dropHovering = false);
      },
      onPerformDrop: (PerformDropEvent event) async {
        if (!_dropHovering) return;
        final List<rust.FileEntry> entries = _internalEntries(event.session);
        if (entries.isEmpty || !widget.canDrop!(entries, widget.entry.path)) {
          return;
        }
        setState(() => _dropHovering = false);
        widget.onDrop!(entries, widget.entry.path);
      },
      child: Stack(
        children: [
          source,
          if (_dropHovering)
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    color: context.colors.selection.withValues(alpha: 0.32),
                    borderRadius: BorderRadius.circular(7),
                    border: Border.all(color: context.colors.selectionBorder),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _EntryDragFeedback extends StatelessWidget {
  const _EntryDragFeedback({required this.entries});

  final List<rust.FileEntry> entries;

  /// Badge height is fixed so the preview never jumps between files and
  /// folders or between one item and many; only the width follows the label.
  // static const double _height = 8;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final String label = entries.length == 1
        ? entries.single.name
        : '${entries.length} items';

    // Outline in the sidebar-divider tone over a themed surface fill, so the
    // chip follows the active palette (and its light/dark variant) instead of
    // floating transparently over whatever is underneath.
    return Center(
      child: Column(
        children: [
        Icon(CupertinoIcons.book_solid, size: 40,),
          Text(
            label,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _EntryGlyph extends StatelessWidget {
  const _EntryGlyph({required this.entry});

  final rust.FileEntry entry;

  @override
  Widget build(BuildContext context) {
    if (entry.isFile && isRasterImageFile(entry.name)) {
      return ImageThumbnail(
        path: entry.path,
        width: 58,
        height: 58,
        fallback: FileGlyph(name: entry.name, width: 46, height: 58),
      );
    }

    if (entry.isDirectory) {
      return ThemedIcon(
        iconNames: themedIconNamesFor(name: entry.name, isDirectory: true),
        size: 56,
        fallback: FolderGlyph(),
      );
    }

    return ThemedIcon(
      iconNames: themedIconNamesFor(name: entry.name, isDirectory: false),
      size: 50,
      fallback: FileGlyph(name: entry.name),
    );
  }
}

class _EntryMiniIcon extends StatelessWidget {
  const _EntryMiniIcon({required this.entry});

  final rust.FileEntry entry;

  @override
  Widget build(BuildContext context) {
    if (entry.isDirectory) {
      return Align(
        alignment: Alignment.centerLeft,
        child: ThemedIcon(
          iconNames: themedIconNamesFor(name: entry.name, isDirectory: true),
          size: 15,
          fallback: Icon(Icons.folder, size: 15, color: context.colors.folder),
        ),
      );
    }

    final Color color = fileColorFor(entry.name, context.colors);

    if (isRasterImageFile(entry.name)) {
      return Align(
        alignment: Alignment.centerLeft,
        child: ImageThumbnail(
          path: entry.path,
          width: 15,
          height: 15,
          fallback: Icon(Icons.description_outlined, size: 15, color: color),
        ),
      );
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: ThemedIcon(
        iconNames: themedIconNamesFor(name: entry.name, isDirectory: false),
        size: 15,
        fallback: Icon(Icons.description_outlined, size: 15, color: color),
      ),
    );
  }
}
