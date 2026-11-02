import 'dart:io';

import 'package:fide/models/quick_fix.dart';
import 'package:fide/models/string_review.dart';
import 'package:fide/providers/app_providers.dart';
import 'package:fide/services/code_review.dart';
import 'package:fide/services/quick_fix_handler.dart';
import 'package:fide/services/quick_fix_runner.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// A handler asking to confirm [message] and recording its requests.
class _RecordingHandler implements QuickFixHandler {
  _RecordingHandler(this.message);

  final String message;
  final List<QuickFixRequest> requests = [];

  @override
  Future<QuickFixOutcome?> run(QuickFixRequest request) async {
    requests.add(request);
    if (!await request.confirm(message)) return null;
    return (summary: 'Done', changedFiles: const <String>[]);
  }
}

void main() {
  late Directory project;

  setUp(() {
    project = Directory.systemTemp.createTempSync('fide_quick_fix_');
    File('${project.path}/pubspec.yaml').writeAsStringSync('name: sample\n');
    File('${project.path}/lib/a.dart')
      ..createSync(recursive: true)
      ..writeAsStringSync('/// A.\nclass A {}\n');
  });
  tearDown(() => project.deleteSync(recursive: true));

  test('every quick fix has a handler', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(
      container.read(quickFixHandlersProvider).keys,
      unorderedEquals(QuickFix.values),
    );
  });

  test('the string fixes are the quick fixes rewriting strings', () {
    expect(StringFix.of(QuickFix.passLookup), StringFix.passLookup);
    expect(StringFix.of(QuickFix.sortMembers), isNull);
    for (final fix in StringFix.values) {
      expect(StringFix.of(fix.quickFix), fix);
    }
  });

  test('runs a fix through its handler with a fresh analysis', () async {
    final handler = _RecordingHandler('Sort every file?');
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final runner = QuickFixRunner(
      review: const CodeReview(),
      strings: container.read(stringFixerProvider),
      handlers: {QuickFix.sortMembers: handler},
    );
    final asked = <(QuickFix, String)>[];

    final outcome = await runner.run(
      project.path,
      QuickFix.sortMembers,
      confirm: (fix, message) async {
        asked.add((fix, message));
        return false;
      },
    );

    expect(outcome, isNull);
    expect(asked, [(QuickFix.sortMembers, 'Sort every file?')]);
    expect(handler.requests.single.projectPath, project.path);
    expect(handler.requests.single.metrics.analysisRootPath, isNotEmpty);
    // Unasked, the fix runs
    expect(
      (await runner.run(project.path, QuickFix.sortMembers))?.summary,
      'Done',
    );
    await expectLater(
      runner.run(project.path, QuickFix.migrateToArb),
      throwsStateError,
    );
  });
}
