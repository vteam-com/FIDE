part of 'app_icon_fixer.dart';

/// Why an [AppIconFixer] could not write a platform's icons.
class AppIconFixException implements Exception {
  /// Creates an exception explained by [message].
  const AppIconFixException(this.message);

  /// What prevented the fix, for the user.
  final String message;

  @override
  String toString() => message;
}
