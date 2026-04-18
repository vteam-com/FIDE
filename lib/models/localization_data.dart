import 'package:fide/constants.dart';

/// A single key-value translation entry parsed from an ARB file, optionally carrying `@`-prefixed metadata.
class ArbEntry {
  final String key;
  final String value;
  final Map<String, dynamic>? metadata;

  ArbEntry({required this.key, required this.value, this.metadata});

  factory ArbEntry.fromJson(
    String key,
    dynamic value,
    Map<String, dynamic>? metadata,
  ) {
    return ArbEntry(key: key, value: value.toString(), metadata: metadata);
  }
}

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
    // Assuming format like app_en.arb, intl_en.arb, etc.
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

/// A cross-language comparison record for one ARB key, capturing values present or missing per locale.
class ArbComparison {
  final String key;
  final String? englishValue;
  final Map<String, String?> otherValues;
  final bool isMissingInEnglish;
  final List<String> missingInLanguages;

  ArbComparison({
    required this.key,
    this.englishValue,
    required this.otherValues,
    this.isMissingInEnglish = false,
    this.missingInLanguages = const [],
  });
}
