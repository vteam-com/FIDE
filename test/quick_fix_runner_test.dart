import 'dart:io';

import 'package:fcheck/fcheck.dart' as fcheck;

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

/// An fCheck run counting its analyses.
class _CountingReview extends CodeReview {
  int analyses = 0;

  @override
  Future<fcheck.ProjectMetrics> analyze(
    String projectPath, {
    bool nearDuplicates = false,
  }) {
    analyses++;
    return super.analyze(projectPath, nearDuplicates: nearDuplicates);
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

  test('reuses the latest analysis of the current files', () async {
    final handler = _RecordingHandler('Sort every file?');
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final review = _CountingReview();
    final metrics = await const CodeReview().analyze(project.path);
    fcheck.ProjectMetrics? latest;
    final runner = QuickFixRunner(
      review: review,
      strings: container.read(stringFixerProvider),
      handlers: {QuickFix.sortMembers: handler},
      latest: (_) async => latest,
    );

    latest = metrics;
    await runner.run(project.path, QuickFix.sortMembers);
    expect(handler.requests.last.metrics, same(metrics));
    expect(review.analyses, 0);

    // None for the current files: a fresh analysis
    latest = null;
    await runner.run(project.path, QuickFix.sortMembers);
    expect(handler.requests.last.metrics, isNot(same(metrics)));
    expect(review.analyses, 1);
  });
}
