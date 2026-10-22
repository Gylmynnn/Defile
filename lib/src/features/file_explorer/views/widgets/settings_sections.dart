part of 'settings_dialog.dart';

extension _SettingsSections on _SettingsDialogState {
  Widget _buildAboutSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Top Card

        const SizedBox(height: 22),
        _buildSectionTitle('About'),
        const SizedBox(height: 8),
        _CustomSectionCard(
          children: [
            _CustomSettingRow(
              title: 'Version 0.5.0',
              subtitle: 'Installer version: 0.5.0',
              linkText: 'Read the changelog.',
              onLinkTap: () {
                _showInfoMessage(
                  'Changelog',
                  'Defile 0.5.0 introduces custom themes, and lightning-fast file navigation.',
                );
              },
              control: _CustomButton(
                label: 'Check for updates',
                onTap: () {
                  _showInfoMessage(
                    'Update Check',
                    'You are running the latest version of Defile.',
                  );
                },
              ),
            ),

            // NOTE: i think not made langage switch feature for now

            // _CustomDivider(),
            // _CustomSettingRow(
            //   title: 'Language',
            //   subtitle: 'Change the display language.\nLearn how to add a new language to Defile.',
            //   control: _CustomDropdown<String>(
            //     value: _selectedLanguage,
            //     items: const [
            //       DropdownMenuItem(value: 'English', child: Text('English')),
            //       DropdownMenuItem(
            //         value: 'Bahasa Indonesia',
            //         child: Text('Bahasa Indonesia'),
            //       ),
            //       DropdownMenuItem(value: '日本語', child: Text('日本語')),
            //       DropdownMenuItem(value: 'Deutsch', child: Text('Deutsch')),
            //       DropdownMenuItem(value: 'Français', child: Text('Français')),
            //     ],
            //     onChanged: (val) {
            //       if (val != null) _update(() => _selectedLanguage = val);
            //     },
            //   ),
            // ),
          ],
        ),
      ],
    );
  }

  // ==========================================
  // Appearance Section (Real Icon & Font service)
  // ==========================================
  Widget _buildAppearanceSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Theme & Styling'),
        const SizedBox(height: 8),

        // Icon Theme Card
        _CustomSectionCard(
          children: [
            Obx(() {
              final String currentTheme = _iconService.themeName.value;
              final String display = currentTheme.isEmpty
                  ? 'Application default'
                  : currentTheme;

              return _CustomSettingRow(
                title: 'Icon theme',
                subtitle: 'Icons are loaded from themes installed on this system. Applies across all files and folders.',
                control: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: context.colors.chip,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: context.colors.chipBorder),
                      ),
                      child: Text(
                        display,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: context.colors.accent,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _CustomButton(
                      label: 'Scan themes',
                      onTap: _iconService.refreshThemes,
                    ),
                  ],
                ),
              );
            }),
            _CustomDivider(),
            Padding(
              padding: const EdgeInsets.all(12),
              child: _buildThemeSearchField(),
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200),
              child: Obx(() => _buildCustomThemeList()),
            ),
          ],
        ),

        const SizedBox(height: 22),
        _buildSectionTitle('Typography'),
        const SizedBox(height: 8),

        // Display Font Card
        _CustomSectionCard(
          children: [
            Obx(() {
              final String currentFont = _fontService.fontFamily.value;
              final String display = currentFont.isEmpty
                  ? 'Application default'
                  : currentFont;

              return _CustomSettingRow(
                title: 'Display font',
                subtitle: 'Select a font installed on your system. Defile will immediately render with the chosen typeface.',
                control: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: context.colors.chip,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: context.colors.chipBorder),
                      ),
                      child: Text(
                        display,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: context.colors.accent,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _CustomButton(
                      label: 'Scan fonts',
                      onTap: _fontService.refreshFonts,
                    ),
                  ],
                ),
              );
            }),
            _CustomDivider(),
            Padding(
              padding: const EdgeInsets.all(12),
              child: _buildFontSearchField(),
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200),
              child: Obx(() => _buildCustomFontList()),
            ),
          ],
        ),

        const SizedBox(height: 22),
        _buildSectionTitle('Colors & Accents'),
        const SizedBox(height: 8),

        _CustomSectionCard(
          children: [
            Obx(() {
              final String currentTheme = _themeService.baseThemeId.value;

              return _CustomSettingRow(
                title: 'Base color theme',
                subtitle:
                    'Select the base color scheme for the whole interface.',
                control: _CustomDropdown<String>(
                  value: AppPalettes.byId(currentTheme).id,
                  items: [
                    for (final palette in AppPalettes.all)
                      DropdownMenuItem(
                        value: palette.id,
                        child: Text(palette.label),
                      ),
                  ],
                  onChanged: (val) {
                    if (val != null) _selectBaseTheme(val);
                  },
                ),
              );
            }),
            _CustomDivider(),
            Obx(() {
              final String currentAccent = _themeService.accentId.value;

              return _CustomSettingRow(
                title: 'Accent color',
                subtitle:
                    'Color highlight for selections, badges, and focus rings.',
                control: Wrap(
                  spacing: 6,
                  children: [
                    for (final accent in AppAccents.all)
                      _ColorDot(
                        color: accent.color,
                        isSelected: accent.id == currentAccent,
                        onTap: () => _selectAccent(accent.id),
                      ),
                  ],
                ),
              );
            }),
          ],
        ),

        const SizedBox(height: 22),
        _buildSectionTitle('Display'),
        const SizedBox(height: 8),

        _CustomSectionCard(
          children: [
            Obx(() {
              final double scale = _themeService.uiScale.value;

              return _CustomSettingRow(
                title: 'Interface scale',
                subtitle: 'Enlarge or shrink the whole interface, similar to display scaling on your monitor.',
                control: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 168,
                      child: SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 3,
                          activeTrackColor: context.colors.accent,
                          inactiveTrackColor: context.colors.elevated,
                          thumbColor: context.colors.accent,
                          overlayShape: SliderComponentShape.noOverlay,
                          thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 6,
                          ),
                        ),
                        child: Slider(
                          value: scale,
                          min: ThemeService.minScale,
                          max: ThemeService.maxScale,
                          divisions: 15,
                          onChanged: _themeService.setUiScale,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      width: 48,
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(
                        color: context.colors.elevated,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: context.colors.elevatedBorder,
                        ),
                      ),
                      child: Text(
                        '${(scale * 100).round()}%',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: context.colors.accent,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _CustomButton(
                      label: 'Reset',
                      onTap: () => _themeService.setUiScale(1.0),
                    ),
                  ],
                ),
              );
            }),
            _CustomDivider(),
            Obx(() {
              final bool enabled = _themeService.animationsEnabled.value;

              return _CustomSettingRow(
                title: 'Smooth animations',
                subtitle:
                    'Animate the sidebar and popups when they open and close.',
                control: _CustomSwitch(
                  value: enabled,
                  onChanged: (val) =>
                      _themeService.animationsEnabled.value = val,
                ),
              );
            }),
          ],
        ),
      ],
    );
  }

  // ==========================================
  // Interface Section (Wired to FileExplorerController)
  // ==========================================
  Widget _buildInterfaceSection() {
    final controller = _explorerController;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Explorer View'),
        const SizedBox(height: 8),

        _CustomSectionCard(
          children: [
            if (controller != null)
              Obx(() {
                final mode = controller.viewMode.value;

                return _CustomSettingRow(
                  title: 'Default layout mode',
                  subtitle: 'Choose how folder items and entries are laid out.',
                  control: _CustomDropdown<ExplorerViewMode>(
                    value: mode,
                    items: const [
                      DropdownMenuItem(
                        value: ExplorerViewMode.grid,
                        child: Text('Grid'),
                      ),
                      DropdownMenuItem(
                        value: ExplorerViewMode.list,
                        child: Text('List'),
                      ),
                      DropdownMenuItem(
                        value: ExplorerViewMode.compact,
                        child: Text('Compact'),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) controller.setViewMode(val);
                    },
                  ),
                );
              }),
            _CustomDivider(),
            if (controller != null)
              Obx(() {
                return _CustomSettingRow(
                  title: 'Show sidebar',
                  subtitle: 'Show quick access folders, places, and disk drives on the left.',
                  control: _CustomSwitch(
                    value: controller.showSidebar.value,
                    onChanged: (_) => controller.toggleSidebar(),
                  ),
                );
              }),
            _CustomDivider(),
            _CustomSettingRow(
              title: 'Show storage usage bar',
              subtitle: 'Display total and available capacity bars underneath mounted drives.',
              control: _CustomSwitch(value: true, onChanged: (_) {}),
            ),
            _CustomDivider(),
            Obx(() {
              return _CustomSettingRow(
                title: 'Show preview panel',
                subtitle: 'Display file preview in right sidebar when selecting files.',
                control: _CustomSwitch(
                  value: _themeService.previewEnabled.value,
                  onChanged: (val) => _themeService.previewEnabled.value = val,
                ),
              );
            }),
          ],
        ),
      ],
    );
  }

  // ==========================================
  // Files and Links Section
  // ==========================================
  Widget _buildFilesAndLinksSection() {
    final controller = _explorerController;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('File Operations'),
        const SizedBox(height: 8),

        _CustomSectionCard(
          children: [
            _CustomSettingRow(
              title: 'Confirm before moving to trash',
              subtitle: 'Show a confirmation alert before moving selected files to trash.',
              control: _CustomSwitch(
                value: _confirmTrash,
                onChanged: (val) => _update(() => _confirmTrash = val),
              ),
            ),
            _CustomDivider(),
            _CustomSettingRow(
              title: 'Default terminal application',
              subtitle: 'Terminal emulator launched when pressing F4 or clicking terminal icon.',
              control: _CustomDropdown<String>(
                value: _terminalChoice,
                items: const [
                  DropdownMenuItem(
                    value: 'System default',
                    child: Text('System default'),
                  ),
                  DropdownMenuItem(
                    value: 'gnome-terminal',
                    child: Text('gnome-terminal'),
                  ),
                  DropdownMenuItem(
                    value: 'x-terminal-emulator',
                    child: Text('x-terminal-emulator'),
                  ),
                  DropdownMenuItem(
                    value: 'kitty / alacritty',
                    child: Text('kitty / alacritty'),
                  ),
                ],
                onChanged: (val) {
                  if (val != null) _update(() => _terminalChoice = val);
                },
              ),
            ),
            if (controller != null) ...[
              _CustomDivider(),
              Obx(
                () => _CustomSettingRow(
                  title: 'Home directory',
                  subtitle: controller.homePath.value,
                  control: _CustomButton(
                    label: 'Open',
                    onTap: () {
                      controller.navigateTo(controller.homePath.value);
                      Navigator.of(context).pop();
                    },
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  // ==========================================
  // Hotkeys Section
  // ==========================================
  Widget _buildHotkeysSection() {
    const shortcuts = [
      ('Toggle sidebar', 'Ctrl + B'),
      ('Search files in directory', 'Ctrl + F'),
      ('New directory', 'Ctrl + Shift + N'),
      ('Open terminal in current path', 'F4'),
      ('Refresh directory', 'F5 / Ctrl + R'),
      ('Rename active item', 'F2'),
      ('Move to trash', 'Delete'),
      ('Permanent delete', 'Shift + Delete'),
      ('Select all', 'Ctrl + A'),
      ('Copy to clipboard', 'Ctrl + C'),
      ('Cut to clipboard', 'Ctrl + X'),
      ('Paste from clipboard', 'Ctrl + V'),
      ('Parent directory', 'Alt + Up'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Keyboard Shortcuts'),
        const SizedBox(height: 8),

        _CustomSectionCard(
          children: [
            for (int i = 0; i < shortcuts.length; i++) ...[
              if (i > 0) _CustomDivider(),
              _CustomSettingRow(
                title: shortcuts[i].$1,
                control: _buildHotkeyBadge(shortcuts[i].$2),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildHotkeyBadge(String keys) {
    final parts = keys.split(' ');

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final part in parts)
          if (part == '+' || part == '/')
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                part,
                style: TextStyle(fontSize: 11, color: context.colors.textFaint),
              ),
            )
          else
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: context.colors.chip,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: context.colors.chipBorder),
              ),
              child: Text(
                part,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: context.colors.textLabel,
                ),
              ),
            ),
      ],
    );
  }

  Widget _buildThemeSearchField() {
    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: context.colors.input,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: context.colors.cardBorder),
      ),
      child: Row(
        children: [
          Icon(Icons.search, size: 13, color: context.colors.textFaint),
          const SizedBox(width: 6),
          Expanded(
            child: TextField(
              controller: _themeSearchController,
              onChanged: (val) =>
                  _update(() => _themeQuery = val.trim().toLowerCase()),
              cursorHeight: 12,
              style: TextStyle(
                fontSize: 11.5,
                color: context.colors.textPrimary,
              ),
              decoration: InputDecoration(
                isDense: true,
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                hintText: 'Search icon themes...',
                hintStyle: TextStyle(
                  fontSize: 11.5,
                  color: context.colors.textFaint,
                ),
              ),
            ),
          ),
          if (_themeQuery.isNotEmpty)
            GestureDetector(
              onTap: () {
                _themeSearchController.clear();
                _update(() => _themeQuery = '');
              },
              child: Icon(
                Icons.close,
                size: 12,
                color: context.colors.textFaint,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCustomThemeList() {
    final String selected = _iconService.themeName.value;
    final List<_ThemeChoice> choices = [
      _ThemeChoice(name: '', path: null),
      for (final theme in _iconService.themes)
        if (_themeQuery.isEmpty ||
            theme.name.toLowerCase().contains(_themeQuery))
          _ThemeChoice(name: theme.name, path: theme.path),
    ];

    if (_iconService.themes.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'No installed icon themes found.',
            style: TextStyle(fontSize: 12, color: context.colors.textSecondary),
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      itemCount: choices.length,
      itemBuilder: (context, index) {
        final choice = choices[index];
        return _CustomThemeRow(
          choice: choice,
          selected: choice.name == selected,
          onTap: () => _selectIconTheme(choice.name),
        );
      },
    );
  }

  Widget _buildFontSearchField() {
    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: context.colors.input,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: context.colors.cardBorder),
      ),
      child: Row(
        children: [
          Icon(Icons.search, size: 13, color: context.colors.textFaint),
          const SizedBox(width: 6),
          Expanded(
            child: TextField(
              controller: _fontSearchController,
              onChanged: (val) =>
                  _update(() => _fontQuery = val.trim().toLowerCase()),
              cursorHeight: 12,
              style: TextStyle(
                fontSize: 11.5,
                color: context.colors.textPrimary,
              ),
              decoration: InputDecoration(
                isDense: true,
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                hintText: 'Search fonts...',
                hintStyle: TextStyle(
                  fontSize: 11.5,
                  color: context.colors.textFaint,
                ),
              ),
            ),
          ),
          if (_fontQuery.isNotEmpty)
            GestureDetector(
              onTap: () {
                _fontSearchController.clear();
                _update(() => _fontQuery = '');
              },
              child: Icon(
                Icons.close,
                size: 12,
                color: context.colors.textFaint,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCustomFontList() {
    final String selected = _fontService.fontFamily.value;
    final List<String> filtered = [
      '',
      for (final font in _fontService.fonts)
        if (_fontQuery.isEmpty || font.toLowerCase().contains(_fontQuery)) font,
    ];

    if (_fontService.isLoading.value && _fontService.fonts.isEmpty) {
      return ListView(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        children: [
          _CustomFontRow(
            fontName: '',
            isDefault: true,
            selected: selected.isEmpty,
            onTap: () => _selectFont(''),
          ),
          const Padding(
            padding: EdgeInsets.all(10),
            child: Center(
              child: SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final String fontName = filtered[index];
        final bool isDefault = fontName.isEmpty;
        final bool isSelected = fontName == selected;

        return _CustomFontRow(
          fontName: fontName,
          isDefault: isDefault,
          selected: isSelected,
          onTap: () => _selectFont(fontName),
        );
      },
    );
  }

  // ==========================================
  // Helpers
  // ==========================================
  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: context.colors.textPrimary,
      ),
    );
  }

  void _showInfoMessage(String title, String message) {
    showAppToast(title: title, message: message);
  }

  Future<void> _selectIconTheme(String name) async {
    await _iconService.setTheme(name);
    if (!mounted) return;

    showAppToast(
      title: 'Icon theme changed',
      message: name.isEmpty ? 'Application default' : name,
      variant: AppToastVariant.success,
    );
  }

  Future<void> _selectFont(String fontName) async {
    await _fontService.setFont(fontName);
    if (!mounted) return;

    showAppToast(
      title: 'Font changed',
      message: fontName.isEmpty ? 'Application default' : fontName,
      variant: AppToastVariant.success,
    );
  }

  Future<void> _selectBaseTheme(String id) async {
    await _themeService.setBaseTheme(id);
    if (!mounted) return;

    showAppToast(
      title: 'Theme changed',
      message: AppPalettes.byId(id).label,
      variant: AppToastVariant.success,
    );
  }

  Future<void> _selectAccent(String id) async {
    await _themeService.setAccent(id);
    if (!mounted) return;

    showAppToast(
      title: 'Accent changed',
      message: AppAccents.byId(id).label,
      variant: AppToastVariant.success,
    );
  }
}
