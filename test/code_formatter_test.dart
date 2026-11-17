import 'dart:io';

import 'package:fide/services/code_formatter.dart';
import 'package:fide/services/process_runner.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// Runs the real processes, counting the ones started.
class _CountingRunner extends ProcessRunner {
  /// The argument lists of every process started.
  final List<List<String>> started = [];

  @override
  Future<ProcessResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    bool runInShell = false,
  }) {
    started.add(arguments);
    return super.run(
      executable,
      arguments,
      workingDirectory: workingDirectory,
      runInShell: runInShell,
    );
  }

  @override
  Future<ProcessResult> runWithInput(
    String executable,
    List<String> arguments,
    String input, {
    String? workingDirectory,
  }) {
    started.add(arguments);
    return super.runWithInput(
      executable,
      arguments,
      input,
      workingDirectory: workingDirectory,
    );
  }
}

void main() {
  late Directory project;
  late _CountingRunner runner;
  late CodeFormatter formatter;

  const unformatted = 'void main(){print(1);}';
  const formatted = 'void main() {\n  print(1);\n}\n';
  const broken = 'void main( {';

  setUp(() {
    project = Directory.systemTemp.createTempSync('fide_format_');
    runner = _CountingRunner();
    formatter = CodeFormatter(runner);
  });
  tearDown(() => project.deleteSync(recursive: true));

  String path(String name) => p.join(project.path, 'lib', name);

  test('formats many files in place with one dart format run', () async {
    final paths = [path('a.dart'), path('b.dart'), path('c.dart')];
    for (final file in paths) {
      File(file)
        ..createSync(recursive: true)
        ..writeAsStringSync(unformatted);
    }
    File(paths.last).writeAsStringSync(broken);

    await formatter.formatFiles(paths);

    expect(runner.started, hasLength(1));
    expect(File(paths[0]).readAsStringSync(), formatted);
    expect(File(paths[1]).readAsStringSync(), formatted);
    // A file that can't be formatted keeps its content
    expect(File(paths[2]).readAsStringSync(), broken);
  });

  test('formats many texts with one run, leaving no file behind', () async {
    Directory(p.join(project.path, 'lib')).createSync();
    final contents = {
      path('a.dart'): unformatted,
      path('b.dart'): broken,
      path('c.dart'): unformatted,
    };

    final result = await formatter.formatAllOrKeep(contents);

    expect(runner.started, hasLength(1));
    expect(result.keys, contents.keys);
    expect(result[path('a.dart')], formatted);
    expect(result[path('b.dart')], broken);
    expect(result[path('c.dart')], formatted);
    // Nothing written to the files, and the copies are gone
    expect(Directory(p.join(project.path, 'lib')).listSync(), isEmpty);
  });

  test('formats JSON in process, and Dart without a folder alone', () async {
    final result = await formatter.formatAllOrKeep({
      path('app_en.arb'): '{"a":1}',
      p.join(project.path, 'missing', 'x.dart'): unformatted,
    });

    expect(result.values, ['{\n  "a": 1\n}', formatted]);
    expect(runner.started, hasLength(1));
  });
}
