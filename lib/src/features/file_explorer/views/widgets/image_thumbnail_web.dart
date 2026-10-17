import 'package:flutter/material.dart';

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
  Widget build(BuildContext context) => fallback;
}
