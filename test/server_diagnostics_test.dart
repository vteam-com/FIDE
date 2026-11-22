import 'package:fide/services/dart_language_server.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const project = '/project';
  const path = '$project/lib/main.dart';

  /// The `publishDiagnostics` params of [file] with [diagnostics].
  Map<String, dynamic> published(
    String file,
    List<Map<String, dynamic>> diagnostics,
  ) => {'uri': Uri.file(file).toString(), 'diagnostics': diagnostics};

  const error = {
    'severity': 1,
    'message': 'Undefined name',
    'range': {
      'start': {'line': 0, 'character': 2},
      'end': {'line': 0, 'character': 5},
    },
  };

  late ServerDiagnostics diagnostics;
  late int changes;

  setUp(() {
    changes = 0;
    diagnostics = ServerDiagnostics(project)..addListener(() => changes++);
  });

  test('records each file by its path', () {
    diagnostics.publish(published(path, [error]));

    expect(diagnostics.of(path).single.message, 'Undefined name');
    expect(diagnostics.of(path).single.range['start'], {
      'line': 0,
      'character': 2,
    });
    expect(diagnostics.of('$project/lib/other.dart'), isEmpty);
    expect(changes, 1);
  });

  test('replaces the diagnostics of a file, and forgets them when none', () {
    diagnostics
      ..publish(published(path, [error, error]))
      ..publish(published(path, [error]));
    expect(diagnostics.of(path), hasLength(1));

    diagnostics.publish(published(path, []));
    expect(diagnostics.of(path), isEmpty);
    expect(changes, 3);
  });

  test('tells nothing when a file without diagnostics still has none', () {
    diagnostics.publish(published(path, []));

    expect(changes, 0);
  });

  test('reads a diagnostic without severity as an error', () {
    diagnostics.publish(
      published(path, [
        {'message': 'Oops', 'range': error['range']},
      ]),
    );

    expect(diagnostics.of(path).single.severity, 1);
  });

  test('skips what is not a file diagnostic', () {
    diagnostics
      ..publish({'uri': 'untitled:1', 'diagnostics': []})
      ..publish(
        published(path, [
          {'message': 'No range'},
        ]),
      );

    expect(diagnostics.of(path), isEmpty);
    expect(changes, 0);
  });

  test('analyzes the Dart files of the project only', () {
    expect(diagnostics.analyzes(path), isTrue);
    expect(diagnostics.analyzes('$project/pubspec.yaml'), isFalse);
    expect(diagnostics.analyzes('/elsewhere/lib/main.dart'), isFalse);
  });
}
