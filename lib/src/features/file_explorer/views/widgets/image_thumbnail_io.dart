import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../theme/app_theme.dart';

class ImageThumbnail extends StatelessWidget {
  const ImageThumbnail({
    super.key,
    required this.path,
    required this.width,
    required this.height,
    required this.fallback,
    this.fit = BoxFit.cover,
  });

  final String path;
  final double width;
  final double height;
  final Widget fallback;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final double devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
    final double radius = width < 24 ? 2.5 : 5;

    // Decode at 2x the on-screen size, then let the GPU's mipmapped filter
    // do the final downscale. Decoding straight to the display size forces
    // the codec to shrink in one bilinear step, which is what makes
    // thumbnails look blocky. 2x costs a few dozen KB per thumb — for a
    // square box it also keeps portrait and landscape sources at or above
    // the box size, so cover never has to upscale.
    final int cacheWidth = math.min(
      (math.max(width, height) * devicePixelRatio * 2).round(),
      768,
    );

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: colors.border),
        color: colors.surfaceHigh,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius - 1),
        child: Image.file(
          File(path),
          width: width,
          height: height,
          fit: fit,
          cacheWidth: cacheWidth,
          filterQuality: FilterQuality.medium,
          gaplessPlayback: true,
          errorBuilder: (context, error, stackTrace) => Center(child: fallback),
        ),
      ),
    );
  }
}
