import 'dart:io';

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
          cacheWidth: (width * devicePixelRatio).round(),
          gaplessPlayback: true,
          errorBuilder: (context, error, stackTrace) => Center(child: fallback),
        ),
      ),
    );
  }
}
