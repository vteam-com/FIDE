import 'package:fide/models/status_tone.dart';

/// One problem `dart analyze` reports, such as an unused import on line 3
/// of a file.
class DartDiagnostic {
  /// Creates the diagnostic at 1-based [line] of the file at absolute
  /// [path].
  const DartDiagnostic({
    required this.path,
    required this.line,
    required this.tone,
    required this.code,
    required this.message,
  });

  /// The diagnostic's name, such as `unused_import`.
  final String code;

  /// 1-based line in the file.
  final int line;

  /// What is wrong, as the analyzer words it.
  final String message;

  /// Absolute path of the file.
  final String path;

  /// How serious it is: an error, a warning or an info.
  final StatusTone tone;
}
