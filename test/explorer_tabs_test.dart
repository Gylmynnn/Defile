import 'package:defile/src/features/file_explorer/controllers/explorer_tabs_controller.dart';
import 'package:defile/src/features/file_explorer/controllers/file_explorer_controller.dart';
import 'package:defile/src/features/file_explorer/services/file_system_service.dart';
import 'package:defile/src/features/file_explorer/views/widgets/explorer_tab_bar.dart';
import 'package:defile/src/rust/api/file_entry.dart' as rust;
import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

class _FakeFs extends FileSystemService {
  _FakeFs();

  @override
  Future<List<rust.FileEntry>> listDirectory(String path) async => const [];
}

void main() {
  tearDown(Get.reset);

  group('ExplorerTabsController', () {
    test('initializes with a single default tab', () {
      final tabs = ExplorerTabsController(_FakeFs());
      tabs.onInit();

      expect(tabs.tabs.length, 1);
      expect(tabs.activeIndex.value, 0);
      expect(tabs.canCloseTabs, isFalse);
      expect(tabs.canReopenClosedTab, isFalse);
    });

    test('addTab appends and activates new tab', () {
      final tabs = ExplorerTabsController(_FakeFs());
      tabs.onInit();

      final tab2 = tabs.addTab(path: '/custom/path');

      expect(tabs.tabs.length, 2);
      expect(tabs.activeIndex.value, 1);
      expect(tabs.activeTab.id, tab2.id);
      expect(tabs.activeController.initialPath, '/custom/path');
      expect(tabs.canCloseTabs, isTrue);
    });

    test('selectTab and selectRelative cycle through tabs', () {
      final tabs = ExplorerTabsController(_FakeFs());
      tabs.onInit();
      tabs.addTab(path: '/tab2');
      tabs.addTab(path: '/tab3');

      expect(tabs.activeIndex.value, 2);

      tabs.selectTab(0);
      expect(tabs.activeIndex.value, 0);

      // Next tab
      tabs.selectRelative(1);
      expect(tabs.activeIndex.value, 1);

      // Previous tab with wrap-around
      tabs.selectRelative(-1);
      expect(tabs.activeIndex.value, 0);
      tabs.selectRelative(-1);
      expect(tabs.activeIndex.value, 2);
    });

    test('duplicateTab copies path and viewMode', () {
      final tabs = ExplorerTabsController(_FakeFs());
      tabs.onInit();
      tabs.activeController.currentPath.value = '/source/dir';
      tabs.activeController.viewMode.value = ExplorerViewMode.compact;

      final dup = tabs.duplicateTab(0);

      expect(tabs.tabs.length, 2);
      expect(tabs.activeIndex.value, 1);
      expect(dup.controller.initialPath, '/source/dir');
      expect(dup.controller.viewMode.value, ExplorerViewMode.compact);
    });

    test('closeTab preserves state for reopenClosedTab', () {
      final tabs = ExplorerTabsController(_FakeFs());
      tabs.onInit();
      tabs.addTab(path: '/tab2');
      tabs.activeController.currentPath.value = '/tab2';
      tabs.activeController.viewMode.value = ExplorerViewMode.list;

      expect(tabs.tabs.length, 2);
      expect(tabs.activeIndex.value, 1);

      tabs.closeTab(1);

      expect(tabs.tabs.length, 1);
      expect(tabs.activeIndex.value, 0);
      expect(tabs.canReopenClosedTab, isTrue);

      final restored = tabs.reopenClosedTab();

      expect(restored, isNotNull);
      expect(tabs.tabs.length, 2);
      expect(tabs.activeIndex.value, 1);
      expect(restored!.controller.initialPath, '/tab2');
      expect(restored.controller.viewMode.value, ExplorerViewMode.list);
    });

    test('closeOtherTabs closes all except target', () {
      final tabs = ExplorerTabsController(_FakeFs());
      tabs.onInit();
      tabs.addTab(path: '/tab2');
      tabs.addTab(path: '/tab3');

      expect(tabs.tabs.length, 3);

      tabs.closeOtherTabs(1);

      expect(tabs.tabs.length, 1);
      expect(tabs.activeIndex.value, 0);
      expect(tabs.activeController.initialPath, '/tab2');
    });

    test('closeTabsToTheRight closes only subsequent tabs', () {
      final tabs = ExplorerTabsController(_FakeFs());
      tabs.onInit();
      tabs.addTab(path: '/tab2');
      tabs.addTab(path: '/tab3');
      tabs.addTab(path: '/tab4');

      expect(tabs.tabs.length, 4);

      tabs.closeTabsToTheRight(1);

      expect(tabs.tabs.length, 2);
      expect(tabs.activeIndex.value, 1);
      expect(tabs.tabs[0].controller.initialPath, isNull);
      expect(tabs.tabs[1].controller.initialPath, '/tab2');
    });

    test('reorderTab shifts tabs and preserves active selection', () {
      final tabs = ExplorerTabsController(_FakeFs());
      tabs.onInit();
      final t2 = tabs.addTab(path: '/tab2');
      final t3 = tabs.addTab(path: '/tab3');

      // Currently active is t3 (index 2)
      expect(tabs.activeTab.id, t3.id);

      // Move t3 from index 2 to index 0
      tabs.reorderTab(2, 0);

      expect(tabs.tabs[0].id, t3.id);
      expect(tabs.tabs[2].id, t2.id);
      expect(tabs.activeIndex.value, 0);
      expect(tabs.activeTab.id, t3.id);
    });
  });

  group('ExplorerTabBar widget', () {
    testWidgets('renders tabs, adds tab via + button, and switches tab on tap', (
      tester,
    ) async {
      final controller = Get.put(ExplorerTabsController(_FakeFs()));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: const [
                ExplorerTabBar(),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Initially 1 tab with title 'Home'
      expect(find.text('Home'), findsOneWidget);

      // Find the "+" button and tap it
      final plusButton = find.byTooltip('New tab (Ctrl+T)');
      expect(plusButton, findsOneWidget);

      await tester.tap(plusButton);
      await tester.pumpAndSettle();

      // Now 2 tabs exist
      expect(controller.tabs.length, 2);
      expect(controller.activeIndex.value, 1);

      // Tap first tab to switch back
      await tester.tap(find.byKey(ValueKey(controller.tabs[0].id)));
      await tester.pumpAndSettle();

      expect(controller.activeIndex.value, 0);
    });

    testWidgets('closes tab when clicking the close xmark button', (
      tester,
    ) async {
      final controller = Get.put(ExplorerTabsController(_FakeFs()));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: const [
                ExplorerTabBar(),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open a second tab
      controller.addTab(path: '/tab2');
      await tester.pumpAndSettle();
      expect(controller.tabs.length, 2);

      // In active tab (tab2), close button is rendered
      final closeBtn = find.byIcon(CupertinoIcons.xmark);
      expect(closeBtn, findsOneWidget);

      await tester.tap(closeBtn);
      await tester.pumpAndSettle();

      expect(controller.tabs.length, 1);
      expect(controller.activeIndex.value, 0);
    });

    testWidgets('middle click on tab closes it', (tester) async {
      final controller = Get.put(ExplorerTabsController(_FakeFs()));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: const [
                ExplorerTabBar(),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      controller.addTab(path: '/tab2');
      await tester.pumpAndSettle();
      expect(controller.tabs.length, 2);

      // Perform a tertiary (middle) click on second tab
      final tab2Finder = find.byKey(ValueKey(controller.tabs[1].id));
      await tester.tap(tab2Finder, buttons: kTertiaryButton);
      await tester.pumpAndSettle();

      expect(controller.tabs.length, 1);
    });
  });
}
