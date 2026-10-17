import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../services/icon_theme_service.dart';

class ThemedIcon extends StatelessWidget {
  const ThemedIcon({
    super.key,
    required this.iconNames,
    required this.size,
    required this.fallback,
    this.theme,
  });

  final List<String> iconNames;
  final double size;
  final Widget fallback;
  final String? theme;

  @override
  Widget build(BuildContext context) {
    final IconThemeService service = Get.find<IconThemeService>();
    final double devicePixelRatio = MediaQuery.devicePixelRatioOf(context);

    final int lookupPixelSize = (size * devicePixelRatio).round().clamp(8, 512);

    Widget buildImage(Uint8List bytes) {
      return Image.memory(
        bytes,
        width: size,
        height: size,
        fit: BoxFit.contain,
        gaplessPlayback: true,
        filterQuality: FilterQuality.medium,
        errorBuilder: (context, error, stackTrace) => fallback,
      );
    }

    Widget buildIcon() {
      final String? override = theme;
      if (override == null && service.themeName.value.isEmpty) {
        return fallback;
      }

      if (service.hasIconPng(iconNames, lookupPixelSize, theme: override)) {
        final Uint8List? cached = service.cachedIconPng(
          iconNames,
          lookupPixelSize,
          theme: override,
        );

        return cached == null ? fallback : buildImage(cached);
      }

      return FutureBuilder<Uint8List?>(
        future: service.iconPng(iconNames, lookupPixelSize, theme: override),
        builder: (context, snapshot) {
          final Uint8List? bytes = snapshot.data;
          if (bytes == null) return fallback;

          return buildImage(bytes);
        },
      );
    }

    if (theme != null) return buildIcon();

    return Obx(buildIcon);
  }
}
