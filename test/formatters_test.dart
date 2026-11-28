import 'package:defile/src/features/file_explorer/utils/formatters.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('formats byte sizes in decimal and binary units', () {
    expect(formatBytes(BigInt.from(512)), '512 B');
    expect(formatBytes(BigInt.from(1024)), '1.0 KB');
    expect(formatBytes(BigInt.from(1024 * 1024)), '1.0 MB');
    expect(formatBytesIec(BigInt.from(1024)), '1.0 KiB');
    expect(formatBytesIec(BigInt.from(1024 * 1024)), '1.0 MiB');
  });

  test('formats thousands separators', () {
    expect(formatThousands(BigInt.from(1234567)), '1,234,567');
  });

  test('formats storage capacity with a trimmed decimal', () {
    expect(formatStorageSize(BigInt.from(512)), '512 B');
    expect(formatStorageSize(BigInt.from(1536)), '1.5 KB');
    expect(formatStorageSize(BigInt.from(2048)), '2 KB');
    expect(
      formatStorageSize(BigInt.from(512) * BigInt.from(1024 * 1024 * 1024)),
      '512 GB',
    );
  });
}
