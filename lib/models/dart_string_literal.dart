/// Writes and reads single-quoted Dart string literals, for code FIDE
/// generates.
class DartStringLiteral {
  const DartStringLiteral._();

  /// An escape sequence in a literal's body: a backslash and the character
  /// after it.
  static final RegExp _escape = RegExp(r'\\(.)');

  /// Characters an escape sequence stands for, by the letter after the
  /// backslash; any other escaped character stands for itself.
  static const Map<String, String> _escapedControls = {'n': '\n', 'r': '\r'};

  /// [value] as a single-quoted Dart string literal, quotes included,
  /// with `\`, `'`, `$` and line breaks escaped.
  static String quote(String value) {
    final body = value
        .replaceAll(r'\', r'\\')
        .replaceAll("'", r"\'")
        .replaceAll(r'$', r'\$')
        .replaceAll('\n', r'\n')
        .replaceAll('\r', r'\r');
    return "'$body'";
  }

  /// The value of [body], the text between the quotes of a literal
  /// [quote] wrote.
  static String valueOf(String body) => body.replaceAllMapped(
    _escape,
    (match) => _escapedControls[match[1]] ?? match[1]!,
  );
}
