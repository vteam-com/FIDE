import 'package:fide/models/locale_number.dart';

/// What rewriting a project's hardcoded strings did, such as localizing
/// them or making them constants: how many strings were rewritten, in
/// which files, and why the others were left.
class StringRewrite {
  /// Creates the outcome of [action], such as `Localized`.
  const StringRewrite({
    required this.action,
    required this.rewritten,
    required this.changedFiles,
    required this.skipped,
  });

  /// What was done to the strings, in the past tense.
  final String action;

  /// Absolute paths of the Dart files rewritten.
  final List<String> changedFiles;

  /// Strings rewritten.
  final int rewritten;

  /// Strings left as they were, counted by reason.
  final Map<String, int> skipped;

  /// One line for the user, such as "Localized 37 strings in 9 files;
  /// left 12: 12 without a BuildContext".
  String get summary {
    final done = rewritten == 0
        ? 'No string changed'
        : '$action ${rewritten.localized} strings in '
              '${changedFiles.length.localized} files';
    if (skipped.isEmpty) return done;
    final left = skipped.values.fold(0, (sum, count) => sum + count);
    final reasons = [
      for (final MapEntry(:key, :value) in skipped.entries)
        '${value.localized} $key',
    ].join(', ');
    return '$done; left ${left.localized}: $reasons';
  }
}
