part of 'localization_data.dart';

/// A cross-language comparison record for one ARB key, capturing values present or missing per locale.
class ArbComparison {
  final String key;
  final String? englishValue;

  /// The value of each other locale, null where the key is missing.
  final Map<String, String?> otherValues;

  /// The template's description of the key, saying where it appears or how
  /// to translate it, such as "DO NOT TRANSLATE"; null when it has none.
  final String? description;

  ArbComparison({
    required this.key,
    this.englishValue,
    required this.otherValues,
    this.description,
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
