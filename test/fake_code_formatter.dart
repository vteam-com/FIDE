import 'package:fide/services/code_formatter.dart';
import 'package:fide/services/process_runner.dart';

/// A [CodeFormatter] running no `dart format`: it only trims trailing
/// blank lines, ending the text with one line break.
class FakeCodeFormatter extends CodeFormatter {
  /// Creates the formatter.
  const FakeCodeFormatter() : super(const ProcessRunner());

  @override
  Future<String> format(String filePath, String content) async =>
      '${content.trimRight()}\n';
}
