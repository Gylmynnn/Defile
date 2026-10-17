import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../theme/app_theme.dart';
import '../../services/font_service.dart';
import '../../services/icon_theme_service.dart';
import 'entry_glyphs.dart';
import 'themed_icon.dart';

enum SettingsTab { iconTheme, font }

class SettingsDialog extends StatefulWidget {
  const SettingsDialog({super.key});

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  final TextEditingController _searchController = TextEditingController();
  SettingsTab _activeTab = SettingsTab.iconTheme;
  String _query = '';

  IconThemeService get _iconService => Get.find<IconThemeService>();
  FontService get _fontService => Get.find<FontService>();

  @override
  void initState() {
    super.initState();
    _iconService.refreshThemes();
    if (Get.isRegistered<FontService>()) {
      _fontService.refreshFonts();
    }
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
        width: 440,
        height: 360,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildTabSelector(),
            const SizedBox(height: 12),
            if (_activeTab == SettingsTab.iconTheme) ...[
              _buildIconThemeHeader(),
              const SizedBox(height: 4),
              const Text(
                'Ikon diambil dari tema terpasang di perangkat. Pengaturan ini '
                'hanya berlaku untuk Defile.',
                style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
              ),
            ] else ...[
              _buildFontHeader(),
              const SizedBox(height: 4),
              const Text(
                'Font diambil dari font yang terpasang di sistem. Pengaturan ini '
                'hanya berlaku untuk Defile.',
                style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
              ),
            ],
            const SizedBox(height: 10),
            _buildSearchField(),
            const SizedBox(height: 6),
            Expanded(
              child: _activeTab == SettingsTab.iconTheme
                  ? Obx(() => _buildThemeList())
                  : Obx(() => _buildFontList()),
            ),
          ],
        ),
      ),
      actions: [FilledButton(onPressed: Get.back, child: const Text('Tutup'))],
    );
  }

  Widget _buildTabSelector() {
    return Container(
      height: 32,
      decoration: BoxDecoration(
        color: AppColors.window,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.menuBorder),
      ),
      padding: const EdgeInsets.all(2),
      child: Row(
        children: [
          Expanded(
            child: _buildTabButton(
              label: 'Tema Ikon',
              icon: Icons.palette_outlined,
              tab: SettingsTab.iconTheme,
            ),
          ),
          const SizedBox(width: 2),
          Expanded(
            child: _buildTabButton(
              label: 'Font Sistem',
              icon: Icons.text_fields_rounded,
              tab: SettingsTab.font,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton({
    required String label,
    required IconData icon,
    required SettingsTab tab,
  }) {
    final bool active = _activeTab == tab;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          if (_activeTab != tab) {
            _searchController.clear();
            setState(() {
              _activeTab = tab;
              _query = '';
            });
          }
        },
        child: Container(
          decoration: BoxDecoration(
            color: active ? AppColors.surfaceHigh : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 14,
                color: active ? AppColors.accent : AppColors.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: active ? FontWeight.w600 : FontWeight.normal,
                  color: active ? AppColors.textPrimary : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIconThemeHeader() {
    return Row(
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
              onTap: _iconService.refreshThemes,
              child: const Icon(
                Icons.refresh,
                size: 15,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFontHeader() {
    return Row(
      children: [
        const Expanded(
          child: Text(
            'Font tampilan',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        Tooltip(
          message: 'Pindai ulang font sistem',
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: _fontService.refreshFonts,
              child: const Icon(
                Icons.refresh,
                size: 15,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchField() {
    final String hint =
        _activeTab == SettingsTab.iconTheme ? 'Cari tema...' : 'Cari font...';

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
              decoration: InputDecoration(
                isDense: true,
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                hintText: hint,
                hintStyle: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textFaint,
                ),
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
    final String selected = _iconService.themeName.value;
    final String query = _query.toLowerCase();
    final List<_ThemeChoice> choices = [
      const _ThemeChoice(name: '', path: null),
      for (final theme in _iconService.themes)
        if (query.isEmpty || theme.name.toLowerCase().contains(query))
          _ThemeChoice(name: theme.name, path: theme.path),
    ];

    if (_iconService.themes.isEmpty) {
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
          onTap: () => _iconService.setTheme(choice.name),
        );
      },
    );
  }

  Widget _buildFontList() {
    final String selected = _fontService.fontFamily.value;
    final String query = _query.toLowerCase();
    final List<String> filtered = [
      '',
      for (final font in _fontService.fonts)
        if (query.isEmpty || font.toLowerCase().contains(query))
          font,
    ];

    if (_fontService.isLoading.value && _fontService.fonts.isEmpty) {
      return const Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    if (filtered.length == 1 && query.isNotEmpty) {
      return const Center(
        child: Text(
          'Font tidak ditemukan.',
          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(right: 2),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final String fontName = filtered[index];
        final bool isDefault = fontName.isEmpty;
        final bool isSelected = fontName == selected;

        return _FontOption(
          fontName: fontName,
          isDefault: isDefault,
          selected: isSelected,
          onTap: () => _fontService.setFont(fontName),
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

class _FontOption extends StatefulWidget {
  const _FontOption({
    required this.fontName,
    required this.isDefault,
    required this.selected,
    required this.onTap,
  });

  final String fontName;
  final bool isDefault;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_FontOption> createState() => _FontOptionState();
}

class _FontOptionState extends State<_FontOption> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final String label = widget.isDefault ? 'Bawaan aplikasi' : widget.fontName;
    final String? previewFamily = widget.isDefault ? null : widget.fontName;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
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
              Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.surfaceHigh,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Aa',
                  style: TextStyle(
                    fontFamily: previewFamily,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: widget.selected
                        ? AppColors.accent
                        : AppColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: previewFamily,
                    fontSize: 12.5,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              if (widget.selected)
                const Icon(Icons.check, size: 15, color: AppColors.accent),
            ],
          ),
        ),
      ),
    );
  }
}
