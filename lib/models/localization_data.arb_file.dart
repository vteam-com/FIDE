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

  /// [languageCode] of a file whose name has no `_<locale>` suffix.
  static const String unknownLanguageCode = 'unknown';
}
