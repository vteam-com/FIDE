/// Turns what the user typed into a valid Dart package name for a new
/// project.
class ProjectName {
  /// Name used when nothing valid is left after normalizing.
  static const String fallback = 'flutter_app';

  /// Dart reserved words, which can't be package names on their own.
  static const Set<String> _reservedWords = {
    'abstract',
    'as',
    'assert',
    'async',
    'await',
    'break',
    'case',
    'catch',
    'class',
    'const',
    'continue',
    'default',
    'deferred',
    'do',
    'dynamic',
    'else',
    'enum',
    'export',
    'extends',
    'extension',
    'external',
    'factory',
    'false',
    'final',
    'finally',
    'for',
    'function',
    'get',
    'hide',
    'if',
    'implements',
    'import',
    'in',
    'interface',
    'is',
    'late',
    'library',
    'mixin',
    'new',
    'null',
    'on',
    'operator',
    'part',
    'required',
    'rethrow',
    'return',
    'set',
    'show',
    'static',
    'super',
    'switch',
    'sync',
    'this',
    'throw',
    'true',
    'try',
    'typedef',
    'var',
    'void',
    'while',
    'with',
    'yield',
  };

  /// Returns a lowercase snake_case package name for [input], or null when
  /// [input] is empty.
  ///
  /// `MyApp` and `my app` both become `my_app`; a leading digit gets an
  /// `app_` prefix and a reserved word an `_app` suffix.
  static String? normalize(String input) {
    if (input.isEmpty) return null;

    var name = input
        // camelCase and PascalCase word boundaries become underscores
        .replaceAll(RegExp(r'(?<=[a-z0-9])(?=[A-Z])'), '_')
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9_]'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');

    if (name.startsWith(RegExp(r'[0-9]'))) {
      name = 'app_$name';
    }
    if (name.isEmpty) {
      name = fallback;
    }
    if (_reservedWords.contains(name)) {
      name = '${name}_app';
    }
    return name;
  }
}
