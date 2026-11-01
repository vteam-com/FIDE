import 'package:fide/constants/constants.dart';

/// Formats a byte count for people to read.
extension ByteSize on int {
  /// Units of [readableSize], each [AppMetric.fileSizeDivisor] times the
  /// previous one.
  static const List<String> _units = ['B', 'KB', 'MB', 'GB'];

  /// This many bytes in the largest unit that keeps the number above one,
  /// with one decimal: `0 B`, `512.0 B`, `2.0 KB`, `1.5 MB`.
  String get readableSize {
    if (this == 0) return '0 B';
    var unit = 0;
    var size = toDouble();
    while (size > AppMetric.fileSizeDivisor && unit < _units.length - 1) {
      size /= AppMetric.fileSizeDivisor;
      unit++;
    }
    return '${size.toStringAsFixed(1)} ${_units[unit]}';
  }
}
