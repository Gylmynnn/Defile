import 'package:flutter/material.dart';

abstract final class AppColors {
  static const Color window = Color(0xFF191B1C);
  static const Color sidebar = Color(0xFF161819);
  static const Color surface = Color(0xFF202324);
  static const Color surfaceHigh = Color(0xFF26292B);
  static const Color hover = Color(0xFF23272A);
  static const Color border = Color(0xFF2B2F31);
  static const Color divider = Color(0xFF25292B);

  static const Color textPrimary = Color(0xFFDCDDDD);
  static const Color textSecondary = Color(0xFF8C9496);
  static const Color textFaint = Color(0xFF666E70);

  static const Color accent = Color(0xFFCFA05A);
  static const Color selection = Color(0xFF4A3B28);
  static const Color selectionBorder = Color(0xFF75603F);

  static const Color folder = Color(0xFF87AFA2);
  static const Color folderDark = Color(0xFF6D968A);
  static const Color folderTab = Color(0xFF5D857A);

  static const Color danger = Color(0xFFB4433B);
  static const Color dangerBright = Color(0xFFE0574F);
  static const Color warning = Color(0xFFC08B3E);
  static const Color success = Color(0xFF6F9E86);

  static const Color menu = Color(0xFF1B1D1E);
  static const Color menuBorder = Color(0xFF303436);
  static const Color menuLabel = Color(0xFFD7DADB);
  static const Color menuIcon = Color(0xFFC9CDCE);
  static const Color menuShortcut = Color(0xFF6E7778);

  static const Color fileDefault = Color(0xFF7C8A99);
}

abstract final class AppTheme {
  static ThemeData dark() {
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
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: AppColors.accent,
        selectionColor: Color(0x5575603F),
        selectionHandleColor: AppColors.accent,
      ),
      textTheme: base.textTheme
          .apply(
            bodyColor: AppColors.textPrimary,
            displayColor: AppColors.textPrimary,
          )
          .copyWith(
            bodySmall: base.textTheme.bodySmall?.copyWith(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
            bodyMedium: base.textTheme.bodyMedium?.copyWith(fontSize: 13),
            titleMedium: base.textTheme.titleMedium?.copyWith(fontSize: 14),
          ),
      iconTheme: const IconThemeData(color: AppColors.textSecondary, size: 18),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: AppColors.border),
        ),
        titleTextStyle: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
        contentTextStyle: const TextStyle(
          fontSize: 13,
          color: AppColors.textSecondary,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.surfaceHigh,
        contentTextStyle: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 12.5,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: AppColors.surfaceHigh,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(5),
        ),
        textStyle: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 11.5,
        ),
        waitDuration: const Duration(milliseconds: 500),
      ),
      inputDecorationTheme: InputDecorationTheme(
        isDense: true,
        filled: true,
        fillColor: AppColors.window,
        hintStyle: const TextStyle(color: AppColors.textFaint, fontSize: 12.5),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 10,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: AppColors.selectionBorder),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.selection,
          foregroundColor: AppColors.textPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
            side: const BorderSide(color: AppColors.selectionBorder),
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
          side: const BorderSide(color: AppColors.border),
        ),
        textStyle: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 12.5,
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.accent,
      ),
      scrollbarTheme: ScrollbarThemeData(
        thickness: WidgetStateProperty.all(6),
        radius: const Radius.circular(3),
        thumbColor: WidgetStateProperty.all(const Color(0xFF3A3F41)),
        crossAxisMargin: 2,
      ),
    );
  }
}
