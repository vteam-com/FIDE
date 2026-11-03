import 'dart:io';

import 'package:fcheck/fcheck.dart' as fcheck;
import 'package:fide/models/constants_plan.dart';
import 'package:fide/models/hardcoded_string.dart';
import 'package:fide/models/string_review.dart';
import 'package:fide/models/string_rewrite.dart';
import 'package:fide/services/code_formatter.dart';
import 'package:fide/services/code_review.dart';
import 'package:fide/services/flutter_sdk.dart';
import 'package:fide/services/l10n_generator.dart';
import 'package:fide/services/process_runner.dart';
import 'package:fide/services/project_config_reader.dart';
import 'package:fide/services/reference_finder.dart';
import 'package:fide/services/string_constants_extractor.dart';
import 'package:fide/services/string_fixer.dart';
import 'package:fide/services/string_localizer.dart';
import 'package:fide/services/string_lookup_passer.dart';
import 'package:fide/services/string_rewriter.dart';
import 'package:flutter_test/flutter_test.dart';

/// Records the fixes planned, in order, in [planned], and answers [apply]
/// with [rewritten] strings rewritten.
class _RecordingRewriter implements StringRewriter {
  const _RecordingRewriter(this.fix, this.planned, {this.rewritten = 0});

  final StringFix fix;
  final List<StringFix> planned;
  final int rewritten;

  @override
  Future<StringReview> plan(
    String projectPath,
    fcheck.ProjectMetrics metrics,
    StringReview review,
  ) async {
    planned.add(fix);
    return review.copyWith(localizationBlocker: 'planned ${fix.label}');
  }

  @override
  Future<StringRewrite> apply(
    StringReview review,
    List<HardcodedString> selected,
  ) async => StringRewrite(
    action: 'Rewrote',
    rewritten: rewritten,
    changedFiles: const ['/p/lib/a.dart'],
    skipped: const {},
  );
}

void main() {
  late Directory project;
  late fcheck.ProjectMetrics metrics;

  setUp(() async {
    project = Directory.systemTemp.createTempSync('fide_string_fixer_');
    File('${project.path}/pubspec.yaml').writeAsStringSync('name: sample\n');
    File('${project.path}/lib/a.dart')
      ..createSync(recursive: true)
      ..writeAsStringSync('/// A.\nclass A {}\n');
    metrics = await const CodeReview().analyze(project.path);
  });
  tearDown(() => project.deleteSync(recursive: true));

  test('review plans each registered fix in declaration order', () async {
    final planned = <StringFix>[];
    final fixer = StringFixer({
      StringFix.makeConstants: _RecordingRewriter(
        StringFix.makeConstants,
        planned,
      ),
      StringFix.localizeStrings: _RecordingRewriter(
        StringFix.localizeStrings,
        planned,
      ),
    });

    final review = await fixer.review(project.path, metrics);

    expect(planned, [StringFix.localizeStrings, StringFix.makeConstants]);
    expect(review.localizationBlocker, 'planned Make string constants');
  });

  test('apply runs the fix through its rewriter', () async {
    final fixer = StringFixer({
      StringFix.makeConstants: _RecordingRewriter(
        StringFix.makeConstants,
        [],
        rewritten: 2,
      ),
    });

    final outcome = await fixer.apply(
      StringReview.empty,
      StringFix.makeConstants,
      const [],
    );

    expect(outcome.summary, contains('2'));
    expect(outcome.changedFiles, ['/p/lib/a.dart']);
    await expectLater(
      fixer.apply(StringReview.empty, StringFix.passLookup, const []),
      throwsA(isA<StateError>()),
    );
  });

  group('the rewriters', () {
    final localizer = const StringLocalizer(
      ProjectConfigReader(),
      L10nGenerator(ProcessRunner()),
      CodeFormatter(ProcessRunner()),
    );
    late ReferenceFinder finder;

    setUp(() {
      finder = ReferenceFinder(
        projectPath: project.path,
        flutterSdk: const FlutterSdk(ProcessRunner()),
      );
    });
    tearDown(() => finder.dispose());

    test('localizing says why a project cannot be localized', () async {
      final rewriter = LocalizeStringsRewriter(localizer);

      final review = await rewriter.plan(
        project.path,
        metrics,
        StringReview.empty,
      );

      expect(review.localization, isNull);
      expect(review.localizationBlocker, contains('set up localization'));
      await expectLater(
        rewriter.apply(review, const []),
        throwsA(
          isA<Exception>().having(
            (e) => '$e',
            'message',
            contains('set up localization'),
          ),
        ),
      );
    });

    test('passing lookups needs the localization plan', () async {
      final rewriter = PassLookupRewriter(
        StringLookupPasser(
          finder,
          const L10nGenerator(ProcessRunner()),
          const CodeFormatter(ProcessRunner()),
        ),
      );
      final blocked = StringReview.empty.copyWith(localizationBlocker: 'no');

      final review = await rewriter.plan(project.path, metrics, blocked);

      expect(review.lookups.candidates, isEmpty);
      await expectLater(
        rewriter.apply(review, const []),
        throwsA(
          isA<Exception>().having((e) => '$e', 'message', endsWith('no')),
        ),
      );
    });

    test('making constants plans where the constants go', () async {
      const rewriter = MakeConstantsRewriter(
        StringConstantsExtractor(
          CodeFormatter(ProcessRunner()),
          ProjectConfigReader(),
        ),
      );

      final review = await rewriter.plan(
        project.path,
        metrics,
        StringReview.empty,
      );

      expect(review.constants, isNot(same(ConstantsPlan.empty)));
      expect(review.constants.className, isNotEmpty);
      expect(review.constants.candidates, isEmpty);
      final result = await rewriter.apply(review, const []);
      expect(result.rewritten, 0);
    });
  });
}
