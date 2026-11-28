import 'package:defile/src/features/file_explorer/controllers/file_explorer_controller.dart';
import 'package:defile/src/features/file_explorer/services/file_system_service.dart';
import 'package:defile/src/features/file_explorer/services/theme_service.dart';
import 'package:defile/src/features/file_explorer/views/widgets/app_sidebar.dart';
import 'package:defile/src/rust/api/file_entry.dart' as rust;
import 'package:defile/src/rust/api/system.dart' as rust_system;
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

class _FakeFs extends FileSystemService {
  @override
  Future<List<rust.FileEntry>> listDirectory(String path) async => const [];
}

void main() {
  tearDown(Get.reset);

  testWidgets('drive tile shows usage as soon as driveUsages updates', (
    tester,
  ) async {
    Get.put<ThemeService>(ThemeService());
    final controller = FileExplorerController(_FakeFs());
    controller.drivePlaces.assignAll(<rust_system.Place>[
      rust_system.Place(
        label: 'Disk',
        path: '/',
        kind: rust_system.PlaceKind.drive,
      ),
    ]);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 260,
            height: 400,
            child: AppSidebar(controller: controller),
          ),
        ),
      ),
    );

    // Before usage arrives the card shows only the name.
    expect(find.text('Disk'), findsOneWidget);
    expect(find.textContaining(' of '), findsNothing);

    // Arriving later must rebuild the tile without any other interaction.
    controller.driveUsages['/'] = rust_system.DiskUsage(
      path: '/',
      totalBytes: BigInt.from(100) * BigInt.from(1024 * 1024 * 1024),
      freeBytes: BigInt.from(50) * BigInt.from(1024 * 1024 * 1024),
      usedBytes: BigInt.from(50) * BigInt.from(1024 * 1024 * 1024),
    );
    await tester.pump();

    expect(find.text('50%'), findsOneWidget);
    expect(find.text('50 GB of 100 GB'), findsOneWidget);
  });
}