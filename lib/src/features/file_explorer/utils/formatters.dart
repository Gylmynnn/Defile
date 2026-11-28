String formatBytes(BigInt bytes) =>
    _formatBytes(bytes, const ['KB', 'MB', 'GB', 'TB', 'PB']);

String formatBytesIec(BigInt bytes) =>
    _formatBytes(bytes, const ['KiB', 'MiB', 'GiB', 'TiB', 'PiB']);

/// Capacity-style size: always one decimal (trimmed when `.0`), so a disk
/// reads like `342.8 GB of 512 GB` instead of `343 GB`.
String formatStorageSize(BigInt bytes) {
  final int value = bytes.toInt();
  if (value < 1024) return '$value B';

  double size = value / 1024;
  const List<String> units = ['KB', 'MB', 'GB', 'TB', 'PB'];
  int unitIndex = 0;

  while (size >= 1024 && unitIndex < units.length - 1) {
    size /= 1024;
    unitIndex++;
  }

  String formatted = size.toStringAsFixed(1);
  if (formatted.endsWith('.0')) {
    formatted = formatted.substring(0, formatted.length - 2);
  }
  return '$formatted ${units[unitIndex]}';
}

String _formatBytes(BigInt bytes, List<String> units) {
  final int value = bytes.toInt();
  if (value < 1024) return '$value B';

  double size = value / 1024;
  int unitIndex = 0;

  while (size >= 1024 && unitIndex < units.length - 1) {
    size /= 1024;
    unitIndex++;
  }

  final String formatted = size >= 100
      ? size.toStringAsFixed(0)
      : size.toStringAsFixed(1);

  return '$formatted ${units[unitIndex]}';
}

String formatThousands(BigInt value) {
  final String digits = value.toString();
  final StringBuffer buffer = StringBuffer();

  for (int index = 0; index < digits.length; index++) {
    if (index > 0 && (digits.length - index) % 3 == 0) {
      buffer.write(',');
    }
    buffer.write(digits[index]);
  }

  return buffer.toString();
}

String formatDateNumeric(int unixSeconds) {
  if (unixSeconds <= 0) return '—';

  final DateTime date = DateTime.fromMillisecondsSinceEpoch(unixSeconds * 1000);
  final String day = date.day.toString().padLeft(2, '0');
  final String month = date.month.toString().padLeft(2, '0');

  return '$month/$day/${date.year}';
}

const List<String> _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

String formatDate(int unixSeconds) {
  if (unixSeconds <= 0) return '—';

  final DateTime date = DateTime.fromMillisecondsSinceEpoch(unixSeconds * 1000);
  final String day = date.day.toString().padLeft(2, '0');
  final String hour = date.hour.toString().padLeft(2, '0');
  final String minute = date.minute.toString().padLeft(2, '0');

  return '$day ${_months[date.month - 1]} ${date.year}  $hour:$minute';
}
