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

class ArbFile {
  final String path;
  final String languageCode;
  final Map<String, ArbEntry> entries;

  ArbFile({
    required this.path,
    required this.languageCode,
    required this.entries,
  });

  static String extractLanguageCode(String filename) {
    // Assuming format like app_en.arb, intl_en.arb, etc.
    final parts = filename.split('_');
    if (parts.length >= 2) {
      final lastPart = parts.last;
      if (lastPart.endsWith('.arb')) {
        return lastPart.replaceAll('.arb', '');
      }
    }
    return 'unknown';
  }
}

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
