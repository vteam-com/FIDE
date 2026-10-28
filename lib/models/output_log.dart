/// Output and error text captured from commands a panel runs, for display
/// in its output section.
class OutputLog {
  final StringBuffer _errors = StringBuffer();
  final StringBuffer _output = StringBuffer();

  /// Captured error text.
  String get errors => _errors.toString();

  /// Whether any error text has been captured.
  bool get hasErrors => _errors.isNotEmpty;

  /// Whether any output text has been captured.
  bool get hasOutput => _output.isNotEmpty;

  /// Captured output text.
  String get output => _output.toString();

  /// Appends [line] and a newline to the errors.
  void addError(String line) => _errors.writeln(line);

  /// Appends [line] and a newline to the output.
  void addOutput(String line) => _output.writeln(line);

  /// Discards all captured text.
  void clear() {
    _errors.clear();
    _output.clear();
  }

  /// Discards captured errors, e.g. before an automatic retry.
  void clearErrors() => _errors.clear();

  /// Appends [text] to the errors as-is.
  void writeError(String text) => _errors.write(text);

  /// Appends [text] to the output as-is.
  void writeOutput(String text) => _output.write(text);
}
