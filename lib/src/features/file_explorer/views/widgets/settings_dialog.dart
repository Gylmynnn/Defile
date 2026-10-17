import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../theme/app_theme.dart';
import '../../services/icon_theme_service.dart';
import 'entry_glyphs.dart';
import 'themed_icon.dart';

class SettingsDialog extends StatefulWidget {
  const SettingsDialog({super.key});

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  IconThemeService get _service => Get.find<IconThemeService>();

  @override
  void initState() {
    super.initState();
    _service.refreshThemes();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Pengaturan'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Tema ikon',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                Tooltip(
                  message: 'Pindai ulang tema terpasang',
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: _service.refreshThemes,
                      child: const Icon(
                        Icons.refresh,
                        size: 15,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Ikon diambil dari tema terpasang di perangkat. Pengaturan ini '
              'hanya berlaku untuk Defile.',
              style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 10),
            _buildSearchField(),
            const SizedBox(height: 6),
            SizedBox(height: 300, child: Obx(() => _buildThemeList())),
          ],
        ),
      ),
      actions: [FilledButton(onPressed: Get.back, child: const Text('Tutup'))],
    );
  }

  Widget _buildSearchField() {
    return Container(
      height: 28,
      padding: const EdgeInsets.only(left: 8, right: 4),
      decoration: BoxDecoration(
        color: AppColors.window,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.menuBorder),
      ),
      child: Row(
        children: [
          const Icon(Icons.search, size: 13, color: AppColors.textFaint),
          const SizedBox(width: 6),
          Expanded(
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _query = value.trim()),
              cursorHeight: 13,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textPrimary,
              ),
              decoration: const InputDecoration(
                isDense: true,
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                hintText: 'Cari tema...',
                hintStyle: TextStyle(fontSize: 12, color: AppColors.textFaint),
              ),
            ),
          ),
          if (_query.isNotEmpty)
            InkWell(
              onTap: () {
                _searchController.clear();
                setState(() => _query = '');
              },
              borderRadius: BorderRadius.circular(4),
              child: const Padding(
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

  Widget _buildThemeList() {
    final String selected = _service.themeName.value;
    final String query = _query.toLowerCase();
    final List<_ThemeChoice> choices = [
      const _ThemeChoice(name: '', path: null),
      for (final theme in _service.themes)
        if (query.isEmpty || theme.name.toLowerCase().contains(query))
          _ThemeChoice(name: theme.name, path: theme.path),
    ];

    if (_service.themes.isEmpty) {
      return const Center(
        child: Text(
          'Tidak ada tema ikon terpasang yang bisa dipakai.',
          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
      );
    }

    if (choices.length == 1) {
      return const Center(
        child: Text(
          'Tema tidak ditemukan.',
          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(right: 2),
      itemCount: choices.length,
      itemBuilder: (context, index) {
        final _ThemeChoice choice = choices[index];

        return _ThemeOption(
          choice: choice,
          selected: choice.name == selected,
          onTap: () => _service.setTheme(choice.name),
        );
      },
    );
  }
}

class _ThemeChoice {
  const _ThemeChoice({required this.name, required this.path});

  final String name;
  final String? path;
}

class _ThemeOption extends StatefulWidget {
  const _ThemeOption({
    required this.choice,
    required this.selected,
    required this.onTap,
  });

  final _ThemeChoice choice;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_ThemeOption> createState() => _ThemeOptionState();
}

class _ThemeOptionState extends State<_ThemeOption> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final bool isDefault = widget.choice.name.isEmpty;

    final Widget preview = isDefault
        ? const Center(child: FolderGlyph(width: 21, height: 17))
        : ThemedIcon(
            iconNames: const ['folder', 'inode-directory'],
            size: 19,
            theme: widget.choice.name,
            fallback: const Icon(
              Icons.folder,
              size: 17,
              color: AppColors.textFaint,
            ),
          );

    final Widget row = Container(
      height: 32,
      margin: const EdgeInsets.symmetric(vertical: 1),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: widget.selected
            ? AppColors.selection
            : _hovered
            ? AppColors.hover
            : Colors.transparent,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(
          color: widget.selected
              ? AppColors.selectionBorder
              : Colors.transparent,
        ),
      ),
      child: Row(
        children: [
          SizedBox(width: 24, child: preview),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isDefault ? 'Bawaan aplikasi' : widget.choice.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12.5,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          if (widget.selected)
            const Icon(Icons.check, size: 15, color: AppColors.accent),
        ],
      ),
    );

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: widget.choice.path == null
            ? row
            : Tooltip(message: widget.choice.path!, child: row),
      ),
    );
  }
}
