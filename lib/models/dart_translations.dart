/// The translations of one locale written as a Dart localizations class,
/// such as `String get cancel => 'Cancel';`, read back as ARB messages by
/// `DartTranslationsParser`.
class DartTranslations {
  /// Creates the translations read from one class.
  const DartTranslations({
    required this.messages,
    required this.placeholders,
    required this.unsupported,
  });

  /// ARB message of each key, such as `Delete {name}?`.
  final Map<String, String> messages;

  /// Placeholder name → type of each key with parameters.
  final Map<String, Map<String, String>> placeholders;

  /// Keys whose body is not a plain string with parameter interpolations,
  /// such as plural logic, which ARB cannot hold as-is.
  final List<String> unsupported;
}
