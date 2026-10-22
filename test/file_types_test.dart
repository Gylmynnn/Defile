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
}
