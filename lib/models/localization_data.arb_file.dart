part of 'localization_data.dart';

/// Represents a parsed ARB localization file, identified by its language code and keyed entries.
class ArbFile {
  final String path;
  final String languageCode;
  final Map<String, ArbEntry> entries;

  ArbFile({
    required this.path,
    required this.languageCode,
    required this.entries,
  });

  /// Handles `ArbFile.extractLanguageCode`.
  static String extractLanguageCode(String filename) {
    final parts = filename.split('_');
    if (parts.length >= AppMetric.minDirPathDepth) {
      final lastPart = parts.last;
      if (lastPart.endsWith('.arb')) {
        return lastPart.replaceAll('.arb', '');
      }
    }
    return 'unknown';
  }
}
