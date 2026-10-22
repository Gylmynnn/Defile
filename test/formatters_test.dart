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
}
