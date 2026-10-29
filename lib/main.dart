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

/// Launched by D-Bus activation (xdg-desktop-portal). Runs without a visible
/// window: xdg-desktop-portal only wires the FileChooser interface while the
/// activated backend stays alive, so a closed window would silently kill the
/// portal for the whole session. The window appears when a picker request
/// arrives and closing it merely hides it again.
class _PortalBackendWindowListener extends WindowListener {
  @override
  void onWindowClose() async {
    await windowManager.hide();
  }
}

Future<void> main(List<String> args) async {
  // systemd stops D-Bus-activated units (and the whole session cgroup at
  // logout) with SIGTERM. Relying on the default disposition has been
  // observed to leave the process alive ("remains running after unit
  // stopped"), still holding the bus name and blocking the next activation —
  // so exit explicitly instead.
  ProcessSignal.sigterm.watch().listen((_) => exit(0));

  WidgetsFlutterBinding.ensureInitialized();

  // Claim the D-Bus names before anything slow: xdg-desktop-portal and
  // browsers activate org.freedesktop.impl.portal.desktop.defile /
  // org.freedesktop.FileManager1 with a ~25 s D-Bus timeout, and a cold
  // AppImage start (squashfs mount, engine, fonts, theme, first frame) can
  // exceed it — the daemon then gives up and never exports the FileChooser
  // interface for the rest of the session. Requests that arrive while the
  // UI is still booting simply queue up in [PortalPickController]. The
  // claims finish in milliseconds; awaiting them lets a portal backend that
  // lost the name race (e.g. the systemd unit racing a D-Bus activation)
  // bow out immediately instead of lurking as an invisible duplicate.
  final bool portalBackend = args.contains('--dbus-portal');
  final PortalFileChooserService fileChooser = PortalFileChooserService();
  final List<bool> claimed = await Future.wait(<Future<bool>>[
    FileManager1Service().start(),
    fileChooser.start(),
  ]);
  Get.put(PortalPickController());
  Get.put(fileChooser);
  if (portalBackend && !claimed.every((bool owned) => owned)) {
    exit(0);
  }

  await RustLib.init();
  await windowManager.ensureInitialized();

  // xdg-open hands us the target as a CLI argument (plain path or file://
  // URI from the %u desktop entry field). Directories open as the first
  // tab; files open their parent directory.
  ExplorerTabsController.launchPath = _resolveLaunchPath(args);

  final fontService = Get.put(FontService());
  await fontService.init();

  final themeService = Get.put(ThemeService());
  await themeService.init();

  final iconThemeService = Get.put(IconThemeService());
  await iconThemeService.init();

  final windowOptions = WindowOptions(
    titleBarStyle: TitleBarStyle.hidden,
    skipTaskbar: true,
  );

  if (portalBackend) {
    windowManager.addListener(_PortalBackendWindowListener());
  }

  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    if (portalBackend) {
      // Headless until a picker request reveals the window; closing it must
      // never take the backend process (and the claimed D-Bus name) down.
      await windowManager.setPreventClose(true);
      await windowManager.hide();
      return;
    }
    await windowManager.show();
    await windowManager.focus();
  });

  runApp(const RootApp());

  // Portal backend only: verify the daemon actually wired us up, and bounce
  // it once if its startup introspection raced our cold start.
  if (portalBackend) {
    unawaited(fileChooser.ensureFrontendWired());
  }
}

/// Resolves the first positional CLI argument into the directory the first
/// tab should open. Accepts plain paths and `file://` URIs; a file argument
/// opens its parent directory. Returns null when nothing valid is given and
/// the app falls back to Home.
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
                const PortalPickBar(),
              ],
            ),
          ),
        ),
        home: const FileExplorerPage(),
      );
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
