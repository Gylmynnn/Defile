import 'package:defile/src/features/file_explorer/utils/app_toast.dart';
import 'package:defile/src/features/file_explorer/utils/transfer_progress.dart';
import 'package:material_ui/material_ui.dart';
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

  testWidgets('loading toast updates live percentage text', (tester) async {
    await tester.pumpWidget(
      GetMaterialApp(home: const Scaffold(body: SizedBox())),
    );

    final ValueNotifier<AppToastProgress?> progress =
        ValueNotifier<AppToastProgress?>(
          const AppToastProgress(fraction: 0.25, message: 'Unpacking file.7z'),
        );

    showAppToast(
      title: 'Extracting',
      message: 'Unpacking file.7z',
      variant: AppToastVariant.loading,
      progress: progress,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Extracting'), findsOneWidget);
    expect(find.text('25%'), findsOneWidget);

    progress.value = const AppToastProgress(fraction: 0.85);
    await tester.pump();
    expect(find.text('85%'), findsOneWidget);

    showAppToast(
      title: 'Extracted',
      message: 'Done',
      variant: AppToastVariant.success,
      duration: const Duration(milliseconds: 500),
    );
    progress.dispose();
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('TransferProgress overlay displays percentage', (tester) async {
    await tester.pumpWidget(
      GetMaterialApp(home: const Scaffold(body: SizedBox())),
    );

    final TransferProgress progress = TransferProgress(
      title: 'Copying items',
      total: 4,
    );
    showTransferProgress(progress);
    await tester.pump();

    expect(find.text('0 of 4 items'), findsOneWidget);
    expect(find.text('0%'), findsOneWidget);

    progress.update(completed: 2, fraction: 0.62, detail: '2 of 4 items · a.bin');
    await tester.pump();

    expect(find.text('2 of 4 items · a.bin'), findsOneWidget);
    expect(find.text('62%'), findsOneWidget);

    progress.close();
    await tester.pump();
  });
}
