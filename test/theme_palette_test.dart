import 'package:defile/src/theme/theme_palette.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('light and dark palettes are detected', () {
    expect(AppPalettes.catppuccinLatte.isLight, isTrue);
    expect(AppPalettes.catppuccinMocha.isLight, isFalse);
    expect(AppPalettes.tokyoNight.isLight, isFalse);
  });
}
