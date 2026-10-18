import 'package:defile/src/rust/api/file_entry.dart' as rust;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../../../theme/app_theme.dart';
import '../../utils/formatters.dart';
import 'entry_glyphs.dart';
import 'image_thumbnail.dart';
import 'themed_icon.dart';

typedef EntryOpenCallback = void Function(rust.FileEntry entry);
typedef EntryMenuCallback = void Function(
  rust.FileEntry entry,
  Offset position,
);

class EntryTileKey extends GlobalKey {
  const EntryTileKey(this.path) : super.constructor();

  final String path;

  @override
  bool operator ==(Object other) => other is EntryTileKey && other.path == path;

  @override
  int get hashCode => path.hashCode;
}

Key entryTileKey(String path) => EntryTileKey(path);

class EntryGridView extends StatelessWidget {
  const EntryGridView({
    super.key,
    required this.entries,
    required this.selectedPaths,
    required this.onPress,
    required this.onTap,
    required this.onOpen,
    required this.onMenu,
  });

  final List<rust.FileEntry> entries;
  final Set<String> selectedPaths;
  final EntryOpenCallback onPress;
  final EntryOpenCallback onTap;
  final EntryOpenCallback onOpen;
  final EntryMenuCallback onMenu;

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

        return _GridTile(
          entry: entry,
          selected: selectedPaths.contains(entry.path),
          onPress: () => onPress(entry),
          onTap: () => onTap(entry),
          onOpen: () => onOpen(entry),
          onMenu: (position) => onMenu(entry, position),
        );
      },
    );
  }
}

class _GridTile extends StatefulWidget {
  const _GridTile({
    required this.entry,
    required this.selected,
    required this.onPress,
    required this.onTap,
    required this.onOpen,
    required this.onMenu,
  });

  final rust.FileEntry entry;
  final bool selected;
  final VoidCallback onPress;
  final VoidCallback onTap;
  final VoidCallback onOpen;
  final ValueChanged<Offset> onMenu;

  @override
  State<_GridTile> createState() => _GridTileState();
}

class _GridTileState extends State<_GridTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    final bool selected = widget.selected;

    return MouseRegion(
      key: entryTileKey(entry.path),
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Listener(
        onPointerDown: (event) {
          if (event.buttons == kPrimaryButton) widget.onPress();
        },
        child: GestureDetector(
          onTap: widget.onTap,
          onDoubleTap: widget.onOpen,
          onSecondaryTapDown: (details) =>
              widget.onMenu(details.globalPosition),
          onLongPressStart: (details) => widget.onMenu(details.globalPosition),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            decoration: BoxDecoration(
              color: selected
                  ? AppColors.selection
                  : _hovered
                  ? AppColors.hover
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(7),
              border: Border.all(
                color: selected
                    ? AppColors.selectionBorder
                    : _hovered
                    ? AppColors.border
                    : Colors.transparent,
              ),
            ),
            child: Column(
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
                    color: AppColors.textPrimary,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
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
  });

  final List<rust.FileEntry> entries;
  final Set<String> selectedPaths;
  final EntryOpenCallback onPress;
  final EntryOpenCallback onTap;
  final EntryOpenCallback onOpen;
  final EntryMenuCallback onMenu;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: 28,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.divider)),
          ),
          child: Row(
            children: [
              SizedBox(width: 24),
              Expanded(child: Text('Nama', style: _headerStyle)),
              SizedBox(width: 92, child: Text('Ukuran', style: _headerStyle)),
              SizedBox(width: 158, child: Text('Diubah', style: _headerStyle)),
              SizedBox(width: 64, child: Text('Tipe', style: _headerStyle)),
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

              return _ListRow(
                entry: entry,
                selected: selectedPaths.contains(entry.path),
                onPress: () => onPress(entry),
                onTap: () => onTap(entry),
                onOpen: () => onOpen(entry),
                onMenu: (position) => onMenu(entry, position),
              );
            },
          ),
        ),
      ],
    );
  }
}

TextStyle get _headerStyle => TextStyle(
  fontSize: 11.5,
  fontWeight: FontWeight.w600,
  color: AppColors.textFaint,
);

class _ListRow extends StatefulWidget {
  const _ListRow({
    required this.entry,
    required this.selected,
    required this.onPress,
    required this.onTap,
    required this.onOpen,
    required this.onMenu,
  });

  final rust.FileEntry entry;
  final bool selected;
  final VoidCallback onPress;
  final VoidCallback onTap;
  final VoidCallback onOpen;
  final ValueChanged<Offset> onMenu;

  @override
  State<_ListRow> createState() => _ListRowState();
}

class _ListRowState extends State<_ListRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    final bool selected = widget.selected;

    return MouseRegion(
      key: entryTileKey(entry.path),
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Listener(
        onPointerDown: (event) {
          if (event.buttons == kPrimaryButton) widget.onPress();
        },
        child: GestureDetector(
          onTap: widget.onTap,
          onDoubleTap: widget.onOpen,
          onSecondaryTapDown: (details) =>
              widget.onMenu(details.globalPosition),
          child: Container(
            height: 29,
            margin: const EdgeInsets.symmetric(horizontal: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: selected
                  ? AppColors.selection
                  : _hovered
                  ? AppColors.hover
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(5),
              border: Border.all(
                color: selected
                    ? AppColors.selectionBorder
                    : Colors.transparent,
              ),
            ),
            child: Row(
              children: [
                SizedBox(width: 24, child: _EntryMiniIcon(entry: entry)),
                Expanded(
                  child: Text(
                    entry.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: AppColors.textPrimary,
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
                      color: AppColors.textSecondary,
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
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                SizedBox(
                  width: 64,
                  child: Text(
                    entry.isDirectory ? 'Folder' : _typeLabel(entry.name),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                SizedBox(
                  width: 26,
                  child: _hovered
                      ? InkWell(
                          onTap: () {
                            final RenderBox box =
                                context.findRenderObject()! as RenderBox;
                            widget.onMenu(
                              box.localToGlobal(box.size.center(Offset.zero)),
                            );
                          },
                          borderRadius: BorderRadius.circular(4),
                          child: Icon(
                            Icons.more_horiz,
                            size: 16,
                            color: AppColors.textSecondary,
                          ),
                        )
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
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
  });

  final List<rust.FileEntry> entries;
  final Set<String> selectedPaths;
  final EntryOpenCallback onPress;
  final EntryOpenCallback onTap;
  final EntryOpenCallback onOpen;
  final EntryMenuCallback onMenu;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 3),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];

        return _CompactRow(
          entry: entry,
          selected: selectedPaths.contains(entry.path),
          onPress: () => onPress(entry),
          onTap: () => onTap(entry),
          onOpen: () => onOpen(entry),
          onMenu: (position) => onMenu(entry, position),
        );
      },
    );
  }
}

class _CompactRow extends StatefulWidget {
  const _CompactRow({
    required this.entry,
    required this.selected,
    required this.onPress,
    required this.onTap,
    required this.onOpen,
    required this.onMenu,
  });

  final rust.FileEntry entry;
  final bool selected;
  final VoidCallback onPress;
  final VoidCallback onTap;
  final VoidCallback onOpen;
  final ValueChanged<Offset> onMenu;

  @override
  State<_CompactRow> createState() => _CompactRowState();
}

class _CompactRowState extends State<_CompactRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    final bool selected = widget.selected;

    return MouseRegion(
      key: entryTileKey(entry.path),
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Listener(
        onPointerDown: (event) {
          if (event.buttons == kPrimaryButton) widget.onPress();
        },
        child: GestureDetector(
          onTap: widget.onTap,
          onDoubleTap: widget.onOpen,
          onSecondaryTapDown: (details) =>
              widget.onMenu(details.globalPosition),
          child: Container(
            height: 22,
            margin: const EdgeInsets.symmetric(horizontal: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: selected
                  ? AppColors.selection
                  : _hovered
                  ? AppColors.hover
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: selected
                    ? AppColors.selectionBorder
                    : Colors.transparent,
              ),
            ),
            child: Row(
              children: [
                SizedBox(width: 20, child: _EntryMiniIcon(entry: widget.entry)),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    widget.entry.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
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
    if (entry.isFile && isImageFile(entry.name)) {
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
          fallback: Icon(Icons.folder, size: 15, color: AppColors.folder),
        ),
      );
    }

    final Color color = fileColorFor(entry.name);

    if (isImageFile(entry.name)) {
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

String _typeLabel(String name) {
  final int dot = name.lastIndexOf('.');
  if (dot == -1 || dot == name.length - 1) return 'File';
  return name.substring(dot + 1).toUpperCase();
}
