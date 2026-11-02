part of 'localization_data.dart';

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

  /// Whether the key, the English value or any translation contains
  /// [query], ignoring case; an empty query matches everything.
  bool matches(String query) {
    final lowerQuery = query.toLowerCase();
    return [
      key,
      englishValue,
      ...otherValues.values,
    ].any((text) => text != null && text.toLowerCase().contains(lowerQuery));
  }
}
