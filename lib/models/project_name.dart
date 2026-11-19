import 'package:fide/models/unique_name.dart';

/// Turns what the user typed into a valid Dart package name for a new
/// project.
class ProjectName {
  /// Name used when nothing valid is left after normalizing.
  static const String fallback = 'flutter_app';

  /// Put before a name starting with a digit.
  static const String _digitPrefix = 'app_';

  /// Put after a name that is a Dart keyword.
  static const String _keywordSuffix = '_app';

  /// Returns a lowercase snake_case package name for [input], or null when
  /// [input] is empty.
  ///
  /// `MyApp` and `my app` both become `my_app`; a leading digit gets an
  /// `app_` prefix and a Dart keyword an `_app` suffix.
  static String? normalize(String input) {
    if (input.isEmpty) return null;

    var name = input
        // camelCase and PascalCase word boundaries become underscores
        .replaceAll(RegExp(r'(?<=[a-z0-9])(?=[A-Z])'), '_')
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9_]'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');

    name = withoutLeadingDigit(name, prefix: _digitPrefix);
    if (name.isEmpty) {
      name = fallback;
    }
    return safeIdentifier(name, suffix: _keywordSuffix);
  }
}
