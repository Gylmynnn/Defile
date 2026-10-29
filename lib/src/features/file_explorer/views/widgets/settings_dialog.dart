import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../../theme/app_theme.dart';
import '../../../../theme/theme_palette.dart';
import '../../controllers/explorer_tabs_controller.dart';
import '../../controllers/file_explorer_controller.dart';
import '../../services/default_file_manager_service.dart';
import '../../services/font_service.dart';
import '../../services/icon_theme_service.dart';
import '../../services/portal_file_chooser_service.dart';
import '../../services/theme_service.dart';
import '../../services/update_check_service.dart';
import '../../utils/app_toast.dart';
import 'app_button.dart';
import 'entry_glyphs.dart';
import 'hover_region.dart';
import 'themed_icon.dart';

part 'settings_controls.dart';
part 'settings_sections.dart';

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

  // Default file manager state (Linux). Null = unknown / unsupported.
  final DefaultFileManagerService _defaultFileManagerService =
      DefaultFileManagerService();
  bool _checkingDefaultManager = false;
  bool? _isDefaultFileManager;
  String? _currentDefaultManager;

  // Portal file chooser state (Linux).
  final PortalFileChooserService _portalChooserService =
      PortalFileChooserService();
  bool _portalBusy = false;
  bool _isPortalRegistered = false;

  // About section state. The version comes from pubspec.yaml via
  // package_info_plus, so bumping the build keeps the dialog honest.
  final UpdateCheckService _updateCheckService = UpdateCheckService();
  String? _appVersion;
  bool _checkingUpdate = false;

  IconThemeService get _iconService => Get.find<IconThemeService>();
  FontService get _fontService => Get.find<FontService>();
  ThemeService get _themeService => Get.find<ThemeService>();
  FileExplorerController? get _explorerController {
    if (Get.isRegistered<FileExplorerController>()) {
      return Get.find<FileExplorerController>();
    }
    if (Get.isRegistered<ExplorerTabsController>()) {
      return Get.find<ExplorerTabsController>().activeController;
    }
    return null;
  }

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
      _refreshDefaultFileManagerStatus();
      _isPortalRegistered = _portalChooserService.isRegisteredAsPortal;
      _loadAppVersion();
    });
  }

  /// Reads the pubspec version the binary was built with. Plugin-less
  /// environments (tests) simply keep the placeholder.
  Future<void> _loadAppVersion() async {
    try {
      final PackageInfo info = await PackageInfo.fromPlatform();
      if (!mounted) return;
      _update(() => _appVersion = info.version);
    } catch (_) {
      // Keep "…" until a real environment provides the version.
    }
  }

  /// Queries GitHub for the latest release and reports the outcome.
  Future<void> _checkForUpdates() async {
    if (_checkingUpdate) return;
    _update(() => _checkingUpdate = true);
    final UpdateCheckResult result = await _updateCheckService.checkForUpdate(
      currentVersion: _appVersion ?? 'unknown',
    );
    if (!mounted) return;
    _update(() => _checkingUpdate = false);

    if (!result.succeeded) {
      _showInfoMessage(
        'Update check',
        'Could not check for updates: ${result.error}.',
      );
    } else if (result.hasUpdate) {
      _showInfoMessage(
        'Update available',
        'Defile ${result.latestVersion} is available — you are running '
        '$_appVersion.\n${result.releaseUrl ?? ''}',
      );
    } else {
      _showInfoMessage(
        'Update check',
        'You are running the latest version of Defile ($_appVersion).',
      );
    }
  }

  Future<void> _refreshDefaultFileManagerStatus() async {
    if (!_defaultFileManagerService.isSupported) return;

    _update(() => _checkingDefaultManager = true);
    final String? current = await _defaultFileManagerService.queryDefault();
    _update(() {
      _checkingDefaultManager = false;
      _currentDefaultManager = current;
      _isDefaultFileManager =
          current == DefaultFileManagerService.desktopFileName;
    });
  }

  Future<void> _setDefaultFileManager() async {
    try {
      await _defaultFileManagerService.setAsDefault();
      _update(() => _isDefaultFileManager = true);
      showAppToast(
        title: 'Default file manager',
        message:
            'Defile now handles folders — xdg-open will open them here.',
        variant: AppToastVariant.success,
      );
    } catch (error) {
      showAppToast(
        title: 'Default file manager',
        message: 'Could not set Defile as default: $error',
        variant: AppToastVariant.error,
      );
    } finally {
      await _refreshDefaultFileManagerStatus();
    }
  }

  Future<void> _togglePortalChooser(bool enable) async {
    _update(() => _portalBusy = true);
    try {
      if (enable) {
        await _portalChooserService.registerAsPortal();
        showAppToast(
          title: 'File dialogs',
          message:
              'Defile will draw the open dialogs of portal-aware apps after '
              'they request one.',
          variant: AppToastVariant.success,
        );
      } else {
        await _portalChooserService.unregisterPortal();
        showAppToast(
          title: 'File dialogs',
          message: 'Defile no longer handles portal open dialogs.',
          variant: AppToastVariant.success,
        );
      }
      _update(() => _isPortalRegistered = enable);
    } catch (error) {
      showAppToast(
        title: 'File dialogs',
        message: 'Could not update the portal registration: $error',
        variant: AppToastVariant.error,
      );
    } finally {
      _update(() => _portalBusy = false);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _themeSearchController.dispose();
    _fontSearchController.dispose();
    super.dispose();
  }

  void _update(VoidCallback fn) => setState(fn);

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
              color: context.colors.windowDeep,
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
              border: Border.all(color: context.colors.cardBorder, width: 1),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Left Sidebar
                SizedBox(width: 235, child: _buildSidebar()),

                // Vertical Border Divider
                Container(width: 1, color: context.colors.divider),

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
      color: context.colors.sidebarDeep,
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
                        color: context.colors.textFaint,
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
        color: context.colors.input,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: context.colors.inputBorder, width: 1),
      ),
      child: Row(
        children: [
          Icon(Icons.search, size: 14, color: context.colors.textFaint),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              cursorHeight: 14,
              cursorColor: context.colors.accent,
              style: TextStyle(fontSize: 12, color: context.colors.textPrimary),
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
                  color: context.colors.textFaint,
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
                  child: Icon(
                    Icons.close,
                    size: 13,
                    color: context.colors.textFaint,
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
          color: context.colors.textFaint,
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
      color: context.colors.panel,
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
}
