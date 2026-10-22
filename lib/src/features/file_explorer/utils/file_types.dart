const Set<String> kRasterImageExtensions = {
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

const Set<String> kImageExtensions = {...kRasterImageExtensions, 'svg'};

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
  'oga',
  'm4a',
  'm4b',
  'aac',
  'opus',
  'wma',
  'aiff',
  'alac',
  'mid',
  'midi',
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

const Set<String> kTextExtensions = {
  'txt',
  'md',
  'json',
  'yaml',
  'yml',
  'toml',
  'xml',
  'html',
  'css',
  'js',
  'ts',
  'jsx',
  'tsx',
  'dart',
  'rs',
  'go',
  'py',
  'java',
  'c',
  'cpp',
  'h',
  'hpp',
  'sh',
  'bash',
  'zsh',
  'fish',
  'sql',
  'log',
  'conf',
  'ini',
  'env',
};

const Set<String> kConvertibleDocumentExtensions = {
  'doc',
  'docx',
  'odt',
  'rtf',
};

String fileExtension(String name) {
  final int dot = name.lastIndexOf('.');
  if (dot == -1 || dot == name.length - 1) return '';

  return name.substring(dot + 1).toLowerCase();
}

bool isRasterImageFile(String name) =>
    kRasterImageExtensions.contains(fileExtension(name));

bool isVideoFile(String name) => kVideoExtensions.contains(fileExtension(name));

bool isAudioFile(String name) => kAudioExtensions.contains(fileExtension(name));

bool isTextFile(String name) => kTextExtensions.contains(fileExtension(name));

bool isPdfFile(String name) => fileExtension(name) == 'pdf';

bool isConvertibleDocumentFile(String name) =>
    kConvertibleDocumentExtensions.contains(fileExtension(name));

String fileTypeShortLabel(String name) {
  final String ext = fileExtension(name);
  return ext.isEmpty ? 'File' : ext.toUpperCase();
}

String fileTypeLabel(String name) {
  final String ext = fileExtension(name);
  return ext.isEmpty ? 'File' : '${ext.toUpperCase()} File';
}
