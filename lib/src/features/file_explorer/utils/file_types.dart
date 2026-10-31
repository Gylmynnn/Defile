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
  'astro',
  'bat',
  'bash',
  'c',
  'cc',
  'cfg',
  'clj',
  'cmd',
  'cmake',
  'conf',
  'cpp',
  'cs',
  'css',
  'cxx',
  'dart',
  'diff',
  'env',
  'erl',
  'ex',
  'exs',
  'fish',
  'go',
  'gradle',
  'groovy',
  'graphql',
  'gql',
  'h',
  'hpp',
  'hs',
  'htm',
  'html',
  'ini',
  'jl',
  'java',
  'js',
  'json',
  'jsonl',
  'jsx',
  'kt',
  'kts',
  'less',
  'lua',
  'md',
  'mdx',
  'mjs',
  'cjs',
  'mk',
  'nix',
  'patch',
  'php',
  'pl',
  'pm',
  'properties',
  'proto',
  'ps1',
  'py',
  'rb',
  'rs',
  'sass',
  'scala',
  'scss',
  'sh',
  'sol',
  'sql',
  'styl',
  'svelte',
  'svg',
  'swift',
  'toml',
  'ts',
  'tsx',
  'v',
  'vim',
  'vue',
  'xhtml',
  'xml',
  'yaml',
  'yml',
  'zig',
  'zsh',
  'lock',
  'gemspec',
  'pp',
  'pyw',
  'pyi',
  'r',
};

/// Extensionless / dotfile names that are still text.
const Set<String> kTextFileNames = {
  'makefile',
  'dockerfile',
  'license',
  'licence',
  'changelog',
  'authors',
  'copying',
  'notice',
  'contributing',
  '.gitignore',
  '.gitattributes',
  '.editorconfig',
  '.dockerignore',
  '.npmrc',
  '.nvmrc',
  '.babelrc',
  '.prettierrc',
  '.eslintrc',
};

const Set<String> kTextExtensions = {
  ...kCodeExtensions,
  'txt',
  'log',
  'csv',
  'tsv',
  'gitignore',
  'gitattributes',
  'editorconfig',
  'dockerignore',
  'npmrc',
  'nvmrc',
  'babelrc',
  'prettierrc',
  'eslintrc',
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

bool isTextFile(String name) =>
    kTextFileNames.contains(name.toLowerCase()) ||
    kTextExtensions.contains(fileExtension(name));

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
