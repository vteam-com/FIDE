import 'package:fcheck/fcheck.dart' as fcheck;
import 'package:fide/models/text_case.dart';
import 'package:fide/models/unique_name.dart';

/// A hardcoded string as an ARB message: its text with a `{placeholder}`
/// for each interpolation, and the expressions the lookup passes for them.
class ArbMessage {
  /// The message for the string at [site].
  factory ArbMessage.fromSite(fcheck.HardcodedStringSite site) {
    final placeholders = <String>[];
    final message = StringBuffer(site.textParts.first);
    for (final (index, expression) in site.interpolations.indexed) {
      final name = uniqueName(
        _placeholderBase(expression),
        placeholders.contains,
      );
      placeholders.add(name);
      message.write('{$name}${site.textParts[index + 1]}');
    }
    return ArbMessage._(
      text: message.toString(),
      placeholders: placeholders,
      arguments: site.interpolations,
      isExpressible: !site.textParts.any(
        (part) => part.contains('{') || part.contains('}'),
      ),
    );
  }

  const ArbMessage._({
    required this.text,
    required this.placeholders,
    required this.arguments,
    required this.isExpressible,
  });

  /// Key of the description in a message's `@key` metadata.
  static const String descriptionKey = 'description';

  /// The [descriptionKey] of a message's `@key` [metadata], saying where
  /// it appears or how to translate it; null when it has none.
  static String? descriptionOf(Object? metadata) {
    final description = metadata is Map ? metadata[descriptionKey] : null;
    return description is String && description.isNotEmpty ? description : null;
  }

  /// Key of the placeholders in a message's `@key` metadata.
  static const String placeholdersKey = 'placeholders';

  /// Key of a placeholder's type in [placeholdersKey].
  static const String placeholderTypeKey = 'type';

  /// A `{placeholder}` in a message.
  static final RegExp placeholderPattern = RegExp(r'\{\w+\}');

  /// Type of the placeholders [metadata] declares, which takes any value.
  static const String _placeholderType = 'Object';

  /// Most words of the text used to name a key.
  static const int _maxKeyWords = 5;

  /// Placeholder name when an expression has no usable identifier.
  static const String _fallbackPlaceholder = 'value';

  /// Key base when the text has no words.
  static const String _fallbackKey = 'text';

  /// Source of the expression passed for each placeholder, in order.
  final List<String> arguments;

  /// Whether the text can be written as an ARB message; braces would be
  /// read as placeholders.
  final bool isExpressible;

  /// Placeholder names, in order.
  final List<String> placeholders;

  /// The message, such as `Error: {error}`.
  final String text;

  /// A camelCase key from the first words of the text, such as
  /// `unknownPerformer`; never starts with a digit.
  String get keyBase {
    final words = RegExp(r'[A-Za-z0-9]+')
        .allMatches(text.replaceAll(placeholderPattern, ' '))
        .map((match) => match[0]!.toLowerCase())
        .take(_maxKeyWords)
        .toList();
    if (words.isEmpty) return _fallbackKey;
    final key =
        words.first + words.skip(1).map((word) => word.capitalized).join();
    return withoutLeadingDigit(key, prefix: _fallbackKey);
  }

  /// The `@key` metadata declaring [placeholders]; empty without any.
  Map<String, Object> get metadata => {
    if (placeholders.isNotEmpty)
      placeholdersKey: {
        for (final name in placeholders)
          name: {placeholderTypeKey: _placeholderType},
      },
  };

  /// The lookup of [key] on the localizations instance [localizations],
  /// passing [arguments] when the message has placeholders.
  String lookup(String localizations, String key) => arguments.isEmpty
      ? '$localizations.$key'
      : '$localizations.$key(${arguments.join(', ')})';

  /// A placeholder name from the last identifier of [expression], such as
  /// `name` for `concert.name`, ignoring a trailing `toString()`.
  static String _placeholderBase(String expression) {
    final identifiers = RegExp(r'[A-Za-z_]\w*')
        .allMatches(expression.replaceAll(RegExp(r'\.toString\(\)$'), ''))
        .map((match) => match[0]!.replaceAll('_', ''))
        .where((name) => name.isNotEmpty)
        .toList();
    if (identifiers.isEmpty) return _fallbackPlaceholder;
    return identifiers.last.uncapitalized;
  }
}
