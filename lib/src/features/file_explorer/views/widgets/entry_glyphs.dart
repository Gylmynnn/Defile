import 'package:flutter/material.dart';

import '../../../../theme/app_theme.dart';

class FolderGlyph extends StatelessWidget {
  const FolderGlyph({super.key, this.width = 76, this.height = 58});

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: Size(width, height), painter: _FolderPainter());
  }
}

class _FolderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double radius = size.width * 0.1;
    final double tabWidth = size.width * 0.5;
    final double tabHeight = size.height * 0.32;
    final double bodyTop = size.height * 0.16;

    final RRect tab = RRect.fromRectAndCorners(
      Rect.fromLTWH(0, 0, tabWidth, tabHeight * 1.7),
      topLeft: Radius.circular(radius),
      topRight: Radius.circular(radius),
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          1,
          bodyTop + 4,
          size.width - 2,
          size.height - bodyTop - 4,
        ),
        Radius.circular(radius),
      ),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.28)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );

    canvas.drawRRect(tab, Paint()..color = AppColors.folderTab);

    final Rect bodyRect = Rect.fromLTWH(
      0,
      bodyTop,
      size.width,
      size.height - bodyTop,
    );
    final RRect body = RRect.fromRectAndRadius(
      bodyRect,
      Radius.circular(radius),
    );

    canvas.drawRRect(
      body,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.folder, AppColors.folderDark],
        ).createShader(bodyRect),
    );

    canvas.drawLine(
      Offset(radius, bodyTop + 0.5),
      Offset(size.width - radius, bodyTop + 0.5),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.08)
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(covariant _FolderPainter oldDelegate) => false;
}

class FileGlyph extends StatelessWidget {
  const FileGlyph({
    super.key,
    required this.name,
    this.width = 46,
    this.height = 58,
  });

  final String name;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(width, height),
      painter: _FilePainter(fileColorFor(name)),
    );
  }
}

const Set<String> kImageExtensions = {
  'png',
  'jpg',
  'jpeg',
  'gif',
  'webp',
  'bmp',
  'ico',
  'heic',
  'tiff',
};

bool isImageFile(String name) {
  final int dot = name.lastIndexOf('.');
  if (dot == -1 || dot == name.length - 1) return false;

  return kImageExtensions.contains(name.substring(dot + 1).toLowerCase());
}

const Set<String> kVideoExtensions = {
  'mp4',
  'mkv',
  'avi',
  'mov',
  'webm',
  'flv',
  'wmv',
  'm4v',
  'mpg',
  'mpeg',
};

const Set<String> kAudioExtensions = {
  'mp3',
  'wav',
  'flac',
  'ogg',
  'm4a',
  'aac',
  'opus',
  'wma',
  'mid',
};

const Set<String> kDocumentExtensions = {
  'pdf',
  'doc',
  'docx',
  'odt',
  'xls',
  'xlsx',
  'ods',
  'ppt',
  'pptx',
  'odp',
  'txt',
  'md',
  'rtf',
  'csv',
};

const Set<String> kArchiveExtensions = {
  'zip',
  'rar',
  '7z',
  'tar',
  'gz',
  'bz2',
  'xz',
  'zst',
  'iso',
  'deb',
  'rpm',
  'apk',
  'jar',
};

const Set<String> kCodeExtensions = {
  'dart',
  'rs',
  'py',
  'js',
  'ts',
  'tsx',
  'jsx',
  'c',
  'h',
  'cpp',
  'hpp',
  'java',
  'kt',
  'go',
  'rb',
  'php',
  'sh',
  'bash',
  'zsh',
  'fish',
  'html',
  'css',
  'scss',
  'json',
  'yaml',
  'yml',
  'toml',
  'xml',
  'sql',
  'lua',
  'vim',
};

const Map<String, List<String>> _specificIconNames = {
  'png': ['image-png'],
  'jpg': ['image-jpeg'],
  'jpeg': ['image-jpeg'],
  'gif': ['image-gif'],
  'webp': ['image-webp'],
  'bmp': ['image-bmp'],
  'svg': ['image-svg+xml'],
  'mp4': ['video-mp4'],
  'mp3': ['audio-mp3'],
  'wav': ['audio-x-wav'],
  'flac': ['audio-x-flac'],
  'pdf': ['application-pdf'],
  'txt': ['text-plain'],
  'md': ['text-markdown', 'text-x-markdown'],
  'rtf': ['text-rtf'],
  'doc': ['x-office-document'],
  'docx': ['x-office-document'],
  'odt': ['x-office-document'],
  'xls': ['x-office-spreadsheet'],
  'xlsx': ['x-office-spreadsheet'],
  'ods': ['x-office-spreadsheet'],
  'csv': ['text-csv'],
  'ppt': ['x-office-presentation'],
  'pptx': ['x-office-presentation'],
  'odp': ['x-office-presentation'],
  'zip': ['application-zip'],
  'rar': ['application-x-rar'],
  '7z': ['application-x-7z-compressed'],
  'tar': ['application-x-tar'],
  'gz': ['application-gzip'],
  'xz': ['application-x-xz'],
  'zst': ['application-zstd'],
  'deb': ['application-x-deb'],
  'rpm': ['application-x-rpm'],
  'iso': ['application-x-cd-image'],
  'apk': ['application-x-java-archive'],
  'jar': ['application-x-java-archive'],
  'py': ['text-x-python'],
  'java': ['text-x-java'],
  'js': ['text-x-javascript'],
  'sh': ['text-x-script'],
  'bash': ['text-x-script'],
  'zsh': ['text-x-script'],
  'fish': ['text-x-script'],
};

List<String> themedIconNamesFor({
  required String name,
  required bool isDirectory,
}) {
  if (isDirectory) {
    return const ['folder', 'inode-directory'];
  }

  final int dot = name.lastIndexOf('.');
  if (dot == -1 || dot == name.length - 1) {
    return const ['text-x-generic'];
  }

  final String ext = name.substring(dot + 1).toLowerCase();
  final List<String> specific = _specificIconNames[ext] ?? const <String>[];

  return [...specific, ..._categoryIconNames(ext), 'text-x-generic'];
}

List<String> _categoryIconNames(String ext) {
  if (kImageExtensions.contains(ext) || ext == 'svg') {
    return const ['image-x-generic'];
  }
  if (kVideoExtensions.contains(ext)) return const ['video-x-generic'];
  if (kAudioExtensions.contains(ext)) return const ['audio-x-generic'];
  if (kDocumentExtensions.contains(ext)) return const ['x-office-document'];
  if (kArchiveExtensions.contains(ext)) return const ['package-x-generic'];
  if (kCodeExtensions.contains(ext)) return const ['text-x-script'];

  return const [];
}

Color fileColorFor(String name) {
  final int dot = name.lastIndexOf('.');
  final String ext = dot == -1 ? '' : name.substring(dot + 1).toLowerCase();

  if (kImageExtensions.contains(ext) || ext == 'svg') {
    return const Color(0xFF6FA89B);
  }
  if (kVideoExtensions.contains(ext)) return const Color(0xFF8E7BB5);
  if (kAudioExtensions.contains(ext)) return const Color(0xFFC08B5C);
  if (kDocumentExtensions.contains(ext)) return const Color(0xFFB0655F);
  if (kArchiveExtensions.contains(ext)) return const Color(0xFFA99055);
  if (kCodeExtensions.contains(ext)) return const Color(0xFF6C93B5);

  return AppColors.fileDefault;
}

class _FilePainter extends CustomPainter {
  _FilePainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final double radius = size.width * 0.16;
    final double fold = size.width * 0.34;

    final Path page = Path()
      ..moveTo(radius, 0)
      ..lineTo(size.width - fold, 0)
      ..lineTo(size.width, fold)
      ..lineTo(size.width, size.height - radius)
      ..quadraticBezierTo(
        size.width,
        size.height,
        size.width - radius,
        size.height,
      )
      ..lineTo(radius, size.height)
      ..quadraticBezierTo(0, size.height, 0, size.height - radius)
      ..lineTo(0, radius)
      ..quadraticBezierTo(0, 0, radius, 0)
      ..close();

    canvas.drawPath(page, Paint()..color = color);

    final Path folded = Path()
      ..moveTo(size.width - fold, 0)
      ..lineTo(size.width - fold, fold)
      ..lineTo(size.width, fold)
      ..close();

    canvas.drawPath(
      folded,
      Paint()..color = Color.lerp(color, Colors.black, 0.28)!,
    );

    final Paint line = Paint()
      ..color = Colors.black.withValues(alpha: 0.16)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    final double left = size.width * 0.2;
    final double right = size.width * 0.8;
    for (int index = 0; index < 3; index++) {
      final double y = size.height * (0.52 + index * 0.14);
      canvas.drawLine(
        Offset(left, y),
        Offset(index == 2 ? size.width * 0.62 : right, y),
        line,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _FilePainter oldDelegate) =>
      oldDelegate.color != color;
}
