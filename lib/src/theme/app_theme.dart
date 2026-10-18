import 'package:flutter/material.dart';

import 'theme_palette.dart';

/// Active application colors. The concrete values are resolved at runtime from
/// the selected [ThemePalette] and [AccentPreset] so that switching themes
/// updates every widget that reads these getters.
abstract final class AppColors {
  static ThemePalette _palette = AppPalettes.obsidianDark;
  static AccentPreset _accent = AppAccents.amber;

  static ThemePalette get palette => _palette;
  static AccentPreset get accentPreset => _accent;

  static void usePalette(ThemePalette palette) => _palette = palette;
  static void useAccent(AccentPreset accent) => _accent = accent;

  static Color get window => _palette.window;
  static Color get windowDeep => _palette.windowDeep;
  static Color get panel => _palette.panel;
  static Color get sidebar => _palette.sidebar;
  static Color get sidebarDeep => _palette.sidebarDeep;
  static Color get surface => _palette.surface;
  static Color get surfaceHigh => _palette.surfaceHigh;
  static Color get card => _palette.card;
  static Color get cardBorder => _palette.cardBorder;
  static Color get hover => _palette.hover;
  static Color get border => _palette.border;
  static Color get divider => _palette.divider;

  static Color get elevated => _palette.elevated;
  static Color get elevatedBorder => _palette.elevatedBorder;
  static Color get elevatedBorderHover => _palette.elevatedBorderHover;
  static Color get elevatedHover => _palette.elevatedHover;
  static Color get elevatedPressed => _palette.elevatedPressed;
  static Color get chip => _palette.chip;
  static Color get chipBorder => _palette.chipBorder;
  static Color get input => _palette.input;
  static Color get inputBorder => _palette.inputBorder;
  static Color get rowHover => _palette.rowHover;
  static Color get rowSelected => _palette.rowSelected;
  static Color get switchTrack => _palette.switchTrack;

  static Color get textPrimary => _palette.textPrimary;
  static Color get textStrong => _palette.textStrong;
  static Color get textLabel => _palette.textLabel;
  static Color get textSecondary => _palette.textSecondary;
  static Color get textFaint => _palette.textFaint;

  static Color get accent => _accent.color;
  static Color get selection =>
      Color.lerp(_palette.window, _accent.color, 0.24)!;
  static Color get selectionBorder =>
      Color.lerp(_palette.window, _accent.color, 0.5)!;

  static Color get folder => _palette.folder;
  static Color get folderDark => _palette.folderDark;
  static Color get folderTab => _palette.folderTab;

  static Color get danger => _palette.danger;
  static Color get dangerBright => _palette.dangerBright;
  static Color get warning => _palette.warning;
  static Color get success => _palette.success;

  static Color get menu => _palette.menu;
  static Color get menuBorder => _palette.menuBorder;
  static Color get menuLabel => _palette.menuLabel;
  static Color get menuIcon => _palette.menuIcon;
  static Color get menuShortcut => _palette.menuShortcut;

  static Color get fileDefault => _palette.fileDefault;
  static Color get scrollbar => _palette.scrollbar;
}

abstract final class AppTheme {
  static ThemeData dark({String? fontFamily}) {
    final String? resolvedFamily =
        (fontFamily != null && fontFamily.trim().isNotEmpty)
        ? fontFamily.trim()
        : null;

    final ThemeData base = ThemeData.dark(useMaterial3: true);
    final ColorScheme scheme = base.colorScheme.copyWith(
      primary: AppColors.accent,
      secondary: AppColors.accent,
      surface: AppColors.surface,
      onSurface: AppColors.textPrimary,
      error: AppColors.danger,
    );

    return base.copyWith(
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.window,
      canvasColor: AppColors.window,
      dividerColor: AppColors.divider,
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      visualDensity: VisualDensity.compact,
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: AppColors.accent,
        selectionColor: AppColors.selectionBorder.withValues(alpha: 0.33),
        selectionHandleColor: AppColors.accent,
      ),
      textTheme: base.textTheme
          .apply(
            fontFamily: resolvedFamily,
            bodyColor: AppColors.textPrimary,
            displayColor: AppColors.textPrimary,
          )
          .copyWith(
            bodySmall: base.textTheme.bodySmall?.copyWith(
              fontFamily: resolvedFamily,
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
            bodyMedium: base.textTheme.bodyMedium?.copyWith(
              fontFamily: resolvedFamily,
              fontSize: 13,
            ),
            titleMedium: base.textTheme.titleMedium?.copyWith(
              fontFamily: resolvedFamily,
              fontSize: 14,
            ),
          ),
      iconTheme: IconThemeData(color: AppColors.textSecondary, size: 18),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: AppColors.border),
        ),
        titleTextStyle: TextStyle(
          fontFamily: resolvedFamily,
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
        contentTextStyle: TextStyle(
          fontFamily: resolvedFamily,
          fontSize: 13,
          color: AppColors.textSecondary,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.surfaceHigh,
        contentTextStyle: TextStyle(
          fontFamily: resolvedFamily,
          color: AppColors.textPrimary,
          fontSize: 12.5,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: AppColors.border),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: AppColors.surfaceHigh,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(5),
        ),
        textStyle: TextStyle(
          fontFamily: resolvedFamily,
          color: AppColors.textPrimary,
          fontSize: 11.5,
        ),
        waitDuration: const Duration(milliseconds: 500),
      ),
      inputDecorationTheme: InputDecorationTheme(
        isDense: true,
        filled: true,
        fillColor: AppColors.window,
        hintStyle: TextStyle(color: AppColors.textFaint, fontSize: 12.5),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 10,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: AppColors.selectionBorder),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.selection,
          foregroundColor: AppColors.textPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
            side: BorderSide(color: AppColors.selectionBorder),
          ),
          textStyle: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.textSecondary,
          textStyle: const TextStyle(fontSize: 12.5),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: AppColors.surfaceHigh,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: AppColors.border),
        ),
        textStyle: TextStyle(color: AppColors.textPrimary, fontSize: 12.5),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: AppColors.accent,
      ),
      scrollbarTheme: ScrollbarThemeData(
        thickness: WidgetStateProperty.all(6),
        radius: const Radius.circular(3),
        thumbColor: WidgetStateProperty.all(AppColors.scrollbar),
        crossAxisMargin: 2,
      ),
    );
  }
}
