import 'package:defile/src/features/file_explorer/utils/file_types.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('classifies extensions consistently', () {
    expect(fileExtension('photo.PNG'), 'png');
    expect(fileExtension('.bashrc'), 'bashrc');
    expect(fileExtension('README'), '');

    expect(isRasterImageFile('photo.png'), isTrue);
    expect(isRasterImageFile('vector.svg'), isFalse);
    expect(kImageExtensions.contains(fileExtension('vector.svg')), isTrue);

    expect(isVideoFile('clip.mkv'), isTrue);
    expect(isAudioFile('track.ogg'), isTrue);
    expect(isTextFile('main.dart'), isTrue);
    expect(isPdfFile('book.pdf'), isTrue);
    expect(isConvertibleDocumentFile('letter.docx'), isTrue);

    expect(fileTypeShortLabel('archive.tar.gz'), 'GZ');
    expect(fileTypeLabel('README'), 'File');
  });

  test('recognizes extractable archives and strips compound suffixes', () {
    expect(isExtractableArchiveName('backup.7z'), isTrue);
    expect(isExtractableArchiveName('BACKUP.7Z'), isTrue);
    expect(isExtractableArchiveName('movie.rar'), isTrue);
    expect(isExtractableArchiveName('distro.iso'), isTrue);
    expect(isExtractableArchiveName('pkg.deb'), isTrue);
    expect(isExtractableArchiveName('pkg.rpm'), isTrue);
    expect(isExtractableArchiveName('src.tar.xz'), isTrue);
    expect(isExtractableArchiveName('notes.txt.gz'), isTrue);

    expect(archiveRootName('src.tar.gz'), 'src');
    expect(archiveRootName('src.tar.xz'), 'src');
    expect(archiveRootName('src.TAR.BZ2'), 'src');
    expect(archiveRootName('src.tar.zst'), 'src');
    expect(archiveRootName('src.tgz'), 'src');
    expect(archiveRootName('backup.7z'), 'backup');
    expect(archiveRootName('notes.txt.gz'), 'notes.txt');
    expect(archiveRootName('.7z'), isNull);
    expect(archiveRootName('document.pdf'), isNull);
    expect(isExtractableArchiveName('document.pdf'), isFalse);
    expect(isExtractableArchiveName('photo.png'), isFalse);
  });
}
