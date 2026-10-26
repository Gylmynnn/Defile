import 'dart:collection';

import 'package:defile/src/rust/api/file_entry.dart' as rust;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

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

class _LazyEntries extends ListBase<rust.FileEntry> {
  _LazyEntries(this._resolve);

  final List<rust.FileEntry> Function() _resolve;
  List<rust.FileEntry>? _value;

  void reset() => _value = null;

  List<rust.FileEntry> get _entries => _value ??= _resolve();

  @override
  int get length => _entries.length;

  @override
  set length(int value) => throw UnsupportedError('read-only');

  @override
  rust.FileEntry operator [](int index) => _entries[index];

  @override
  void operator []=(int index, rust.FileEntry value) =>
      throw UnsupportedError('read-only');
}

final Map<String, GlobalKey> _entryKeys = <String, GlobalKey>{};

// ponytail: keys cached per path to avoid re-allocating a GlobalKey on every
// tile build. Never pruned; harmless for typical sessions. Add pruning keyed on
// the live entry set if enormous unique trees get visited.
GlobalKey entryTileKey(String path) =>
    _entryKeys.putIfAbsent(path, GlobalKey.new);

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
            onMiddleClick: onMiddleClick == null ? null : () => onMiddleClick!(entry),
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
  });

  final rust.FileEntry entry;
  final RxSet<String> selectedPaths;
  final VoidCallback onPress;
  final VoidCallback onTap;
  final VoidCallback onOpen;
  final ValueChanged<Offset> onMenu;
  final VoidCallback? onMiddleClick;

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
      key: entryTileKey(entry.path),
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
            onLongPressStart: (details) => onMenu(details.globalPosition),
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
  });

  final rust.FileEntry entry;
  final RxSet<String> selectedPaths;
  final VoidCallback onPress;
  final VoidCallback onTap;
  final VoidCallback onOpen;
  final ValueChanged<Offset> onMenu;
  final VoidCallback? onMiddleClick;

  @override
  Widget build(BuildContext context) {
    return HoverRegion(
      key: entryTileKey(entry.path),
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
  });

  final rust.FileEntry entry;
  final RxSet<String> selectedPaths;
  final VoidCallback onPress;
  final VoidCallback onTap;
  final VoidCallback onOpen;
  final ValueChanged<Offset> onMenu;
  final VoidCallback? onMiddleClick;

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
      key: entryTileKey(entry.path),
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

class _EntryDragWrapper extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final _LazyEntries dragged = _LazyEntries(
      () => dragEntries?.call(entry) ?? <rust.FileEntry>[entry],
    );

    final Widget source = Draggable<List<rust.FileEntry>>(
      data: dragged,
      dragAnchorStrategy: pointerDragAnchorStrategy,
      feedback: _EntryDragFeedback(entries: dragged),
      childWhenDragging: Opacity(opacity: 0.45, child: child),
      onDragStarted: dragged.reset,
      child: child,
    );

    if (!entry.isDirectory || canDrop == null || onDrop == null) return source;

    return DragTarget<List<rust.FileEntry>>(
      onWillAcceptWithDetails: (details) => canDrop!(details.data, entry.path),
      onAcceptWithDetails: (details) => onDrop!(details.data, entry.path),
      builder: (context, candidateData, rejectedData) {
        final bool hovering = candidateData.any(
          (data) => data != null && canDrop!(data, entry.path),
        );

        return Stack(
          children: [
            source,
            if (hovering)
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
        );
      },
    );
  }
}

class _EntryDragFeedback extends StatelessWidget {
  const _EntryDragFeedback({required this.entries});

  final List<rust.FileEntry> entries;

  @override
  Widget build(BuildContext context) {
    final String label = entries.length == 1
        ? entries.single.name
        : '${entries.length} items';

    return Material(
      color: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 220),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: context.colors.surfaceHigh,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: context.colors.selectionBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.28),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              entries.length == 1 && entries.single.isDirectory
                  ? Icons.folder_outlined
                  : Icons.insert_drive_file_outlined,
              size: 15,
              color: context.colors.textSecondary,
            ),
            const SizedBox(width: 7),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: context.colors.textPrimary,
                ),
              ),
            ),
          ],
        ),
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
