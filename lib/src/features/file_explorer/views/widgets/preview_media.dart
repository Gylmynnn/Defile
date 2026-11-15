part of 'preview_panel.dart';

class _ImagePreview extends StatelessWidget {
  const _ImagePreview({required this.file});

  final rust.FileEntry file;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Decode at the panel's display size (2x for crispness,
              // capped) instead of the source resolution: a 24 MP photo
              // decoded raw costs ~96 MiB of bitmap that then sits in the
              // image cache long after the file is deselected.
              final double dpr = MediaQuery.devicePixelRatioOf(context);
              final double box = math.max(
                constraints.maxWidth,
                constraints.maxHeight,
              );
              final int cacheWidth = box.isFinite
                  ? math.min((box * dpr).round(), 1024)
                  : 768;
              return Image.file(
                File(file.path),
                cacheWidth: cacheWidth,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.broken_image,
                        size: 48,
                        color: context.colors.textFaint,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Failed to load image',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: context.colors.textFaint,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _MediaPlaceholder extends StatelessWidget {
  const _MediaPlaceholder({required this.isVideo});

  final bool isVideo;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isVideo ? Icons.videocam_off : Icons.audio_file_outlined,
              size: 48,
              color: context.colors.textFaint,
            ),
            const SizedBox(height: 12),
            Text(
              isVideo ? 'Video preview unavailable' : 'Audio preview unavailable',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, color: context.colors.textFaint),
            ),
            const SizedBox(height: 4),
            Text(
              'Open the file with an external player.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11.5, color: context.colors.textFaint),
            ),
          ],
        ),
      ),
    );
  }
}
