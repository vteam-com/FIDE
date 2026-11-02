import 'dart:convert';

import 'package:fide/services/file_type_utils.dart';
import 'package:fide/services/process_runner.dart';

/// Formats source text: Dart with `dart format`, JSON and ARB by
/// re-encoding with indentation.
///
/// Works on the editor's text rather than the file on disk, so unsaved
/// edits are formatted along with everything else.
class CodeFormatter {
  /// Indentation used for JSON and ARB files.
  static const String jsonIndent = '  ';

  /// The file types [format] handles, for messages.
  static const String supportedDescription = 'Dart, JSON, and ARB';

  /// Extensions formatted as JSON.
  static const Set<String> _jsonExtensions = {'json', 'arb'};

  final ProcessRunner _runner;

  /// Creates a formatter that runs `dart format` through [_runner].
  const CodeFormatter(this._runner);

  /// Whether [filePath] is a Dart, JSON or ARB file.
  static bool canFormat(String filePath) {
    final extension = FileTypeUtils.extensionOf(filePath);
    return extension == 'dart' || _jsonExtensions.contains(extension);
  }

  /// Returns [content] formatted as the kind of file [filePath] names;
  /// throws with the tool's message when it can't be formatted.
  ///
  /// Dart is piped through `dart format` with [filePath] as the stdin name,
  /// so the project's language version still applies.
  Future<String> format(String filePath, String content) async {
    if (_jsonExtensions.contains(FileTypeUtils.extensionOf(filePath))) {
      return JsonEncoder.withIndent(jsonIndent).convert(jsonDecode(content));
    }
    final result = await _runner.runWithInput('dart', [
      'format',
      '--stdin-name=$filePath',
    ], content);
    if (result.exitCode != 0) {
      throw Exception(result.stderr.toString().trim());
    }
    return result.stdout as String;
  }

  /// [content] formatted like [format], or unchanged when it cannot be,
  /// so generated edits are still saved.
  Future<String> formatOrKeep(String filePath, String content) async {
    try {
      return await format(filePath, content);
    } on Exception {
      return content;
    }
  }
}
