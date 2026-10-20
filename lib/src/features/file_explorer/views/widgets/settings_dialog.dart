import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../theme/app_theme.dart';
import '../../../../theme/theme_palette.dart';
import '../../controllers/file_explorer_controller.dart';
import '../../services/font_service.dart';
import '../../services/icon_theme_service.dart';
import '../../services/theme_service.dart';
import '../../utils/app_toast.dart';
import 'entry_glyphs.dart';
import 'themed_icon.dart';

/// Sections available in the settings popup.
enum SettingsSection { appearance, interface, filesAndLinks, hotkeys, about }

class _SidebarItemDef {
  const _SidebarItemDef({
    required this.section,
    required this.label,
    required this.icon,
    required this.category,
    this.keywords = const [],
  });

  final SettingsSection section;
  final String label;
  final IconData icon;
  final String category;
  final List<String> keywords;
}

const List<_SidebarItemDef> _allSidebarItems = [
  // Options
  _SidebarItemDef(
    section: SettingsSection.appearance,
    label: 'Appearance',
    icon: Icons.palette_outlined,
    category: 'Options',
    keywords: [
      'appearance',
      'theme',
      'icon',
      'font',
      'color',
      'accent',
      'display',
    ],
  ),
  _SidebarItemDef(
    section: SettingsSection.interface,
    label: 'Interface',
    icon: Icons.desktop_windows_outlined,
    category: 'Options',
    keywords: [
      'interface',
      'view',
      'grid',
      'list',
      'compact',
      'sidebar',
      'disk',
      'layout',
    ],
  ),
  _SidebarItemDef(
    section: SettingsSection.filesAndLinks,
    label: 'Files and links',
    icon: Icons.folder_open_outlined,
    category: 'Options',
    keywords: [
      'files',
      'links',
      'trash',
      'terminal',
      'home',
      'delete',
      'directory',
    ],
  ),
  _SidebarItemDef(
    section: SettingsSection.hotkeys,
    label: 'Hotkeys',
    icon: Icons.keyboard_outlined,
    category: 'Options',
    keywords: ['hotkeys', 'shortcuts', 'keyboard', 'bindings', 'keys'],
  ),
  _SidebarItemDef(
    section: SettingsSection.about,
    label: 'About',
    icon: Icons.account_circle_outlined,
    category: 'Options',
    keywords: [
      'general',
      'version',
      'update',
      'language',
      'account',
      'license',
      'advanced',
      'startup',
      'help',
    ],
  ),
];

class SettingsDialog extends StatefulWidget {
  const SettingsDialog({super.key});

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _themeSearchController = TextEditingController();
  final TextEditingController _fontSearchController = TextEditingController();

  SettingsSection _activeSection = SettingsSection.about;
  String _searchQuery = '';
  String _themeQuery = '';
  String _fontQuery = '';

  // Setting states
  bool _confirmTrash = true;
  String _terminalChoice = 'System default';

  IconThemeService get _iconService => Get.find<IconThemeService>();
  FontService get _fontService => Get.find<FontService>();
  ThemeService get _themeService => Get.find<ThemeService>();
  FileExplorerController? get _explorerController =>
      Get.isRegistered<FileExplorerController>()
      ? Get.find<FileExplorerController>()
      : null;

  @override
  void initState() {
    super.initState();
    // Services already warm these up at startup. Only refresh when empty, and
    // never block the first frame: the dialog should open instantly.
    Future.microtask(() {
      if (_iconService.themes.isEmpty) _iconService.refreshThemes();
      if (Get.isRegistered<FontService>() && _fontService.fonts.isEmpty) {
        _fontService.refreshFonts();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _themeSearchController.dispose();
    _fontSearchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    setState(() {
      _searchQuery = value.trim().toLowerCase();
    });
  }

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.sizeOf(context);
    final double dialogWidth = (screenSize.width * 0.86).clamp(760.0, 940.0);
    final double dialogHeight = (screenSize.height * 0.84).clamp(500.0, 680.0);

    return Obx(() {
      _themeService.baseThemeId.value;
      _themeService.accentId.value;

      return Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        shape: const RoundedRectangleBorder(),
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Center(
          child: Container(
            width: dialogWidth,
            height: dialogHeight,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: AppColors.windowDeep,
              borderRadius: BorderRadius.circular(10),
              boxShadow: const [
                BoxShadow(
                  color: Color(0xA6000000),
                  blurRadius: 36,
                  offset: Offset(0, 14),
                ),
              ],
            ),
            foregroundDecoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.cardBorder, width: 1),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Left Sidebar
                SizedBox(width: 235, child: _buildSidebar()),

                // Vertical Border Divider
                Container(width: 1, color: AppColors.divider),

                // Right Content Panel
                Expanded(
                  child: Stack(
                    children: [
                      Positioned.fill(child: _buildContentPanel()),
                      // Close button at top right
                      Positioned(
                        top: 14,
                        right: 18,
                        child: _CloseButton(
                          onTap: () => Navigator.of(context).pop(),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }

  // ==========================================
  // Left Sidebar
  // ==========================================
  Widget _buildSidebar() {
    final Map<String, List<_SidebarItemDef>> grouped = {};

    for (final item in _allSidebarItems) {
      if (_searchQuery.isNotEmpty) {
        final bool labelMatches = item.label.toLowerCase().contains(
          _searchQuery,
        );
        final bool categoryMatches = item.category.toLowerCase().contains(
          _searchQuery,
        );
        final bool keywordMatches = item.keywords.any(
          (k) => k.toLowerCase().contains(_searchQuery),
        );

        if (!labelMatches && !categoryMatches && !keywordMatches) {
          continue;
        }
      }

      grouped.putIfAbsent(item.category, () => []).add(item);
    }

    return Container(
      color: AppColors.sidebarDeep,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top Search Field
          _buildSearchField(),
          const SizedBox(height: 14),

          // Scrollable Sidebar Navigation
          Expanded(
            child: grouped.isEmpty
                ? Center(
                    child: Text(
                      'No matching settings',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textFaint,
                      ),
                    ),
                  )
                : ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      for (final entry in grouped.entries) ...[
                        _buildCategoryHeader(entry.key),
                        const SizedBox(height: 4),
                        for (final item in entry.value) ...[
                          _buildSidebarItem(item),
                        ],
                        const SizedBox(height: 14),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.input,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.inputBorder, width: 1),
      ),
      child: Row(
        children: [
          Icon(Icons.search, size: 14, color: AppColors.textFaint),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              cursorHeight: 14,
              cursorColor: AppColors.accent,
              style: TextStyle(fontSize: 12, color: AppColors.textPrimary),
              decoration: InputDecoration(
                isDense: true,
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                hintText: 'Search settings...',
                hintStyle: TextStyle(fontSize: 12, color: AppColors.textFaint),
              ),
            ),
          ),
          if (_searchQuery.isNotEmpty)
            GestureDetector(
              onTap: () {
                _searchController.clear();
                _onSearchChanged('');
              },
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: Padding(
                  padding: EdgeInsets.all(2),
                  child: Icon(
                    Icons.close,
                    size: 13,
                    color: AppColors.textFaint,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCategoryHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 6, bottom: 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          color: AppColors.textFaint,
        ),
      ),
    );
  }

  Widget _buildSidebarItem(_SidebarItemDef item) {
    final bool active = _activeSection == item.section;

    return _SidebarItemWidget(
      label: item.label,
      icon: item.icon,
      active: active,
      onTap: () {
        setState(() {
          _activeSection = item.section;
        });
      },
    );
  }

  // ==========================================
  // Right Content Panel
  // ==========================================
  Widget _buildContentPanel() {
    return Container(
      color: AppColors.panel,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(28, 22, 28, 36),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            switch (_activeSection) {
              SettingsSection.appearance => _buildAppearanceSection(),
              SettingsSection.interface => _buildInterfaceSection(),
              SettingsSection.filesAndLinks => _buildFilesAndLinksSection(),
              SettingsSection.hotkeys => _buildHotkeysSection(),
              SettingsSection.about => _buildAboutSection(),
            },
          ],
        ),
      ),
    );
  }

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
            //       if (val != null) setState(() => _selectedLanguage = val);
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
                        color: AppColors.chip,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: AppColors.chipBorder),
                      ),
                      child: Text(
                        display,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: AppColors.accent,
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
                        color: AppColors.chip,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: AppColors.chipBorder),
                      ),
                      child: Text(
                        display,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: AppColors.accent,
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
                          activeTrackColor: AppColors.accent,
                          inactiveTrackColor: AppColors.elevated,
                          thumbColor: AppColors.accent,
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
                        color: AppColors.elevated,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: AppColors.elevatedBorder),
                      ),
                      child: Text(
                        '${(scale * 100).round()}%',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.accent,
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
                onChanged: (val) => setState(() => _confirmTrash = val),
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
                  if (val != null) setState(() => _terminalChoice = val);
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
                style: TextStyle(fontSize: 11, color: AppColors.textFaint),
              ),
            )
          else
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.chip,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: AppColors.chipBorder),
              ),
              child: Text(
                part,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textLabel,
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
        color: AppColors.input,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: [
          Icon(Icons.search, size: 13, color: AppColors.textFaint),
          const SizedBox(width: 6),
          Expanded(
            child: TextField(
              controller: _themeSearchController,
              onChanged: (val) =>
                  setState(() => _themeQuery = val.trim().toLowerCase()),
              cursorHeight: 12,
              style: TextStyle(fontSize: 11.5, color: AppColors.textPrimary),
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
                  color: AppColors.textFaint,
                ),
              ),
            ),
          ),
          if (_themeQuery.isNotEmpty)
            GestureDetector(
              onTap: () {
                _themeSearchController.clear();
                setState(() => _themeQuery = '');
              },
              child: Icon(Icons.close, size: 12, color: AppColors.textFaint),
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
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
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
        color: AppColors.input,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: [
          Icon(Icons.search, size: 13, color: AppColors.textFaint),
          const SizedBox(width: 6),
          Expanded(
            child: TextField(
              controller: _fontSearchController,
              onChanged: (val) =>
                  setState(() => _fontQuery = val.trim().toLowerCase()),
              cursorHeight: 12,
              style: TextStyle(fontSize: 11.5, color: AppColors.textPrimary),
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
                  color: AppColors.textFaint,
                ),
              ),
            ),
          ),
          if (_fontQuery.isNotEmpty)
            GestureDetector(
              onTap: () {
                _fontSearchController.clear();
                setState(() => _fontQuery = '');
              },
              child: Icon(Icons.close, size: 12, color: AppColors.textFaint),
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
        color: AppColors.textPrimary,
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

class _SidebarItemWidget extends StatefulWidget {
  const _SidebarItemWidget({
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  @override
  State<_SidebarItemWidget> createState() => _SidebarItemWidgetState();
}

class _SidebarItemWidgetState extends State<_SidebarItemWidget> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final Color bgColor = widget.active
        ? AppColors.rowSelected
        : (_hovered ? AppColors.rowHover : Colors.transparent);

    final Color contentColor = widget.active
        ? AppColors.textStrong
        : (_hovered ? AppColors.textLabel : AppColors.textSecondary);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          height: 31,
          margin: const EdgeInsets.symmetric(vertical: 1),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(5),
          ),
          child: Row(
            children: [
              Icon(widget.icon, size: 15, color: contentColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: widget.active
                        ? FontWeight.w500
                        : FontWeight.w400,
                    color: contentColor,
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

class _CustomSectionCard extends StatelessWidget {
  const new({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.cardBorder, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}

class _CustomDivider extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    return Container(height: 1, color: AppColors.chip);
  }
}

class _CustomSettingRow extends StatelessWidget {
  const new({
    required this.title,
    this.subtitle,
    this.linkText,
    this.onLinkTap,
    required this.control,
  });

  final String title;
  final String? subtitle;
  final String? linkText;
  final VoidCallback? onLinkTap;
  final Widget control;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textStrong,
                  ),
                ),
                if (subtitle != null && subtitle!.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    subtitle!,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: AppColors.textSecondary,
                      height: 1.35,
                    ),
                  ),
                ],
                if (linkText != null && linkText!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: onLinkTap,
                      child: Text(
                        linkText!,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: AppColors.textSecondary,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 16),
          control,
        ],
      ),
    );
  }
}

class _CustomButton extends StatefulWidget {
  const new({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  State<_CustomButton> createState() => _CustomButtonState();
}

class _CustomButtonState extends State<_CustomButton> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final Color bgColor = _pressed
        ? AppColors.rowHover
        : _hovered
        ? AppColors.elevatedHover
        : AppColors.elevated;

    final Color borderColor = _hovered
        ? AppColors.elevatedBorderHover
        : AppColors.elevatedBorder;

    final Color textColor = _hovered
        ? AppColors.textStrong
        : AppColors.textLabel;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() {
        _hovered = false;
        _pressed = false;
      }),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(5),
            border: Border.all(color: borderColor, width: 1),
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: textColor,
            ),
          ),
        ),
      ),
    );
  }
}

class _CustomSwitch extends StatelessWidget {
  const new({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => onChanged(!value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeInOut,
          width: 34,
          height: 19,
          padding: const EdgeInsets.all(2.5),
          decoration: BoxDecoration(
            color: value ? AppColors.accent : AppColors.switchTrack,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: value ? AppColors.selectionBorder : AppColors.chipBorder,
              width: 1,
            ),
          ),
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: value ? Colors.white : AppColors.textFaint,
              boxShadow: const [
                BoxShadow(
                  color: Color(0x4D000000),
                  blurRadius: 2,
                  offset: Offset(0, 1),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CustomDropdown<T> extends StatefulWidget {
  const _CustomDropdown({
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  @override
  State<_CustomDropdown<T>> createState() => _CustomDropdownState<T>();
}

class _CustomDropdownState<T> extends State<_CustomDropdown<T>> {
  final MenuController _menuController = MenuController();

  @override
  Widget build(BuildContext context) {
    final DropdownMenuItem<T> selectedItem = widget.items.firstWhere(
      (item) => item.value == widget.value,
      orElse: () => widget.items.first,
    );

    return MenuAnchor(
      controller: _menuController,
      alignmentOffset: const Offset(0, 4),
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(AppColors.menu),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        shadowColor: WidgetStatePropertyAll(
          Colors.black.withValues(alpha: 0.5),
        ),
        elevation: const WidgetStatePropertyAll(10),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        ),
        minimumSize: const WidgetStatePropertyAll(Size(248, 0)),
        maximumSize: const WidgetStatePropertyAll(Size(248, 360)),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        side: WidgetStatePropertyAll(BorderSide(color: AppColors.menuBorder)),
      ),
      menuChildren: [
        for (final item in widget.items)
          MenuItemButton(
            onPressed: item.enabled
                ? () {
                    _menuController.close();
                    widget.onChanged(item.value);
                  }
                : null,
            style: ButtonStyle(
              padding: const WidgetStatePropertyAll(EdgeInsets.zero),
              minimumSize: const WidgetStatePropertyAll(Size(0, 30)),
              maximumSize: const WidgetStatePropertyAll(
                Size(double.infinity, 30),
              ),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
              overlayColor: const WidgetStatePropertyAll(Colors.transparent),
              backgroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.hovered) ||
                    states.contains(WidgetState.focused)) {
                  return AppColors.surfaceHigh;
                }
                return Colors.transparent;
              }),
              shape: WidgetStatePropertyAll(
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  SizedBox(
                    width: 16,
                    child: item.value == widget.value
                        ? Icon(
                            Icons.check_rounded,
                            size: 14,
                            color: AppColors.accent,
                          )
                        : null,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DefaultTextStyle.merge(
                      style: TextStyle(
                        fontSize: 12.5,
                        color: item.enabled
                            ? AppColors.menuLabel
                            : AppColors.textFaint.withValues(alpha: 0.5),
                      ),
                      child: item.child,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
      builder: (context, controller, child) {
        return GestureDetector(
          onTap: () {
            if (controller.isOpen) {
              controller.close();
            } else {
              controller.open();
            }
          },
          child: Container(
            height: 30,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: AppColors.elevated,
              borderRadius: BorderRadius.circular(5),
              border: Border.all(color: AppColors.elevatedBorder, width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                DefaultTextStyle.merge(
                  style: TextStyle(fontSize: 12, color: AppColors.textLabel),
                  child: selectedItem.child,
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: Icon(
                    Icons.unfold_more,
                    size: 14,
                    color: AppColors.textFaint,
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

class _CloseButton extends StatefulWidget {
  const _CloseButton({required this.onTap});

  final VoidCallback onTap;

  @override
  State<_CloseButton> createState() => _CloseButtonState();
}

class _CloseButtonState extends State<_CloseButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: _hovered ? AppColors.elevatedHover : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Icon(
            Icons.close,
            size: 15,
            color: _hovered ? AppColors.textStrong : AppColors.textFaint,
          ),
        ),
      ),
    );
  }
}

class _ColorDot extends StatelessWidget {
  const _ColorDot({
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: isSelected ? AppColors.textStrong : Colors.transparent,
              width: 2,
            ),
          ),
        ),
      ),
    );
  }
}

// =====================================================================
// Theme & Font Option Rows
// =====================================================================

class _ThemeChoice {
  _ThemeChoice({required this.name, required this.path});

  final String name;
  final String? path;
}

class _CustomThemeRow extends StatefulWidget {
  const new({
    required this.choice,
    required this.selected,
    required this.onTap,
  });

  final _ThemeChoice choice;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_CustomThemeRow> createState() => _CustomThemeRowState();
}

class _CustomThemeRowState extends State<_CustomThemeRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final bool isDefault = widget.choice.name.isEmpty;

    final Widget preview = isDefault
        ? const Center(child: FolderGlyph(width: 20, height: 16))
        : ThemedIcon(
            iconNames: const ['folder', 'inode-directory'],
            size: 18,
            theme: widget.choice.name,
            fallback: Icon(Icons.folder, size: 16, color: AppColors.textFaint),
          );

    final Widget row = Container(
      height: 30,
      margin: const EdgeInsets.symmetric(vertical: 1),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: widget.selected
            ? AppColors.rowSelected
            : _hovered
            ? AppColors.rowHover
            : Colors.transparent,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          SizedBox(width: 22, child: preview),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isDefault ? 'Application default' : widget.choice.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: widget.selected
                    ? AppColors.textStrong
                    : AppColors.textLabel,
                fontWeight: widget.selected ? FontWeight.w500 : FontWeight.w400,
              ),
            ),
          ),
          if (widget.selected)
            Icon(Icons.check, size: 14, color: AppColors.accent),
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

class _CustomFontRow extends StatefulWidget {
  const new({
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
  State<_CustomFontRow> createState() => _CustomFontRowState();
}

class _CustomFontRowState extends State<_CustomFontRow> {
  bool _hovered = false;
  bool _previewReady = false;

  @override
  void initState() {
    super.initState();
    // Paint the row immediately with the default font, then swap in the
    // preview typeface next frame. Avoids a visible stall on first open while
    // the engine loads each font.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _previewReady = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final String label = widget.isDefault
        ? 'Application default'
        : widget.fontName;
    final String? previewFamily = widget.isDefault || !_previewReady
        ? null
        : widget.fontName;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          height: 30,
          margin: const EdgeInsets.symmetric(vertical: 1),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: widget.selected
                ? AppColors.rowSelected
                : _hovered
                ? AppColors.rowHover
                : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            children: [
              Container(
                width: 22,
                height: 22,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.chip,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Aa',
                  style: TextStyle(
                    fontFamily: previewFamily,
                    fontSize: 10.5,
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
                    fontSize: 12,
                    color: widget.selected
                        ? AppColors.textStrong
                        : AppColors.textLabel,
                    fontWeight: widget.selected
                        ? FontWeight.w500
                        : FontWeight.w400,
                  ),
                ),
              ),
              if (widget.selected)
                Icon(Icons.check, size: 14, color: AppColors.accent),
            ],
          ),
        ),
      ),
    );
  }
}
