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

  bool get isLight => window.computeLuminance() > 0.5;

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
  static const ThemePalette defile = ThemePalette(
    id: 'defile',
    label: 'Defile',
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

  static const ThemePalette catppuccinMocha = ThemePalette(
    id: 'catppuccin-mocha',
    label: 'Catppuccin Mocha',
    window: Color(0xFF1E1E2E),
    windowDeep: Color(0xFF11111B),
    panel: Color(0xFF181825),
    sidebar: Color(0xFF181825),
    sidebarDeep: Color(0xFF11111B),
    surface: Color(0xFF313244),
    surfaceHigh: Color(0xFF45475A),
    card: Color(0xFF181825),
    cardBorder: Color(0xFF313244),
    hover: Color(0xFF313244),
    border: Color(0xFF45475A),
    divider: Color(0xFF313244),
    elevated: Color(0xFF45475A),
    elevatedBorder: Color(0xFF585B70),
    elevatedBorderHover: Color(0xFF6C7086),
    elevatedHover: Color(0xFF585B70),
    elevatedPressed: Color(0xFF313244),
    chip: Color(0xFF313244),
    chipBorder: Color(0xFF45475A),
    input: Color(0xFF181825),
    inputBorder: Color(0xFF45475A),
    rowHover: Color(0xFF313244),
    rowSelected: Color(0xFF45475A),
    switchTrack: Color(0xFF45475A),
    textPrimary: Color(0xFFCDD6F4),
    textStrong: Color(0xFFF5E0DC),
    textLabel: Color(0xFFBAC2DE),
    textSecondary: Color(0xFFA6ADC8),
    textFaint: Color(0xFF7F849C),
    folder: Color(0xFF89B4FA),
    folderDark: Color(0xFF74C7EC),
    folderTab: Color(0xFF94E2D5),
    danger: Color(0xFFF38BA8),
    dangerBright: Color(0xFFEBA0AC),
    warning: Color(0xFFF9E2AF),
    success: Color(0xFFA6E3A1),
    menu: Color(0xFF181825),
    menuBorder: Color(0xFF313244),
    menuLabel: Color(0xFFCDD6F4),
    menuIcon: Color(0xFFBAC2DE),
    menuShortcut: Color(0xFF7F849C),
    fileDefault: Color(0xFFA6ADC8),
    scrollbar: Color(0xFF585B70),
  );

  static const ThemePalette tokyoNight = ThemePalette(
    id: 'tokyonight',
    label: 'Tokyo Night',
    window: Color(0xFF1A1B26),
    windowDeep: Color(0xFF16161E),
    panel: Color(0xFF16161E),
    sidebar: Color(0xFF16161E),
    sidebarDeep: Color(0xFF0C0E14),
    surface: Color(0xFF24283B),
    surfaceHigh: Color(0xFF292E42),
    card: Color(0xFF1F2335),
    cardBorder: Color(0xFF3B4261),
    hover: Color(0xFF292E42),
    border: Color(0xFF3B4261),
    divider: Color(0xFF292E42),
    elevated: Color(0xFF292E42),
    elevatedBorder: Color(0xFF3B4261),
    elevatedBorderHover: Color(0xFF545C7E),
    elevatedHover: Color(0xFF343B58),
    elevatedPressed: Color(0xFF1F2335),
    chip: Color(0xFF292E42),
    chipBorder: Color(0xFF414868),
    input: Color(0xFF16161E),
    inputBorder: Color(0xFF292E42),
    rowHover: Color(0xFF24283B),
    rowSelected: Color(0xFF292E42),
    switchTrack: Color(0xFF414868),
    textPrimary: Color(0xFFC0CAF5),
    textStrong: Color(0xFFD5DEFB),
    textLabel: Color(0xFFA9B1D6),
    textSecondary: Color(0xFF9AA5CE),
    textFaint: Color(0xFF565F89),
    folder: Color(0xFF7AA2F7),
    folderDark: Color(0xFF3D59A1),
    folderTab: Color(0xFF2AC3DE),
    danger: Color(0xFFF7768E),
    dangerBright: Color(0xFFFF7A93),
    warning: Color(0xFFE0AF68),
    success: Color(0xFF9ECE6A),
    menu: Color(0xFF16161E),
    menuBorder: Color(0xFF292E42),
    menuLabel: Color(0xFFC0CAF5),
    menuIcon: Color(0xFFA9B1D6),
    menuShortcut: Color(0xFF565F89),
    fileDefault: Color(0xFF9AA5CE),
    scrollbar: Color(0xFF3B4261),
  );

  static const ThemePalette catppuccinLatte = ThemePalette(
    id: 'catppuccin-latte',
    label: 'Catppuccin Latte',
    window: Color(0xFFEFF1F5),
    windowDeep: Color(0xFFE6E9EF),
    panel: Color(0xFFE6E9EF),
    sidebar: Color(0xFFE6E9EF),
    sidebarDeep: Color(0xFFDCE0E8),
    surface: Color(0xFFE6E9EF),
    surfaceHigh: Color(0xFFDCE0E8),
    card: Color(0xFFFFFFFF),
    cardBorder: Color(0xFFCCD0DA),
    hover: Color(0xFFDCE0E8),
    border: Color(0xFFCCD0DA),
    divider: Color(0xFFD3D7E0),
    elevated: Color(0xFFDCE0E8),
    elevatedBorder: Color(0xFFBCC0CC),
    elevatedBorderHover: Color(0xFFACB0BE),
    elevatedHover: Color(0xFFCCD0DA),
    elevatedPressed: Color(0xFFBCC0CC),
    chip: Color(0xFFDCE0E8),
    chipBorder: Color(0xFFBCC0CC),
    input: Color(0xFFFFFFFF),
    inputBorder: Color(0xFFCCD0DA),
    rowHover: Color(0xFFDCE0E8),
    rowSelected: Color(0xFFCCD0DA),
    switchTrack: Color(0xFFBCC0CC),
    textPrimary: Color(0xFF4C4F69),
    textStrong: Color(0xFF363A4F),
    textLabel: Color(0xFF5C5F77),
    textSecondary: Color(0xFF6C6F85),
    textFaint: Color(0xFF8C8FA1),
    folder: Color(0xFF1E66F5),
    folderDark: Color(0xFF209FB5),
    folderTab: Color(0xFF04A5E5),
    danger: Color(0xFFD20F39),
    dangerBright: Color(0xFFE64553),
    warning: Color(0xFFDF8E1D),
    success: Color(0xFF40A02B),
    menu: Color(0xFFFFFFFF),
    menuBorder: Color(0xFFCCD0DA),
    menuLabel: Color(0xFF4C4F69),
    menuIcon: Color(0xFF5C5F77),
    menuShortcut: Color(0xFF8C8FA1),
    fileDefault: Color(0xFF6C6F85),
    scrollbar: Color(0xFFBCC0CC),
  );

  static const ThemePalette dracula = ThemePalette(
    id: 'dracula',
    label: 'Dracula',
    window: Color(0xFF282A36),
    windowDeep: Color(0xFF21222C),
    panel: Color(0xFF21222C),
    sidebar: Color(0xFF21222C),
    sidebarDeep: Color(0xFF191A21),
    surface: Color(0xFF343746),
    surfaceHigh: Color(0xFF44475A),
    card: Color(0xFF343746),
    cardBorder: Color(0xFF44475A),
    hover: Color(0xFF44475A),
    border: Color(0xFF44475A),
    divider: Color(0xFF343746),
    elevated: Color(0xFF44475A),
    elevatedBorder: Color(0xFF6272A4),
    elevatedBorderHover: Color(0xFF7A86B8),
    elevatedHover: Color(0xFF52566B),
    elevatedPressed: Color(0xFF383B4A),
    chip: Color(0xFF343746),
    chipBorder: Color(0xFF44475A),
    input: Color(0xFF21222C),
    inputBorder: Color(0xFF44475A),
    rowHover: Color(0xFF343746),
    rowSelected: Color(0xFF44475A),
    switchTrack: Color(0xFF44475A),
    textPrimary: Color(0xFFF8F8F2),
    textStrong: Color(0xFFFFFFFF),
    textLabel: Color(0xFFE6E6E0),
    textSecondary: Color(0xFFA8AABF),
    textFaint: Color(0xFF6272A4),
    folder: Color(0xFF8BE9FD),
    folderDark: Color(0xFF62C9D9),
    folderTab: Color(0xFF5CB8C9),
    danger: Color(0xFFFF5555),
    dangerBright: Color(0xFFFF6E6E),
    warning: Color(0xFFF1FA8C),
    success: Color(0xFF50FA7B),
    menu: Color(0xFF21222C),
    menuBorder: Color(0xFF44475A),
    menuLabel: Color(0xFFF8F8F2),
    menuIcon: Color(0xFFA8AABF),
    menuShortcut: Color(0xFF6272A4),
    fileDefault: Color(0xFFB8B9C5),
    scrollbar: Color(0xFF44475A),
  );

  static const ThemePalette nord = ThemePalette(
    id: 'nord',
    label: 'Nord',
    window: Color(0xFF2E3440),
    windowDeep: Color(0xFF272C36),
    panel: Color(0xFF292E39),
    sidebar: Color(0xFF2E3440),
    sidebarDeep: Color(0xFF272C36),
    surface: Color(0xFF3B4252),
    surfaceHigh: Color(0xFF434C5E),
    card: Color(0xFF3B4252),
    cardBorder: Color(0xFF434C5E),
    hover: Color(0xFF3B4252),
    border: Color(0xFF434C5E),
    divider: Color(0xFF3B4252),
    elevated: Color(0xFF434C5E),
    elevatedBorder: Color(0xFF4C566A),
    elevatedBorderHover: Color(0xFF5E6B82),
    elevatedHover: Color(0xFF4C566A),
    elevatedPressed: Color(0xFF3B4252),
    chip: Color(0xFF434C5E),
    chipBorder: Color(0xFF4C566A),
    input: Color(0xFF2E3440),
    inputBorder: Color(0xFF434C5E),
    rowHover: Color(0xFF3B4252),
    rowSelected: Color(0xFF434C5E),
    switchTrack: Color(0xFF4C566A),
    textPrimary: Color(0xFFD8DEE9),
    textStrong: Color(0xFFECEFF4),
    textLabel: Color(0xFFE5E9F0),
    textSecondary: Color(0xFFA9B1BF),
    textFaint: Color(0xFF7B8494),
    folder: Color(0xFF88C0D0),
    folderDark: Color(0xFF5E81AC),
    folderTab: Color(0xFF8FBCBB),
    danger: Color(0xFFBF616A),
    dangerBright: Color(0xFFD06B74),
    warning: Color(0xFFEBCB8B),
    success: Color(0xFFA3BE8C),
    menu: Color(0xFF2E3440),
    menuBorder: Color(0xFF434C5E),
    menuLabel: Color(0xFFD8DEE9),
    menuIcon: Color(0xFFA9B1BF),
    menuShortcut: Color(0xFF7B8494),
    fileDefault: Color(0xFFA9B1BF),
    scrollbar: Color(0xFF4C566A),
  );

  static const ThemePalette oneDark = ThemePalette(
    id: 'one-dark',
    label: 'One Dark',
    window: Color(0xFF282C34),
    windowDeep: Color(0xFF21252B),
    panel: Color(0xFF21252B),
    sidebar: Color(0xFF21252B),
    sidebarDeep: Color(0xFF1B1F24),
    surface: Color(0xFF31363F),
    surfaceHigh: Color(0xFF3A404B),
    card: Color(0xFF2C313A),
    cardBorder: Color(0xFF3E4451),
    hover: Color(0xFF2C313A),
    border: Color(0xFF3E4451),
    divider: Color(0xFF2F343D),
    elevated: Color(0xFF3A3F4B),
    elevatedBorder: Color(0xFF4B5263),
    elevatedBorderHover: Color(0xFF5C6370),
    elevatedHover: Color(0xFF434955),
    elevatedPressed: Color(0xFF323640),
    chip: Color(0xFF2C313A),
    chipBorder: Color(0xFF3E4451),
    input: Color(0xFF21252B),
    inputBorder: Color(0xFF3E4451),
    rowHover: Color(0xFF2C313A),
    rowSelected: Color(0xFF3A404B),
    switchTrack: Color(0xFF3E4451),
    textPrimary: Color(0xFFABB2BF),
    textStrong: Color(0xFFD7DAE0),
    textLabel: Color(0xFFC8CDD5),
    textSecondary: Color(0xFF8B92A0),
    textFaint: Color(0xFF5C6370),
    folder: Color(0xFF61AFEF),
    folderDark: Color(0xFF4D8FD0),
    folderTab: Color(0xFF56B6C2),
    danger: Color(0xFFE06C75),
    dangerBright: Color(0xFFEC7A83),
    warning: Color(0xFFE5C07B),
    success: Color(0xFF98C379),
    menu: Color(0xFF21252B),
    menuBorder: Color(0xFF3E4451),
    menuLabel: Color(0xFFABB2BF),
    menuIcon: Color(0xFF9AA1AE),
    menuShortcut: Color(0xFF5C6370),
    fileDefault: Color(0xFF98A2B3),
    scrollbar: Color(0xFF4B5263),
  );

  static const ThemePalette rosePine = ThemePalette(
    id: 'rose-pine',
    label: 'Rosé Pine',
    window: Color(0xFF191724),
    windowDeep: Color(0xFF151320),
    panel: Color(0xFF1F1D2E),
    sidebar: Color(0xFF1F1D2E),
    sidebarDeep: Color(0xFF151320),
    surface: Color(0xFF26233A),
    surfaceHigh: Color(0xFF403D52),
    card: Color(0xFF1F1D2E),
    cardBorder: Color(0xFF403D52),
    hover: Color(0xFF26233A),
    border: Color(0xFF403D52),
    divider: Color(0xFF26233A),
    elevated: Color(0xFF403D52),
    elevatedBorder: Color(0xFF524F67),
    elevatedBorderHover: Color(0xFF6E6A86),
    elevatedHover: Color(0xFF524F67),
    elevatedPressed: Color(0xFF26233A),
    chip: Color(0xFF26233A),
    chipBorder: Color(0xFF403D52),
    input: Color(0xFF1F1D2E),
    inputBorder: Color(0xFF403D52),
    rowHover: Color(0xFF26233A),
    rowSelected: Color(0xFF403D52),
    switchTrack: Color(0xFF403D52),
    textPrimary: Color(0xFFE0DEF4),
    textStrong: Color(0xFFF0EEFB),
    textLabel: Color(0xFFD6D2EA),
    textSecondary: Color(0xFF908CAA),
    textFaint: Color(0xFF6E6A86),
    folder: Color(0xFF9CCFD8),
    folderDark: Color(0xFF31748F),
    folderTab: Color(0xFFC4A7E7),
    danger: Color(0xFFEB6F92),
    dangerBright: Color(0xFFF08BA8),
    warning: Color(0xFFF6C177),
    success: Color(0xFF9CCFD8),
    menu: Color(0xFF1F1D2E),
    menuBorder: Color(0xFF403D52),
    menuLabel: Color(0xFFE0DEF4),
    menuIcon: Color(0xFF908CAA),
    menuShortcut: Color(0xFF6E6A86),
    fileDefault: Color(0xFF908CAA),
    scrollbar: Color(0xFF524F67),
  );

  static const List<ThemePalette> all = [
    defile,
    everblush,
    gruvbox,
    catppuccinMocha,
    catppuccinLatte,
    tokyoNight,
    dracula,
    nord,
    oneDark,
    rosePine,
  ];

  static ThemePalette byId(String id) {
    return all.firstWhere((palette) => palette.id == id, orElse: () => defile);
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
