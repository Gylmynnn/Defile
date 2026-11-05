import 'dart:async';
import 'dart:io';

import 'package:defile/src/features/file_explorer/bindings/file_explorer_binding.dart';
import 'package:defile/src/features/file_explorer/controllers/explorer_tabs_controller.dart';
import 'package:defile/src/features/file_explorer/controllers/portal_pick_controller.dart';
import 'package:defile/src/features/file_explorer/services/file_manager1_service.dart';
import 'package:defile/src/features/file_explorer/services/font_service.dart';
import 'package:defile/src/features/file_explorer/services/icon_theme_service.dart';
import 'package:defile/src/features/file_explorer/services/portal_file_chooser_service.dart';
import 'package:defile/src/features/file_explorer/services/theme_service.dart';
import 'package:defile/src/features/file_explorer/views/file_explorer_page.dart';
import 'package:defile/src/features/file_explorer/views/widgets/portal_pick_bar.dart';
import 'package:defile/src/rust/frb_generated.dart';
import 'package:defile/src/theme/app_theme.dart';
import 'package:window_manager/window_manager.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class _PortalBackendWindowListener extends WindowListener {
  @override
  void onWindowClose() async {
    if (Get.isRegistered<PortalPickController>()) {
      Get.find<PortalPickController>().markWindowUnwanted();
    }
    await windowManager.hide();
  }

  @override
  void onWindowEvent(String eventName) {
    if (eventName != 'show') return;
    // The GTK embedder maps the window on its first frame no matter how
    // early main() hid it (the race is boot-timing dependent), so re-hide
    // whenever it resurfaces with nothing to show. A pending picker request
    // or a FileManager1 reveal marks the window wanted and stays visible.
    if (!Get.isRegistered<PortalPickController>()) return;
    final PortalPickController picker = Get.find<PortalPickController>();
    if (picker.queue.isNotEmpty || picker.windowWanted) return;
    windowManager.hide();
  }
}

Future<void> main(List<String> args) async {
  ProcessSignal.sigterm.watch().listen((_) => exit(0));
  WidgetsFlutterBinding.ensureInitialized();
  // Browsing photo-heavy folders decodes many 768px-class thumbnails; the
  // default Flutter image cache budgets 100 MiB of decoded bitmaps, which
  // lands directly in the RSS of the long-lived portal backend. 48 MiB
  // still holds well over a hundred grid thumbnails.
  PaintingBinding.instance.imageCache.maximumSizeBytes = 48 << 20;
  final bool portalBackend = args.contains('--dbus-portal');
  final PortalFileChooserService fileChooser = PortalFileChooserService();
  final FileManager1Service fileManager = FileManager1Service();

  final List<dynamic> initResults = await Future.wait<dynamic>(
    <Future<dynamic>>[
      RustLib.init(),
      windowManager.ensureInitialized(),
      fileManager.start(),
      fileChooser.start(),
    ],
  );

  final bool fileChooserClaimed = initResults[3] as bool;

  Get.put(
    // Dedicated portal backends exit once nothing uses them; the next
    // FileChooser call re-activates the process via D-Bus. GUI instances
    // must never self-exit, so they pass null. The default can be
    // overridden (or disabled with 0) for testing via the environment.
    PortalPickController(
      idleExitAfter: portalBackend
          ? Duration(
              seconds:
                  int.tryParse(
                    Platform.environment['DEFILE_PORTAL_IDLE_EXIT_SECS'] ?? '',
                  ) ??
                  300,
            )
          : null,
    ),
  );
  Get.put(fileChooser);
  if (portalBackend && !fileChooserClaimed) {
    exit(0);
  }

  ExplorerTabsController.launchPath = _resolveLaunchPath(args);

  final fontService = Get.put(FontService());
  final themeService = Get.put(ThemeService());
  final iconThemeService = Get.put(IconThemeService());

  await Future.wait(<Future<void>>[
    fontService.init(),
    themeService.init(),
    iconThemeService.init(),
  ]);

  final windowOptions = WindowOptions(
    titleBarStyle: TitleBarStyle.hidden,
    skipTaskbar: true,
  );

  if (portalBackend) {
    windowManager.addListener(_PortalBackendWindowListener());
  }

  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    if (portalBackend) {
      await windowManager.setTitle('Defile — File Chooser');
      await windowManager.setPreventClose(true);
      await windowManager.hide();
      return;
    }
    await windowManager.show();
    await windowManager.focus();
  });

  runApp(const RootApp());
  if (portalBackend) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      windowManager.hide();
    });
    unawaited(fileChooser.ensureFrontendWired());
  }
}

String? _resolveLaunchPath(List<String> args) {
  for (final String arg in args) {
    if (arg.startsWith('-')) continue; // ignore flags

    String path = arg;
    if (path.startsWith('file://')) {
      try {
        path = Uri.parse(path).toFilePath();
      } on FormatException {
        continue;
      }
    }
    if (path.isEmpty) continue;
    if (path.length > 1 && path.endsWith('/')) {
      path = path.substring(0, path.length - 1);
    }

    if (Directory(path).existsSync()) return path;
    if (File(path).existsSync()) return File(path).parent.path;
  }
  return null;
}

class RootApp extends StatelessWidget {
  const RootApp({super.key});

  @override
  Widget build(BuildContext context) {
    final FontService fontService = Get.find<FontService>();
    final ThemeService themeService = Get.find<ThemeService>();

    return Obx(() {
      final String font = fontService.fontFamily.value;
      final palette = themeService.palette;
      final accent = themeService.accent;

      return GetMaterialApp(
        title: 'Defile',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark(
          palette: palette,
          accentPreset: accent,
          fontFamily: font.isEmpty ? null : font,
        ),
        initialBinding: FileExplorerBinding(),
        builder: (BuildContext context, Widget? child) => Obx(
          () => _UiScaler(
            scale: themeService.uiScale.value,
            child: Stack(
              children: [
                child ?? const SizedBox.shrink(),
                // A pending FileChooser request must win over anything drawn
                // beneath it (toasts, context menus), so it gets its own
                // event-handling layer inside the scaled surface.
                const _PortalLayer(),
              ],
            ),
          ),
        ),
        home: const FileExplorerPage(),
      );
    });
  }
}

/// Wraps [PortalPickBar] so only the bar's own widgets take part in hit
/// testing: while no request is pending the layer is 'invisible' and clicks
/// pass straight through to the app below it.
class _PortalLayer extends StatelessWidget {
  const _PortalLayer();

  @override
  Widget build(BuildContext context) {
    final PortalPickController picker = Get.find<PortalPickController>();
    return Obx(() {
      if (picker.queue.isEmpty) {
        return const Positioned.fill(
          child: IgnorePointer(child: SizedBox.shrink()),
        );
      }
      return const Positioned.fill(child: PortalPickBar());
    });
  }
}

/// Scales the whole application surface so the interface can be enlarged or
/// shrunk like a display/monitor scale setting.
class _UiScaler extends StatelessWidget {
  const _UiScaler({required this.scale, required this.child});

  final double scale;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if ((scale - 1.0).abs() < 0.001) {
      return child;
    }

    final MediaQueryData mediaQuery = MediaQuery.of(context);
    final Size logicalSize = mediaQuery.size / scale;

    return MediaQuery(
      data: mediaQuery.copyWith(size: logicalSize),
      child: FittedBox(
        fit: BoxFit.fill,
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: logicalSize.width,
          height: logicalSize.height,
          child: child,
        ),
      ),
    );
  }
}
