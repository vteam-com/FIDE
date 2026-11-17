import 'dart:io';

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

  @override
  Future<void> formatFiles(Iterable<String> paths) async {
    for (final path in paths) {
      final file = File(path);
      await file.writeAsString(await format(path, await file.readAsString()));
    }
  }

  @override
  Future<Map<String, String>> formatAllOrKeep(
    Map<String, String> contents,
  ) async => {
    for (final MapEntry(key: path, value: content) in contents.entries)
      path: await format(path, content),
  };
}
