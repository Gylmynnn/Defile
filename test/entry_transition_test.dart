import 'package:defile/src/features/file_explorer/services/icon_theme_service.dart';
import 'package:defile/src/features/file_explorer/services/theme_service.dart';
import 'package:defile/src/features/file_explorer/views/widgets/entry_transition.dart';
import 'package:defile/src/features/file_explorer/views/widgets/entry_views.dart';
import 'package:defile/src/rust/api/file_entry.dart' as rust;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

void main() {
  setUp(() {
    Get.put(IconThemeService());
    Get.put(ThemeService());
  });
  tearDown(Get.reset);

  final rust.FileEntry entry = rust.FileEntry(
    name: 'a.txt',
    path: '/a.txt',
    isDirectory: false,
    isFile: true,
    sizeBytes: BigInt.zero,
    modifiedSeconds: 0,
  );
  final RxSet<String> selected = <String>{}.obs;

  Widget harness(String directory) => MaterialApp(
    home: Scaffold(
      body: EntryTransitionScope(
        transitionKey: directory,
        child: EntryGridView(
          entries: [entry],
          selectedPaths: selected,
          onPress: (_) {},
          onTap: (_) {},
          onOpen: (_) {},
          onMenu: (entry, position) {},
        ),
      ),
    ),
  );

  Finder revealOpacity() => find.descendant(
    of: find.byType(EntryReveal),
    matching: find.byType(Opacity),
  );

  double revealOpacityValue(WidgetTester tester) =>
      tester.widget<Opacity>(revealOpacity().first).opacity;

  testWidgets('opening another directory fades the entries in', (tester) async {
    await tester.pumpWidget(harness('/first'));
    expect(revealOpacityValue(tester), 1.0);

    await tester.pumpWidget(harness('/second'));
    expect(revealOpacityValue(tester), lessThan(1.0));

    await tester.pump(const Duration(milliseconds: 110));
    final double mid = revealOpacityValue(tester);
    expect(mid, greaterThan(0.0));
    expect(mid, lessThan(1.0));

    await tester.pumpAndSettle();
    expect(revealOpacityValue(tester), 1.0);
  });

  testWidgets('rebuilding the same directory keeps the entries settled', (
    tester,
  ) async {
    await tester.pumpWidget(harness('/same'));
    await tester.pumpAndSettle();

    await tester.pumpWidget(harness('/same'));
    expect(revealOpacityValue(tester), 1.0);
  });

  testWidgets('disabled animations skip the reveal', (tester) async {
    await tester.pumpWidget(harness('/plain'));
    await tester.pumpAndSettle();

    Get.find<ThemeService>().animationsEnabled.value = false;

    await tester.pumpWidget(harness('/quiet'));
    expect(revealOpacity().evaluate().isEmpty, isTrue);
  });
}
