import 'package:defile/src/features/file_explorer/services/icon_theme_service.dart';
import 'package:defile/src/features/file_explorer/views/widgets/themed_icon.dart';
import 'package:defile/src/rust/frb_generated.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

void main() {
  setUpAll(() async {
    await RustLib.init(
      externalLibrary: ExternalLibrary.open(
        'build/linux/x64/debug/bundle/lib/librust_lib_defile.so',
      ),
    );
  });

  tearDown(Get.reset);

  testWidgets('selecting a theme updates ThemedIcon', (tester) async {
    Get.put(IconThemeService());
    final service = Get.find<IconThemeService>();

    await tester.runAsync(service.init);

    final String originalTheme = service.themeName.value;
    addTearDown(() => tester.runAsync(() => service.setTheme(originalTheme)));

    if (service.themes.length < 2) {
      markTestSkipped('Needs at least two usable icon themes');
      return;
    }
    final String firstTheme = service.themes[0].name;
    final String secondTheme = service.themes[1].name;

    await tester.pumpWidget(
      GetMaterialApp(
        home: Center(
          child: ThemedIcon(
            iconNames: const ['folder', 'inode-directory'],
            size: 48,
            fallback: const Text('fallback'),
          ),
        ),
      ),
    );

    expect(find.text('fallback'), findsOneWidget);

    Future<void> settleFfi() async {
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 120)),
      );
      await tester.pump();
      await tester.pump();
    }

    await tester.runAsync(() => service.setTheme(firstTheme));
    await settleFfi();

    expect(find.text('fallback'), findsNothing);
    final first = tester.widget<Image>(find.byType(Image)).image;

    await tester.runAsync(() => service.setTheme(secondTheme));
    await settleFfi();

    final second = tester.widget<Image>(find.byType(Image)).image;
    expect(identical(first, second), isFalse);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(
      GetMaterialApp(
        home: Center(
          child: ThemedIcon(
            iconNames: const ['folder', 'inode-directory'],
            size: 48,
            fallback: const Text('fallback'),
          ),
        ),
      ),
    );

    expect(find.text('fallback'), findsNothing);

    await tester.runAsync(() => service.setTheme(''));
    await tester.pump();

    expect(find.text('fallback'), findsOneWidget);
  });

  testWidgets('grid size (56) loads icons from the selected theme', (
    tester,
  ) async {
    Get.put(IconThemeService());
    final service = Get.find<IconThemeService>();

    await tester.runAsync(service.init);

    if (service.themes.isEmpty) {
      markTestSkipped('Needs at least one usable icon theme');
      return;
    }
    final String originalTheme = service.themeName.value;
    addTearDown(() => tester.runAsync(() => service.setTheme(originalTheme)));

    await tester.runAsync(() => service.setTheme(service.themes.first.name));

    await tester.pumpWidget(
      GetMaterialApp(
        home: Center(
          child: ThemedIcon(
            iconNames: const ['folder', 'inode-directory'],
            size: 56,
            fallback: const Text('fallback'),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 120)),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byType(Image), findsOneWidget);
    expect(find.text('fallback'), findsNothing);
  });
}
