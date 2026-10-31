import 'package:fcheck/fcheck.dart' as fcheck;
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
        .allMatches(text.replaceAll(RegExp(r'\{\w+\}'), ' '))
        .map((match) => match[0]!.toLowerCase())
        .take(_maxKeyWords)
        .toList();
    if (words.isEmpty) return _fallbackKey;
    final key = words.first + words.skip(1).map(_capitalized).join();
    return key.startsWith(RegExp('[0-9]'))
        ? '$_fallbackKey${_capitalized(key)}'
        : key;
  }

  /// The `@key` metadata declaring [placeholders]; empty without any.
  Map<String, Object> get metadata => {
    if (placeholders.isNotEmpty)
      'placeholders': {
        for (final name in placeholders) name: {'type': 'Object'},
      },
  };

  /// The lookup of [key] on the localizations instance [localizations],
  /// passing [arguments] when the message has placeholders.
  String lookup(String localizations, String key) => arguments.isEmpty
      ? '$localizations.$key'
      : '$localizations.$key(${arguments.join(', ')})';

  /// [word] with its first letter in uppercase.
  static String _capitalized(String word) =>
      word.isEmpty ? word : word[0].toUpperCase() + word.substring(1);

  /// A placeholder name from the last identifier of [expression], such as
  /// `name` for `concert.name`, ignoring a trailing `toString()`.
  static String _placeholderBase(String expression) {
    final identifiers = RegExp(r'[A-Za-z_]\w*')
        .allMatches(expression.replaceAll(RegExp(r'\.toString\(\)$'), ''))
        .map((match) => match[0]!.replaceAll('_', ''))
        .where((name) => name.isNotEmpty)
        .toList();
    if (identifiers.isEmpty) return _fallbackPlaceholder;
    final name = identifiers.last;
    return name[0].toLowerCase() + name.substring(1);
  }
}
