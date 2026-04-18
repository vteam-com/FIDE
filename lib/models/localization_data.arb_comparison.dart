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
}
