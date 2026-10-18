import 'package:flutter/material.dart';

/// A complete base color scheme used to theme the whole application shell.
@immutable
class ThemePalette {
  const ThemePalette({
    required this.id,
    required this.label,
    required this.window,
    required this.windowDeep,
    required this.panel,
    required this.sidebar,
    required this.sidebarDeep,
    required this.surface,
    required this.surfaceHigh,
    required this.card,
    required this.cardBorder,
    required this.hover,
    required this.border,
    required this.divider,
    required this.elevated,
    required this.elevatedBorder,
    required this.elevatedBorderHover,
    required this.elevatedHover,
    required this.elevatedPressed,
    required this.chip,
    required this.chipBorder,
    required this.input,
    required this.inputBorder,
    required this.rowHover,
    required this.rowSelected,
    required this.switchTrack,
    required this.textPrimary,
    required this.textStrong,
    required this.textLabel,
    required this.textSecondary,
    required this.textFaint,
    required this.folder,
    required this.folderDark,
    required this.folderTab,
    required this.danger,
    required this.dangerBright,
    required this.warning,
    required this.success,
    required this.menu,
    required this.menuBorder,
    required this.menuLabel,
    required this.menuIcon,
    required this.menuShortcut,
    required this.fileDefault,
    required this.scrollbar,
  });

  final String id;
  final String label;

  final Color window;
  final Color windowDeep;
  final Color panel;
  final Color sidebar;
  final Color sidebarDeep;
  final Color surface;
  final Color surfaceHigh;
  final Color card;
  final Color cardBorder;
  final Color hover;
  final Color border;
  final Color divider;

  final Color elevated;
  final Color elevatedBorder;
  final Color elevatedBorderHover;
  final Color elevatedHover;
  final Color elevatedPressed;
  final Color chip;
  final Color chipBorder;
  final Color input;
  final Color inputBorder;
  final Color rowHover;
  final Color rowSelected;
  final Color switchTrack;

  final Color textPrimary;
  final Color textStrong;
  final Color textLabel;
  final Color textSecondary;
  final Color textFaint;

  final Color folder;
  final Color folderDark;
  final Color folderTab;

  final Color danger;
  final Color dangerBright;
  final Color warning;
  final Color success;

  final Color menu;
  final Color menuBorder;
  final Color menuLabel;
  final Color menuIcon;
  final Color menuShortcut;

  final Color fileDefault;
  final Color scrollbar;
}

/// A selectable highlight color. Selection tints are derived from the accent
/// and the active base palette at runtime.
@immutable
class AccentPreset {
  const AccentPreset({
    required this.id,
    required this.label,
    required this.color,
  });

  final String id;
  final String label;
  final Color color;
}

abstract final class AppPalettes {
  static const ThemePalette obsidianDark = ThemePalette(
    id: 'obsidian-dark',
    label: 'Obsidian Dark',
    window: Color(0xFF191B1C),
    windowDeep: Color(0xFF16181A),
    panel: Color(0xFF17191B),
    sidebar: Color(0xFF161819),
    sidebarDeep: Color(0xFF131517),
    surface: Color(0xFF202324),
    surfaceHigh: Color(0xFF26292B),
    card: Color(0xFF1E2124),
    cardBorder: Color(0xFF2A2D30),
    hover: Color(0xFF23272A),
    border: Color(0xFF2B2F31),
    divider: Color(0xFF25292B),
    elevated: Color(0xFF2A2E32),
    elevatedBorder: Color(0xFF3B4045),
    elevatedBorderHover: Color(0xFF484E54),
    elevatedHover: Color(0xFF33383D),
    elevatedPressed: Color(0xFF222528),
    chip: Color(0xFF26292C),
    chipBorder: Color(0xFF383C40),
    input: Color(0xFF1A1C1E),
    inputBorder: Color(0xFF282C2E),
    rowHover: Color(0xFF222528),
    rowSelected: Color(0xFF282B2E),
    switchTrack: Color(0xFF26292B),
    textPrimary: Color(0xFFDCDDDD),
    textStrong: Color(0xFFDFE1E2),
    textLabel: Color(0xFFD4D8DB),
    textSecondary: Color(0xFF8C9496),
    textFaint: Color(0xFF666E70),
    folder: Color(0xFF87AFA2),
    folderDark: Color(0xFF6D968A),
    folderTab: Color(0xFF5D857A),
    danger: Color(0xFFB4433B),
    dangerBright: Color(0xFFE0574F),
    warning: Color(0xFFC08B3E),
    success: Color(0xFF6F9E86),
    menu: Color(0xFF1B1D1E),
    menuBorder: Color(0xFF303436),
    menuLabel: Color(0xFFD7DADB),
    menuIcon: Color(0xFFC9CDCE),
    menuShortcut: Color(0xFF6E7778),
    fileDefault: Color(0xFF7C8A99),
    scrollbar: Color(0xFF3A3F41),
  );

  static const ThemePalette everblush = ThemePalette(
    id: 'everblush',
    label: 'Everblush',
    window: Color(0xFF141B1E),
    windowDeep: Color(0xFF0F1619),
    panel: Color(0xFF171E21),
    sidebar: Color(0xFF10171A),
    sidebarDeep: Color(0xFF0D1417),
    surface: Color(0xFF1E2528),
    surfaceHigh: Color(0xFF232A2D),
    card: Color(0xFF1E2528),
    cardBorder: Color(0xFF2D3437),
    hover: Color(0xFF232A2D),
    border: Color(0xFF2D3437),
    divider: Color(0xFF222A2D),
    elevated: Color(0xFF232A2D),
    elevatedBorder: Color(0xFF2D3437),
    elevatedBorderHover: Color(0xFF3B4245),
    elevatedHover: Color(0xFF2D3437),
    elevatedPressed: Color(0xFF1E2528),
    chip: Color(0xFF232A2D),
    chipBorder: Color(0xFF2D3437),
    input: Color(0xFF1A2124),
    inputBorder: Color(0xFF2D3437),
    rowHover: Color(0xFF232A2D),
    rowSelected: Color(0xFF2D3437),
    switchTrack: Color(0xFF232A2D),
    textPrimary: Color(0xFFDADADA),
    textStrong: Color(0xFFE4E6E6),
    textLabel: Color(0xFFC0C6C5),
    textSecondary: Color(0xFF9BA3A5),
    textFaint: Color(0xFF6B7375),
    folder: Color(0xFF6CBFBF),
    folderDark: Color(0xFF57A3A3),
    folderTab: Color(0xFF479595),
    danger: Color(0xFFE57474),
    dangerBright: Color(0xFFF08B8B),
    warning: Color(0xFFE5C76B),
    success: Color(0xFF8CCF7E),
    menu: Color(0xFF171E21),
    menuBorder: Color(0xFF2D3437),
    menuLabel: Color(0xFFDADADA),
    menuIcon: Color(0xFFB3B9B8),
    menuShortcut: Color(0xFF6B7375),
    fileDefault: Color(0xFF7F96A3),
    scrollbar: Color(0xFF2D3437),
  );

  static const ThemePalette gruvbox = ThemePalette(
    id: 'gruvbox',
    label: 'Gruvbox',
    window: Color(0xFF1D2021),
    windowDeep: Color(0xFF161819),
    panel: Color(0xFF1D2021),
    sidebar: Color(0xFF161819),
    sidebarDeep: Color(0xFF131517),
    surface: Color(0xFF282828),
    surfaceHigh: Color(0xFF32302F),
    card: Color(0xFF282828),
    cardBorder: Color(0xFF3C3836),
    hover: Color(0xFF3C3836),
    border: Color(0xFF3C3836),
    divider: Color(0xFF32302F),
    elevated: Color(0xFF32302F),
    elevatedBorder: Color(0xFF504945),
    elevatedBorderHover: Color(0xFF665C54),
    elevatedHover: Color(0xFF3C3836),
    elevatedPressed: Color(0xFF282828),
    chip: Color(0xFF32302F),
    chipBorder: Color(0xFF504945),
    input: Color(0xFF32302F),
    inputBorder: Color(0xFF3C3836),
    rowHover: Color(0xFF3C3836),
    rowSelected: Color(0xFF504945),
    switchTrack: Color(0xFF3C3836),
    textPrimary: Color(0xFFEBDBB2),
    textStrong: Color(0xFFFBF1C7),
    textLabel: Color(0xFFD5C4A1),
    textSecondary: Color(0xFFA89984),
    textFaint: Color(0xFF7C6F64),
    folder: Color(0xFF83A598),
    folderDark: Color(0xFF6D8A7F),
    folderTab: Color(0xFF5D7A6F),
    danger: Color(0xFFFB4934),
    dangerBright: Color(0xFFFF6B5B),
    warning: Color(0xFFFABD2F),
    success: Color(0xFFB8BB26),
    menu: Color(0xFF1F2221),
    menuBorder: Color(0xFF3C3836),
    menuLabel: Color(0xFFEBDBB2),
    menuIcon: Color(0xFFD5C4A1),
    menuShortcut: Color(0xFF7C6F64),
    fileDefault: Color(0xFFA89984),
    scrollbar: Color(0xFF504945),
  );

  static const List<ThemePalette> all = [obsidianDark, everblush, gruvbox];

  static ThemePalette byId(String id) {
    return all.firstWhere(
      (palette) => palette.id == id,
      orElse: () => obsidianDark,
    );
  }
}

abstract final class AppAccents {
  static const AccentPreset amber = AccentPreset(
    id: 'amber',
    label: 'Amber',
    color: Color(0xFFCFA05A),
  );
  static const AccentPreset violet = AccentPreset(
    id: 'violet',
    label: 'Violet',
    color: Color(0xFF7C54E8),
  );
  static const AccentPreset blue = AccentPreset(
    id: 'blue',
    label: 'Blue',
    color: Color(0xFF4A90E2),
  );
  static const AccentPreset green = AccentPreset(
    id: 'green',
    label: 'Green',
    color: Color(0xFF48BB78),
  );
  static const AccentPreset red = AccentPreset(
    id: 'red',
    label: 'Red',
    color: Color(0xFFE06C75),
  );
  static const AccentPreset pink = AccentPreset(
    id: 'pink',
    label: 'Pink',
    color: Color(0xFFC47FD5),
  );
  static const AccentPreset cyan = AccentPreset(
    id: 'cyan',
    label: 'Cyan',
    color: Color(0xFF67B0E8),
  );

  static const List<AccentPreset> all = [
    amber,
    violet,
    blue,
    green,
    red,
    pink,
    cyan,
  ];

  static AccentPreset byId(String id) {
    return all.firstWhere((accent) => accent.id == id, orElse: () => amber);
  }
}
