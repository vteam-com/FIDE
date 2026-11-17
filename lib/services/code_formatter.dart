import 'dart:convert';
import 'dart:io';

import 'package:fide/services/file_type_utils.dart';
import 'package:fide/services/flutter_sdk.dart';
import 'package:fide/services/process_runner.dart';
import 'package:path/path.dart' as p;

/// Formats source text: Dart with `dart format`, JSON and ARB by
/// re-encoding with indentation.
///
/// Works on the editor's text rather than the file on disk, so unsaved
/// edits are formatted along with everything else. Rewrites of many files
/// use [formatFiles] or [formatAllOrKeep], which run `dart format` once
/// for all of them rather than once per file.
class CodeFormatter {
  /// Indentation used for JSON and ARB files.
  static const String jsonIndent = '  ';

  /// The file types [format] handles, for messages.
  static const String supportedDescription = 'Dart, JSON, and ARB';

  /// Name start of the hidden copy [formatAllOrKeep] formats beside a file,
  /// where `dart format` finds the same language version and settings.
  static const String _copyPrefix = '.fide_format_';

  /// Extensions formatted as JSON.
  static const Set<String> _jsonExtensions = {'json', 'arb'};

  final ProcessRunner _runner;

  /// Resolves the Dart tool to launch, such as [FlutterSdk.bundledDart].
  final DartCommand _dart;

  /// Creates a formatter that runs `dart format` with the tool [_dart]
  /// resolves, through [_runner].
  const CodeFormatter(this._runner, [this._dart = FlutterSdk.dartOnPath]);

  /// [json] as the content of a JSON file, indented like [format], with a
  /// final line break.
  static String encodeJson(Object? json) =>
      '${const JsonEncoder.withIndent(jsonIndent).convert(json)}\n';

  /// Whether [filePath] is a Dart, JSON or ARB file.
  static bool canFormat(String filePath) =>
      FileTypeUtils.isDartFile(filePath) || _isJson(filePath);

  /// Whether [filePath] is formatted as JSON.
  static bool _isJson(String filePath) =>
      _jsonExtensions.contains(FileTypeUtils.extensionOf(filePath));

  /// Returns [content] formatted as the kind of file [filePath] names;
  /// throws with the tool's message when it can't be formatted.
  ///
  /// Dart is piped through `dart format` with [filePath] as the stdin name,
  /// so the project's language version still applies.
  Future<String> format(String filePath, String content) async {
    if (_isJson(filePath)) {
      return JsonEncoder.withIndent(jsonIndent).convert(jsonDecode(content));
    }
    final result = await _runner.runWithInput(await _dart(), [
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

  /// Formats the Dart, JSON and ARB files at [paths] in place, every Dart
  /// file with one `dart format` run; a file that can't be formatted keeps
  /// its content, as with [formatOrKeep].
  Future<void> formatFiles(Iterable<String> paths) async {
    final dartPaths = <String>[];
    for (final path in paths) {
      if (FileTypeUtils.isDartFile(path)) {
        dartPaths.add(path);
      } else if (_isJson(path)) {
        final file = File(path);
        try {
          await file.writeAsString(
            await formatOrKeep(path, await file.readAsString()),
          );
        } on FileSystemException {
          // Kept as it is, like a file that can't be formatted
        }
      }
    }
    if (dartPaths.isEmpty) return;
    try {
      // Formats the files it can parse even when it fails on others
      await _runner.run(await _dart(), ['format', ...dartPaths]);
    } on Exception {
      // No formatter to run: the files keep their content
    }
  }

  /// [contents], new text keyed by file path, each formatted like
  /// [formatOrKeep], all the Dart ones with a single `dart format` run:
  /// each is written to a hidden copy beside its file, formatted there and
  /// read back, so nothing is written to the files themselves.
  Future<Map<String, String>> formatAllOrKeep(
    Map<String, String> contents,
  ) async {
    final formatted = <String, String>{};
    final copies = <String, File>{};
    for (final MapEntry(key: path, value: content) in contents.entries) {
      if (FileTypeUtils.isDartFile(path) &&
          Directory(p.dirname(path)).existsSync()) {
        copies[path] = File(
          p.join(p.dirname(path), '$_copyPrefix${p.basename(path)}'),
        );
      } else {
        formatted[path] = await formatOrKeep(path, content);
      }
    }
    try {
      for (final MapEntry(key: path, value: copy) in copies.entries) {
        await copy.writeAsString(contents[path]!);
      }
      await formatFiles([for (final copy in copies.values) copy.path]);
      for (final MapEntry(key: path, value: copy) in copies.entries) {
        formatted[path] = await copy.readAsString();
      }
    } on FileSystemException {
      // Unformatted rather than lost
    } finally {
      for (final copy in copies.values) {
        if (copy.existsSync()) await copy.delete();
      }
    }
    return {
      for (final MapEntry(key: path, value: content) in contents.entries)
        path: formatted[path] ?? content,
    };
  }
}
