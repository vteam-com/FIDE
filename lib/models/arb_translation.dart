/// One ARB key to translate from the template language into another.
class ArbTranslation {
  /// Creates the translation of [key] from [source] into [language].
  const ArbTranslation({
    required this.key,
    required this.source,
    required this.language,
    required this.arbPath,
  });

  /// Absolute path of the target language's ARB file.
  final String arbPath;

  /// The ARB key.
  final String key;

  /// The language to translate into, as the model is told, such as
  /// `French`.
  final String language;

  /// The template language's message.
  final String source;

  /// The `{placeholder}`s of [source], which the translation must keep.
  Set<String> get placeholders => {
    for (final match in RegExp(r'\{\w+\}').allMatches(source)) match[0]!,
  };
}
