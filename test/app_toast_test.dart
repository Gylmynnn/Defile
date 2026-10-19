import 'package:defile/src/features/file_explorer/utils/app_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

void main() {
  testWidgets('showAppToast renders top-right and auto-dismisses', (
    tester,
  ) async {
    await tester.pumpWidget(
      GetMaterialApp(home: const Scaffold(body: SizedBox())),
    );

    showAppToast(
      title: 'Deleted',
      message: '1 item permanently deleted.',
      duration: const Duration(seconds: 1),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Deleted'), findsOneWidget);
    expect(find.text('1 item permanently deleted.'), findsOneWidget);

    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Deleted'), findsNothing);
  });
}
