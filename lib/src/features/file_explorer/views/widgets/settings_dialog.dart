import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../theme/app_theme.dart';
import '../../../../theme/theme_palette.dart';
import '../../controllers/file_explorer_controller.dart';
import '../../services/font_service.dart';
import '../../services/icon_theme_service.dart';
import '../../services/theme_service.dart';
import 'entry_glyphs.dart';
import 'themed_icon.dart';

/// Sections available in the settings popup.
enum SettingsSection {
  general,
  appearance,
  interface,
  editor,
  filesAndLinks,
  hotkeys,
  keychain,
  corePlugins,
  communityPlugins,
  // Core plugins
  backlinks,
  canvas,
  commandPalette,
  dailyNotes,
  fileRecovery,
  noteComposer,
  pagePreview,
  quickSwitcher,
  sync,
  templates,
  // Community plugins
  projectManager,
}

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
    section: SettingsSection.general,
    label: 'General',
    icon: Icons.account_circle_outlined,
    category: 'Options',
    keywords: ['general', 'version', 'update', 'language', 'account', 'license', 'advanced', 'startup', 'help'],
  ),
  _SidebarItemDef(
    section: SettingsSection.appearance,
    label: 'Appearance',
    icon: Icons.palette_outlined,
    category: 'Options',
    keywords: ['appearance', 'theme', 'icon', 'font', 'color', 'accent', 'display'],
  ),
  _SidebarItemDef(
    section: SettingsSection.interface,
    label: 'Interface',
    icon: Icons.desktop_windows_outlined,
    category: 'Options',
    keywords: ['interface', 'view', 'grid', 'list', 'compact', 'sidebar', 'disk', 'layout'],
  ),
  _SidebarItemDef(
    section: SettingsSection.editor,
    label: 'Editor',
    icon: Icons.edit_outlined,
    category: 'Options',
    keywords: ['editor', 'text', 'line', 'wrap', 'code'],
  ),
  _SidebarItemDef(
    section: SettingsSection.filesAndLinks,
    label: 'Files and links',
    icon: Icons.folder_open_outlined,
    category: 'Options',
    keywords: ['files', 'links', 'trash', 'terminal', 'home', 'delete', 'directory'],
  ),
  _SidebarItemDef(
    section: SettingsSection.hotkeys,
    label: 'Hotkeys',
    icon: Icons.keyboard_outlined,
    category: 'Options',
    keywords: ['hotkeys', 'shortcuts', 'keyboard', 'bindings', 'keys'],
  ),
  _SidebarItemDef(
    section: SettingsSection.keychain,
    label: 'Keychain',
    icon: Icons.vpn_key_outlined,
    category: 'Options',
    keywords: ['keychain', 'security', 'credentials', 'password'],
  ),
  _SidebarItemDef(
    section: SettingsSection.corePlugins,
    label: 'Core plugins',
    icon: Icons.inventory_2_outlined,
    category: 'Options',
    keywords: ['plugins', 'core', 'extensions'],
  ),
  _SidebarItemDef(
    section: SettingsSection.communityPlugins,
    label: 'Community plugins',
    icon: Icons.extension_outlined,
    category: 'Options',
    keywords: ['community', 'plugins', 'marketplace', 'third-party'],
  ),

  // Core plugins
  _SidebarItemDef(
    section: SettingsSection.backlinks,
    label: 'Backlinks',
    icon: Icons.call_split_outlined,
    category: 'Core plugins',
    keywords: ['backlinks', 'links', 'references'],
  ),
  _SidebarItemDef(
    section: SettingsSection.canvas,
    label: 'Canvas',
    icon: Icons.grid_view_outlined,
    category: 'Core plugins',
    keywords: ['canvas', 'board', 'visual', 'cards'],
  ),
  _SidebarItemDef(
    section: SettingsSection.commandPalette,
    label: 'Command palette',
    icon: Icons.terminal_outlined,
    category: 'Core plugins',
    keywords: ['command', 'palette', 'terminal', 'prompt'],
  ),
  _SidebarItemDef(
    section: SettingsSection.dailyNotes,
    label: 'Daily notes',
    icon: Icons.calendar_today_outlined,
    category: 'Core plugins',
    keywords: ['daily', 'notes', 'calendar', 'journal'],
  ),
  _SidebarItemDef(
    section: SettingsSection.fileRecovery,
    label: 'File recovery',
    icon: Icons.history_outlined,
    category: 'Core plugins',
    keywords: ['recovery', 'history', 'snapshots', 'backup'],
  ),
  _SidebarItemDef(
    section: SettingsSection.noteComposer,
    label: 'Note composer',
    icon: Icons.note_add_outlined,
    category: 'Core plugins',
    keywords: ['composer', 'merge', 'split', 'notes'],
  ),
  _SidebarItemDef(
    section: SettingsSection.pagePreview,
    label: 'Page preview',
    icon: Icons.visibility_outlined,
    category: 'Core plugins',
    keywords: ['preview', 'hover', 'tooltip', 'page'],
  ),
  _SidebarItemDef(
    section: SettingsSection.quickSwitcher,
    label: 'Quick switcher',
    icon: Icons.find_in_page_outlined,
    category: 'Core plugins',
    keywords: ['quick', 'switcher', 'jump', 'fuzzy', 'search'],
  ),
  _SidebarItemDef(
    section: SettingsSection.sync,
    label: 'Sync',
    icon: Icons.sync_outlined,
    category: 'Core plugins',
    keywords: ['sync', 'cloud', 'backup', 'remote'],
  ),
  _SidebarItemDef(
    section: SettingsSection.templates,
    label: 'Templates',
    icon: Icons.description_outlined,
    category: 'Core plugins',
    keywords: ['templates', 'snippets', 'boilerplate'],
  ),

  // Community plugins
  _SidebarItemDef(
    section: SettingsSection.projectManager,
    label: 'Project Manager',
    icon: Icons.folder_special_outlined,
    category: 'Community plugins',
    keywords: ['project', 'manager', 'workspaces', 'bookmarks'],
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

  SettingsSection _activeSection = SettingsSection.general;
  String _searchQuery = '';
  String _themeQuery = '';
  String _fontQuery = '';

  // Setting states
  bool _automaticUpdates = false;
  String _selectedLanguage = 'English';
  bool _notifyStartup = false;
  bool _hardwareAcceleration = true;
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
    _iconService.refreshThemes();
    if (Get.isRegistered<FontService>()) {
      _fontService.refreshFonts();
    }
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
    final double dialogWidth =
        (screenSize.width * 0.86).clamp(760.0, 940.0);
    final double dialogHeight =
        (screenSize.height * 0.84).clamp(500.0, 680.0);

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
                SizedBox(
                  width: 235,
                  child: _buildSidebar(),
                ),

                // Vertical Border Divider
                Container(
                  width: 1,
                  color: AppColors.divider,
                ),

                // Right Content Panel
                Expanded(
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: _buildContentPanel(),
                      ),
                      // Close button at top right
                      Positioned(
                        top: 14,
                        right: 18,
                        child: _CloseButton(onTap: () => Navigator.of(context).pop()),
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
        final bool labelMatches = item.label.toLowerCase().contains(_searchQuery);
        final bool categoryMatches = item.category.toLowerCase().contains(_searchQuery);
        final bool keywordMatches =
            item.keywords.any((k) => k.toLowerCase().contains(_searchQuery));

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
              style: TextStyle(
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
                hintText: 'Search settings...',
                hintStyle: TextStyle(
                  fontSize: 12,
                  color: AppColors.textFaint,
                ),
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
                  child: Icon(Icons.close, size: 13, color: AppColors.textFaint),
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
              SettingsSection.general => _buildGeneralSection(),
              SettingsSection.appearance => _buildAppearanceSection(),
              SettingsSection.interface => _buildInterfaceSection(),
              SettingsSection.filesAndLinks => _buildFilesAndLinksSection(),
              SettingsSection.hotkeys => _buildHotkeysSection(),
              _ => _buildGenericPluginSection(),
            },
          ],
        ),
      ),
    );
  }

  // ==========================================
  // General Section (Exact Match to Screenshot)
  // ==========================================
  Widget _buildGeneralSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Top Card
        _ObsidianSectionCard(
          children: [
            _ObsidianSettingRow(
              title: 'Version 1.14.4',
              subtitle: 'Installer version: 1.14.4',
              linkText: 'Read the changelog.',
              onLinkTap: () {
                _showInfoMessage('Changelog', 'Defile 1.14.4 introduces custom themes, obsidian styling, and lightning-fast file navigation.');
              },
              control: _ObsidianButton(
                label: 'Check for updates',
                onTap: () {
                  _showInfoMessage('Update Check', 'You are running the latest version of Defile.');
                },
              ),
            ),
            _ObsidianDivider(),
            _ObsidianSettingRow(
              title: 'Automatic updates',
              subtitle: 'Turn this off to prevent the app from checking for updates.',
              control: _ObsidianSwitch(
                value: _automaticUpdates,
                onChanged: (val) => setState(() => _automaticUpdates = val),
              ),
            ),
            _ObsidianDivider(),
            _ObsidianSettingRow(
              title: 'Language',
              subtitle: 'Change the display language.\nLearn how to add a new language to Obsidian.',
              control: _ObsidianDropdown<String>(
                value: _selectedLanguage,
                items: const [
                  DropdownMenuItem(value: 'English', child: Text('English')),
                  DropdownMenuItem(value: 'Bahasa Indonesia', child: Text('Bahasa Indonesia')),
                  DropdownMenuItem(value: '日本語', child: Text('日本語')),
                  DropdownMenuItem(value: 'Deutsch', child: Text('Deutsch')),
                  DropdownMenuItem(value: 'Français', child: Text('Français')),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _selectedLanguage = val);
                },
              ),
            ),
            _ObsidianDivider(),
            _ObsidianSettingRow(
              title: 'Help',
              subtitle: 'Learn how to use Obsidian and get help from the community.',
              control: _ObsidianButton(
                label: 'Open',
                onTap: () {
                  _showInfoMessage('Help & Support', 'Visit docs at https://github.com/Gylmynnn/defile');
                },
              ),
            ),
          ],
        ),

        const SizedBox(height: 22),
        _buildSectionTitle('Account'),
        const SizedBox(height: 8),

        // Account Card
        _ObsidianSectionCard(
          children: [
            _ObsidianSettingRow(
              title: 'Your account',
              subtitle:
                  "You're not logged in right now. An account is only needed for Obsidian Sync,\nObsidian Publish, and early access versions.",
              control: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _ObsidianButton(
                    label: 'Log in',
                    onTap: () => _showInfoMessage('Account', 'Log in feature ready.'),
                  ),
                  const SizedBox(width: 8),
                  _ObsidianButton(
                    label: 'Sign up',
                    onTap: () => _showInfoMessage('Account', 'Sign up feature ready.'),
                  ),
                ],
              ),
            ),
            _ObsidianDivider(),
            _ObsidianSettingRow(
              title: 'Commercial license',
              subtitle: 'Help keep Obsidian 100% user-supported.',
              linkText: 'Learn more',
              onLinkTap: () => _showInfoMessage('License', 'Defile is open-source under MIT/Apache licenses.'),
              control: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _ObsidianButton(
                    label: 'Activate',
                    onTap: () => _showInfoMessage('License', 'Activate commercial key.'),
                  ),
                  const SizedBox(width: 8),
                  _ObsidianButton(
                    label: 'Purchase',
                    onTap: () => _showInfoMessage('License', 'Redirecting to purchase portal.'),
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 22),
        _buildSectionTitle('Advanced'),
        const SizedBox(height: 8),

        // Advanced Card
        _ObsidianSectionCard(
          children: [
            _ObsidianSettingRow(
              title: 'Notify if startup takes longer than expected',
              subtitle:
                  'Diagnose issues with your app by seeing what is causing the app to load slowly.',
              control: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.timer_outlined, size: 16, color: AppColors.textFaint),
                  const SizedBox(width: 8),
                  _ObsidianSwitch(
                    value: _notifyStartup,
                    onChanged: (val) => setState(() => _notifyStartup = val),
                  ),
                ],
              ),
            ),
            _ObsidianDivider(),
            _ObsidianSettingRow(
              title: 'Hardware acceleration',
              subtitle: 'Use GPU acceleration for smoother file rendering and animations.',
              control: _ObsidianSwitch(
                value: _hardwareAcceleration,
                onChanged: (val) => setState(() => _hardwareAcceleration = val),
              ),
            ),
            _ObsidianDivider(),
            _ObsidianSettingRow(
              title: 'Command line interface',
              subtitle: 'Install defile launcher to open folders and files directly from shell.',
              control: _ObsidianButton(
                label: 'Install',
                onTap: () => _showInfoMessage('CLI', 'Defile CLI installed to /usr/local/bin/defile'),
              ),
            ),
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
        _ObsidianSectionCard(
          children: [
            Obx(() {
              final String currentTheme = _iconService.themeName.value;
              final String display =
                  currentTheme.isEmpty ? 'Application default' : currentTheme;

              return _ObsidianSettingRow(
                title: 'Icon theme',
                subtitle:
                    'Icons are loaded from themes installed on this system. Applies across all files and folders.',
                control: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
                    _ObsidianButton(
                      label: 'Scan themes',
                      onTap: _iconService.refreshThemes,
                    ),
                  ],
                ),
              );
            }),
            _ObsidianDivider(),
            Padding(
              padding: const EdgeInsets.all(12),
              child: _buildThemeSearchField(),
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200),
              child: Obx(() => _buildObsidianThemeList()),
            ),
          ],
        ),

        const SizedBox(height: 22),
        _buildSectionTitle('Typography'),
        const SizedBox(height: 8),

        // Display Font Card
        _ObsidianSectionCard(
          children: [
            Obx(() {
              final String currentFont = _fontService.fontFamily.value;
              final String display =
                  currentFont.isEmpty ? 'Application default' : currentFont;

              return _ObsidianSettingRow(
                title: 'Display font',
                subtitle:
                    'Select a font installed on your system. Defile will immediately render with the chosen typeface.',
                control: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
                    _ObsidianButton(
                      label: 'Scan fonts',
                      onTap: _fontService.refreshFonts,
                    ),
                  ],
                ),
              );
            }),
            _ObsidianDivider(),
            Padding(
              padding: const EdgeInsets.all(12),
              child: _buildFontSearchField(),
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200),
              child: Obx(() => _buildObsidianFontList()),
            ),
          ],
        ),

        const SizedBox(height: 22),
        _buildSectionTitle('Colors & Accents'),
        const SizedBox(height: 8),

        _ObsidianSectionCard(
          children: [
            Obx(() {
              final String currentTheme = _themeService.baseThemeId.value;

              return _ObsidianSettingRow(
                title: 'Base color theme',
                subtitle: 'Select the base dark scheme for the whole interface.',
                control: _ObsidianDropdown<String>(
                  value: AppPalettes.byId(currentTheme).id,
                  items: [
                    for (final palette in AppPalettes.all)
                      DropdownMenuItem(
                        value: palette.id,
                        child: Text(palette.label),
                      ),
                  ],
                  onChanged: (val) {
                    if (val != null) _themeService.setBaseTheme(val);
                  },
                ),
              );
            }),
            _ObsidianDivider(),
            Obx(() {
              final String currentAccent = _themeService.accentId.value;

              return _ObsidianSettingRow(
                title: 'Accent color',
                subtitle: 'Color highlight for selections, badges, and focus rings.',
                control: Wrap(
                  spacing: 6,
                  children: [
                    for (final accent in AppAccents.all)
                      _ColorDot(
                        color: accent.color,
                        isSelected: accent.id == currentAccent,
                        onTap: () => _themeService.setAccent(accent.id),
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

        _ObsidianSectionCard(
          children: [
            Obx(() {
              final double scale = _themeService.uiScale.value;

              return _ObsidianSettingRow(
                title: 'Interface scale',
                subtitle:
                    'Enlarge or shrink the whole interface, similar to display scaling on your monitor.',
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
                    _ObsidianButton(
                      label: 'Reset',
                      onTap: () => _themeService.setUiScale(1.0),
                    ),
                  ],
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

        _ObsidianSectionCard(
          children: [
            if (controller != null)
              Obx(() {
                final mode = controller.viewMode.value;

                return _ObsidianSettingRow(
                  title: 'Default layout mode',
                  subtitle: 'Choose how folder items and entries are laid out.',
                  control: _ObsidianDropdown<ExplorerViewMode>(
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
            _ObsidianDivider(),
            if (controller != null)
              Obx(() {
                return _ObsidianSettingRow(
                  title: 'Show sidebar',
                  subtitle: 'Show quick access folders, places, and disk drives on the left.',
                  control: _ObsidianSwitch(
                    value: controller.showSidebar.value,
                    onChanged: (_) => controller.toggleSidebar(),
                  ),
                );
              }),
            _ObsidianDivider(),
            _ObsidianSettingRow(
              title: 'Show storage usage bar',
              subtitle: 'Display total and available capacity bars underneath mounted drives.',
              control: _ObsidianSwitch(
                value: true,
                onChanged: (_) {},
              ),
            ),
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

        _ObsidianSectionCard(
          children: [
            _ObsidianSettingRow(
              title: 'Confirm before moving to trash',
              subtitle: 'Show a confirmation alert before moving selected files to trash.',
              control: _ObsidianSwitch(
                value: _confirmTrash,
                onChanged: (val) => setState(() => _confirmTrash = val),
              ),
            ),
            _ObsidianDivider(),
            _ObsidianSettingRow(
              title: 'Default terminal application',
              subtitle: 'Terminal emulator launched when pressing F4 or clicking terminal icon.',
              control: _ObsidianDropdown<String>(
                value: _terminalChoice,
                items: const [
                  DropdownMenuItem(value: 'System default', child: Text('System default')),
                  DropdownMenuItem(value: 'gnome-terminal', child: Text('gnome-terminal')),
                  DropdownMenuItem(value: 'x-terminal-emulator', child: Text('x-terminal-emulator')),
                  DropdownMenuItem(value: 'kitty / alacritty', child: Text('kitty / alacritty')),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _terminalChoice = val);
                },
              ),
            ),
            if (controller != null) ...[
              _ObsidianDivider(),
              Obx(() => _ObsidianSettingRow(
                    title: 'Home directory',
                    subtitle: controller.homePath.value,
                    control: _ObsidianButton(
                      label: 'Open',
                      onTap: () {
                        controller.navigateTo(controller.homePath.value);
                        Navigator.of(context).pop();
                      },
                    ),
                  )),
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

        _ObsidianSectionCard(
          children: [
            for (int i = 0; i < shortcuts.length; i++) ...[
              if (i > 0) _ObsidianDivider(),
              _ObsidianSettingRow(
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

  // ==========================================
  // Generic Section for Plugins and Other Tabs
  // ==========================================
  Widget _buildGenericPluginSection() {
    final item = _allSidebarItems.firstWhere(
      (element) => element.section == _activeSection,
      orElse: () => _allSidebarItems.first,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(item.label),
        const SizedBox(height: 8),

        _ObsidianSectionCard(
          children: [
            _ObsidianSettingRow(
              title: 'Enable ${item.label}',
              subtitle: 'Turn this on to activate ${item.label} features in Defile.',
              control: _ObsidianSwitch(
                value: true,
                onChanged: (_) {},
              ),
            ),
            _ObsidianDivider(),
            _ObsidianSettingRow(
              title: 'Options',
              subtitle: 'Configure specific settings and keybindings for this module.',
              control: _ObsidianButton(
                label: 'Configure',
                onTap: () => _showInfoMessage(item.label, '${item.label} is currently enabled and active.'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ==========================================
  // Theme & Font Lists in Obsidian Style
  // ==========================================
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
              onChanged: (val) => setState(() => _themeQuery = val.trim().toLowerCase()),
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
                hintStyle: TextStyle(fontSize: 11.5, color: AppColors.textFaint),
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

  Widget _buildObsidianThemeList() {
    final String selected = _iconService.themeName.value;
    final List<_ThemeChoice> choices = [
      _ThemeChoice(name: '', path: null),
      for (final theme in _iconService.themes)
        if (_themeQuery.isEmpty || theme.name.toLowerCase().contains(_themeQuery))
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
        return _ObsidianThemeRow(
          choice: choice,
          selected: choice.name == selected,
          onTap: () => _iconService.setTheme(choice.name),
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
              onChanged: (val) => setState(() => _fontQuery = val.trim().toLowerCase()),
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
                hintStyle: TextStyle(fontSize: 11.5, color: AppColors.textFaint),
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

  Widget _buildObsidianFontList() {
    final String selected = _fontService.fontFamily.value;
    final List<String> filtered = [
      '',
      for (final font in _fontService.fonts)
        if (_fontQuery.isEmpty || font.toLowerCase().contains(_fontQuery))
          font,
    ];

    if (_fontService.isLoading.value && _fontService.fonts.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final String fontName = filtered[index];
        final bool isDefault = fontName.isEmpty;
        final bool isSelected = fontName == selected;

        return _ObsidianFontRow(
          fontName: fontName,
          isDefault: isDefault,
          selected: isSelected,
          onTap: () => _fontService.setFont(fontName),
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
    Get.rawSnackbar(
      title: title,
      message: message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: AppColors.rowHover,
      borderRadius: 8,
      margin: const EdgeInsets.all(16),
      duration: const Duration(seconds: 3),
      borderColor: AppColors.chipBorder,
      borderWidth: 1,
    );
  }
}

// =====================================================================
// Obsidian UI Design System Components
// =====================================================================

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
        ? Colors.white
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
                    fontWeight: widget.active ? FontWeight.w500 : FontWeight.w400,
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

class _ObsidianSectionCard extends StatelessWidget {
  const _ObsidianSectionCard({required this.children});

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

class _ObsidianDivider extends StatelessWidget {
  const _ObsidianDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      color: AppColors.chip,
    );
  }
}

class _ObsidianSettingRow extends StatelessWidget {
  const _ObsidianSettingRow({
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

class _ObsidianButton extends StatefulWidget {
  const _ObsidianButton({
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  State<_ObsidianButton> createState() => _ObsidianButtonState();
}

class _ObsidianButtonState extends State<_ObsidianButton> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final Color bgColor = _pressed
        ? AppColors.rowHover
        : _hovered
            ? AppColors.elevatedHover
            : AppColors.elevated;

    final Color borderColor =
        _hovered ? AppColors.elevatedBorderHover : AppColors.elevatedBorder;

    final Color textColor =
        _hovered ? Colors.white : AppColors.textLabel;

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

class _ObsidianSwitch extends StatelessWidget {
  const _ObsidianSwitch({
    required this.value,
    required this.onChanged,
  });

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

class _ObsidianDropdown<T> extends StatelessWidget {
  const _ObsidianDropdown({
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.elevated,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: AppColors.elevatedBorder, width: 1),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          items: items,
          onChanged: onChanged,
          icon: Padding(
            padding: EdgeInsets.only(left: 6),
            child: Icon(Icons.unfold_more, size: 14, color: AppColors.textFaint),
          ),
          dropdownColor: AppColors.rowHover,
          style: TextStyle(fontSize: 12, color: AppColors.textLabel),
          isDense: true,
          elevation: 4,
          borderRadius: BorderRadius.circular(6),
        ),
      ),
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
            color: _hovered ? Colors.white : AppColors.textFaint,
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
              color: isSelected ? Colors.white : Colors.transparent,
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

class _ObsidianThemeRow extends StatefulWidget {
  const _ObsidianThemeRow({
    required this.choice,
    required this.selected,
    required this.onTap,
  });

  final _ThemeChoice choice;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_ObsidianThemeRow> createState() => _ObsidianThemeRowState();
}

class _ObsidianThemeRowState extends State<_ObsidianThemeRow> {
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
            fallback: Icon(
              Icons.folder,
              size: 16,
              color: AppColors.textFaint,
            ),
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
                color: widget.selected ? Colors.white : AppColors.textLabel,
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

class _ObsidianFontRow extends StatefulWidget {
  const _ObsidianFontRow({
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
  State<_ObsidianFontRow> createState() => _ObsidianFontRowState();
}

class _ObsidianFontRowState extends State<_ObsidianFontRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final String label = widget.isDefault ? 'Application default' : widget.fontName;
    final String? previewFamily = widget.isDefault ? null : widget.fontName;

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
                    color: widget.selected ? AppColors.accent : AppColors.textSecondary,
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
                    color: widget.selected ? Colors.white : AppColors.textLabel,
                    fontWeight: widget.selected ? FontWeight.w500 : FontWeight.w400,
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
