/// Changes the case of a word's first letter, as identifiers and labels
/// built from words need.
extension TextCase on String {
  /// This text with its first letter in uppercase.
  String get capitalized =>
      isEmpty ? this : '${this[0].toUpperCase()}${substring(1)}';

  /// This text with its first letter in lowercase.
  String get uncapitalized =>
      isEmpty ? this : '${this[0].toLowerCase()}${substring(1)}';
}
