import 'package:defile/src/rust/api/appearance.dart' as rust;
import 'package:defile/src/theme/theme_palette.dart';
import 'package:get/get.dart';

/// Owns the selected base color theme and accent color, persists them, and
/// applies the resulting [AppThemeColors] + [ThemeData] to the running app.
class ThemeService extends GetxService {
  final RxString baseThemeId = AppPalettes.defile.id.obs;
  final RxString accentId = AppAccents.amber.id.obs;
  final RxDouble uiScale = 1.0.obs;

  // ponytail: in-memory only. Add a rust getter/setter (like uiScale) if it
  // needs to survive restarts.
  final RxBool animationsEnabled = true.obs;
  final RxBool previewEnabled = false.obs;
  final RxDouble previewWidth = 320.0.obs;

  /// Height of the bottom preview strip used in vertical split view.
  final RxDouble previewHeight = 170.0.obs;

  Duration get animationDuration => animationsEnabled.value
      ? const Duration(milliseconds: 200)
      : Duration.zero;

  static const double minScale = 0.75;
  static const double maxScale = 1.5;

  ThemePalette get palette => AppPalettes.byId(baseThemeId.value);
  AccentPreset get accent => AppAccents.byId(accentId.value);

  Future<void> init() async {
    try {
      final String storedTheme = await rust.getBaseTheme();
      if (AppPalettes.all.any((palette) => palette.id == storedTheme)) {
        baseThemeId.value = storedTheme;
      }
    } catch (_) {}

    try {
      final String storedAccent = await rust.getAccentColor();
      if (AppAccents.all.any((accent) => accent.id == storedAccent)) {
        accentId.value = storedAccent;
      }
    } catch (_) {}

    try {
      final double storedScale = await rust.getUiScale();
      if (storedScale.isFinite && storedScale > 0) {
        uiScale.value = storedScale.clamp(minScale, maxScale);
      }
    } catch (_) {}
  }

  Future<void> setBaseTheme(String id) async {
    baseThemeId.value = id;

    try {
      await rust.setBaseTheme(name: id);
    } catch (_) {}
  }

  Future<void> setAccent(String id) async {
    accentId.value = id;

    try {
      await rust.setAccentColor(name: id);
    } catch (_) {}
  }

  void setUiScale(double value) {
    uiScale.value = double.parse(
      value.clamp(minScale, maxScale).toStringAsFixed(2),
    );

    try {
      rust.setUiScale(scale: uiScale.value);
    } catch (_) {}
  }
}
