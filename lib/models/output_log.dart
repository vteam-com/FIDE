import 'dart:collection';

import 'package:fide/constants/core_constants.dart';

part 'output_log.output_lines.dart';

/// Output and error text captured from commands a panel runs, for display
/// in its output section. Each keeps its newest
/// [AppMetric.outputLogMaxLines] lines, and its text is built once per
/// change rather than on every read.
class OutputLog {
  final _OutputLines _errors = _OutputLines();
  final _OutputLines _output = _OutputLines();

  /// Captured error text.
  String get errors => _errors.text;

  /// Whether any error text has been captured.
  bool get hasErrors => _errors.isNotEmpty;

  /// Captured output text.
  String get output => _output.text;

  /// Appends [line] and a newline to the errors.
  void addError(String line) => _errors.add(line);

  /// Appends [line] and a newline to the output.
  void addOutput(String line) => _output.add(line);

  /// Discards all captured text.
  void clear() {
    _errors.clear();
    _output.clear();
  }
}
