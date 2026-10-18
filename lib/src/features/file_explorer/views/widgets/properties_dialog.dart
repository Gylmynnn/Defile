import 'package:defile/src/rust/api/file_entry.dart' as rust;
import 'package:defile/src/rust/api/properties.dart' as rust_properties;
import 'package:defile/src/rust/api/system.dart' as rust_system;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../../theme/app_theme.dart';
import '../../controllers/file_explorer_controller.dart';
import '../../utils/formatters.dart';
import 'app_dialog.dart';
import 'entry_glyphs.dart';
import 'image_thumbnail.dart';
import 'themed_icon.dart';

class PropertiesDialog extends StatefulWidget {
  const PropertiesDialog({super.key, required this.entry});

  final rust.FileEntry entry;

  @override
  State<PropertiesDialog> createState() => _PropertiesDialogState();
}

class _PropertiesDialogState extends State<PropertiesDialog> {
  late final TextEditingController _nameController;

  rust_properties.EntryProperties? _properties;
  rust_system.DiskUsage? _usage;
  String? _error;
  bool _loading = true;

  FileExplorerController get _explorerController =>
      Get.find<FileExplorerController>();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.entry.name);
    _load();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final properties = await rust_properties.getEntryProperties(
        path: widget.entry.path,
      );

      rust_system.DiskUsage? usage;
      try {
        usage = await rust_system.getDiskUsage(path: widget.entry.path);
      } catch (_) {
        usage = null;
      }

      if (!mounted) return;
      setState(() {
        _properties = properties;
        _usage = usage;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  void _applyRename() {
    final String name = _nameController.text.trim();
    if (name.isEmpty || name == widget.entry.name) return;

    Get.back();
    _explorerController.renameEntry(widget.entry, name);
  }

  Future<void> _copyPath() async {
    await Clipboard.setData(ClipboardData(text: widget.entry.path));
    Get.snackbar(
      'Path copied',
      widget.entry.path,
      snackPosition: SnackPosition.BOTTOM,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      title: 'Properties',
      width: 500,
      maxHeight: 620,
      actions: [
        AppDialogButton(label: 'Copy path', onTap: _copyPath),
        AppDialogButton(label: 'Close', primary: true, onTap: Get.back),
      ],
      content: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_showPreview) _buildPreview(),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!_showPreview) SizedBox(width: 62, child: _buildIcon()),
                Expanded(child: _buildDetails()),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIcon() {
    if (widget.entry.isDirectory) {
      return Padding(
        padding: const EdgeInsets.only(top: 2),
        child: ThemedIcon(
          iconNames: themedIconNamesFor(
            name: widget.entry.name,
            isDirectory: true,
          ),
          size: 40,
          fallback: FolderGlyph(width: 52, height: 40),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: ThemedIcon(
        iconNames: themedIconNamesFor(
          name: widget.entry.name,
          isDirectory: false,
        ),
        size: 42,
        fallback: FileGlyph(name: widget.entry.name, width: 34, height: 42),
      ),
    );
  }

  bool get _showPreview =>
      widget.entry.isFile && isImageFile(widget.entry.name);

  Widget _buildPreview() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Center(
        child: ImageThumbnail(
          path: widget.entry.path,
          width: 176,
          height: 120,
          fit: BoxFit.contain,
          fallback: FileGlyph(name: widget.entry.name, width: 84, height: 106),
        ),
      ),
    );
  }

  Widget _buildDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _row('Name:', _buildNameField()),
        _row('Type:', Text(_properties?.kind ?? _fallbackKind())),
        _row('Location:', SelectableText(widget.entry.path)),
        if (_properties?.linkTarget != null)
          _row('Link:', SelectableText(_properties!.linkTarget!)),
        const SizedBox(height: 10),
        if (_loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          )
        else if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              _error!,
              style: TextStyle(fontSize: 12, color: AppColors.dangerBright),
            ),
          )
        else ...[
          _row('Created:', Text(formatDateNumeric(_created))),
          _row('Modified:', Text(formatDateNumeric(_modified))),
          _row('Accessed:', Text(formatDateNumeric(_accessed))),
          const SizedBox(height: 10),
          _row('Size:', Text(_sizeLabel)),
          _row('Size on disk:', Text(_sizeOnDiskLabel)),
          if (_properties!.isDirectory) ...[
            const SizedBox(height: 10),
            _row('Contents:', Text(_contentLabel)),
          ],
          if (_usage != null) ...[
            const SizedBox(height: 10),
            _row('Capacity:', Text(formatBytesIec(_usage!.totalBytes))),
            _row('Usage:', _buildUsageText()),
            const SizedBox(height: 6),
            _buildUsageBar(),
          ],
        ],
      ],
    );
  }

  Widget _buildNameField() {
    return TextField(
      controller: _nameController,
      onSubmitted: (_) => _applyRename(),
      style: TextStyle(fontSize: 12.5, color: AppColors.textPrimary),
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        fillColor: AppColors.input,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: AppColors.inputBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: AppColors.inputBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: AppColors.selectionBorder),
        ),
      ),
    );
  }

  Widget _row(String label, Widget value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Text(
              label,
              textAlign: TextAlign.right,
              style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: DefaultTextStyle.merge(
              style: TextStyle(fontSize: 12.5, color: AppColors.textPrimary),
              child: value,
            ),
          ),
        ],
      ),
    );
  }

  String _fallbackKind() => widget.entry.isDirectory ? 'Folder' : 'File';

  int get _created => _properties?.createdSeconds.toInt() ?? 0;

  int get _modified => _properties?.modifiedSeconds.toInt() ?? 0;

  int get _accessed => _properties?.accessedSeconds.toInt() ?? 0;

  String get _sizeLabel {
    final properties = _properties;
    if (properties == null) return '—';

    return '${formatBytesIec(properties.sizeBytes)} '
        '(${formatThousands(properties.sizeBytes)} byte)';
  }

  String get _sizeOnDiskLabel {
    final properties = _properties;
    if (properties == null) return '—';

    return '${formatBytesIec(properties.sizeOnDiskBytes)} '
        '(${formatThousands(properties.sizeOnDiskBytes)} byte)';
  }

  String get _contentLabel {
    final properties = _properties;
    if (properties == null) return '—';

    final int files = properties.fileCount.toInt();
    final int folders = properties.folderCount.toInt();

    return '${files + folders} items ($files files, $folders folders)';
  }

  Widget _buildUsageText() {
    final usage = _usage;
    if (usage == null || usage.totalBytes == BigInt.zero) {
      return const Text('—');
    }

    final double usedRatio =
        usage.usedBytes.toDouble() / usage.totalBytes.toDouble();
    final int usedPercent = (usedRatio * 100).round();
    final int freePercent = 100 - usedPercent;

    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: '${formatBytesIec(usage.usedBytes)} used'),
          TextSpan(
            text: ' ($usedPercent%)',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          TextSpan(
            text: '   |   ',
            style: TextStyle(color: AppColors.textFaint),
          ),
          TextSpan(text: '${formatBytesIec(usage.freeBytes)} free'),
          TextSpan(
            text: ' ($freePercent%)',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildUsageBar() {
    final usage = _usage;
    final double ratio = usage == null || usage.totalBytes == BigInt.zero
        ? 0
        : usage.usedBytes.toDouble() / usage.totalBytes.toDouble();

    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: LinearProgressIndicator(
        value: ratio.clamp(0.0, 1.0),
        minHeight: 8,
        color: AppColors.folder,
        backgroundColor: AppColors.chip,
      ),
    );
  }
}
