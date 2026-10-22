import 'package:flutter/material.dart';

import 'theme_palette.dart';

/// Active application colors. The concrete values are resolved at runtime from
/// the selected [ThemePalette] and [AccentPreset] so that switching themes
/// updates every widget that reads these getters.
@immutable
class AppThemeColors extends ThemeExtension<AppThemeColors> {
  const AppThemeColors({required this.palette, required this.accentPreset});

  final ThemePalette palette;
  final AccentPreset accentPreset;

  @override
  AppThemeColors copyWith({ThemePalette? palette, AccentPreset? accentPreset}) {
    return AppThemeColors(
      palette: palette ?? this.palette,
      accentPreset: accentPreset ?? this.accentPreset,
    );
  }

  @override
  AppThemeColors lerp(AppThemeColors? other, double t) => other ?? this;

  Color get window => palette.window;
  Color get windowDeep => palette.windowDeep;
  Color get panel => palette.panel;
  Color get surface => palette.surface;
  Color get surfaceHigh => palette.surfaceHigh;
  Color get sidebar => palette.sidebar;
  Color get sidebarDeep => palette.sidebarDeep;
  Color get card => palette.card;
  Color get chip => palette.chip;
  Color get chipBorder => palette.chipBorder;
  Color get input => palette.input;
  Color get inputBorder => palette.inputBorder;
  Color get switchTrack => palette.switchTrack;
  Color get elevated => palette.elevated;
  Color get elevatedPressed => palette.elevatedPressed;
  Color get elevatedBorder => palette.elevatedBorder;
  Color get elevatedBorderHover => palette.elevatedBorderHover;
  Color get elevatedHover => palette.elevatedHover;
  Color get cardBorder => palette.cardBorder;
  Color get divider => palette.divider;
  Color get border => palette.border;
  Color get hover => palette.hover;
  Color get rowHover => palette.rowHover;
  Color get rowSelected => palette.rowSelected;
  Color get menu => palette.menu;
  Color get menuBorder => palette.menuBorder;
  Color get menuIcon => palette.menuIcon;
  Color get menuLabel => palette.menuLabel;
  Color get menuShortcut => palette.menuShortcut;
  Color get textPrimary => palette.textPrimary;
  Color get textStrong => palette.textStrong;
  Color get textLabel => palette.textLabel;
  Color get textSecondary => palette.textSecondary;
  Color get textFaint => palette.textFaint;
  Color get accent => accentPreset.color;
  Color get accentContent =>
      palette.isLight ? palette.textStrong : palette.windowDeep;
  Color get selection => Color.lerp(palette.window, accentPreset.color, 0.24)!;
  Color get selectionBorder =>
      Color.lerp(palette.window, accentPreset.color, 0.5)!;
  Color get danger => palette.danger;
  Color get dangerBright => palette.dangerBright;
  Color get warning => palette.warning;
  Color get success => palette.success;
  Color get folder => palette.folder;
  Color get folderDark => palette.folderDark;
  Color get folderTab => palette.folderTab;
  Color get fileDefault => palette.fileDefault;
  Color get scrollbar => palette.scrollbar;
}

extension AppThemeColorsContext on BuildContext {
  AppThemeColors get colors {
    return Theme.of(this).extension<AppThemeColors>() ??
        const AppThemeColors(
          palette: AppPalettes.defile,
          accentPreset: AppAccents.amber,
        );
  }
}

abstract final class AppTheme {
  static ThemeData dark({
    required ThemePalette palette,
    required AccentPreset accentPreset,
    String? fontFamily,
  }) {
    final colors = AppThemeColors(palette: palette, accentPreset: accentPreset);
    final String? resolvedFamily =
        (fontFamily != null && fontFamily.trim().isNotEmpty)
        ? fontFamily.trim()
        : null;

    final ThemeData base = colors.palette.isLight
        ? ThemeData.light(useMaterial3: true)
        : ThemeData.dark(useMaterial3: true);
    final ColorScheme scheme = base.colorScheme.copyWith(
      primary: colors.accent,
      secondary: colors.accent,
      surface: colors.surface,
      onSurface: colors.textPrimary,
      error: colors.danger,
    );

    return base.copyWith(
      extensions: [colors],
      colorScheme: scheme,
      scaffoldBackgroundColor: colors.window,
      canvasColor: colors.window,
      dividerColor: colors.divider,
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      visualDensity: VisualDensity.compact,
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: colors.accent,
        selectionColor: colors.selectionBorder.withValues(alpha: 0.33),
        selectionHandleColor: colors.accent,
      ),
      textTheme: base.textTheme
          .apply(
            fontFamily: resolvedFamily,
            bodyColor: colors.textPrimary,
            displayColor: colors.textPrimary,
          )
          .copyWith(
            bodySmall: base.textTheme.bodySmall?.copyWith(
              fontFamily: resolvedFamily,
              fontSize: 12,
              color: colors.textSecondary,
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
      iconTheme: IconThemeData(color: colors.textSecondary, size: 18),
      dialogTheme: DialogThemeData(
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: colors.border),
        ),
        titleTextStyle: TextStyle(
          fontFamily: resolvedFamily,
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: colors.textPrimary,
        ),
        contentTextStyle: TextStyle(
          fontFamily: resolvedFamily,
          fontSize: 13,
          color: colors.textSecondary,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: colors.surfaceHigh,
        contentTextStyle: TextStyle(
          fontFamily: resolvedFamily,
          color: colors.textPrimary,
          fontSize: 12.5,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: colors.border),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: colors.surfaceHigh,
          border: Border.all(color: colors.border),
          borderRadius: BorderRadius.circular(5),
        ),
        textStyle: TextStyle(
          fontFamily: resolvedFamily,
          color: colors.textPrimary,
          fontSize: 11.5,
        ),
        waitDuration: const Duration(milliseconds: 500),
      ),
      inputDecorationTheme: InputDecorationTheme(
        isDense: true,
        filled: true,
        fillColor: colors.window,
        hintStyle: TextStyle(color: colors.textFaint, fontSize: 12.5),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 10,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: colors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: colors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: colors.selectionBorder),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: colors.selection,
          foregroundColor: colors.textPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
            side: BorderSide(color: colors.selectionBorder),
          ),
          textStyle: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colors.textSecondary,
          textStyle: const TextStyle(fontSize: 12.5),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: colors.surfaceHigh,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: colors.border),
        ),
        textStyle: TextStyle(color: colors.textPrimary, fontSize: 12.5),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: colors.accent),
      scrollbarTheme: ScrollbarThemeData(
        thickness: WidgetStateProperty.all(6),
        radius: const Radius.circular(3),
        thumbColor: WidgetStateProperty.all(colors.scrollbar),
        crossAxisMargin: 2,
      ),
    );
  }
}
