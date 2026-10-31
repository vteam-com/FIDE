import 'package:fcheck/fcheck.dart' as fcheck;
import 'package:fide/models/locale_number.dart';
import 'package:fide/models/quality_issue.dart';
import 'package:fide/models/quality_issue.quality_finding.dart';
import 'package:fide/models/quick_fix.dart';
import 'package:fide/models/status_tone.dart';
import 'package:path/path.dart' as p;

/// fCheck's results as [QualityIssue]s: one per analyzer that lowered the
/// score, with its findings and, where one applies, the best practice
/// that fixes them.
extension QualityIssues on fcheck.ProjectMetrics {
  /// Keys named in the guidance of an out-of-sync generated class.
  static const int _maxListedKeys = 3;

  /// How to localize hardcoded strings.
  static const String _hardcodedStringsGuidance =
      'Text shown to users belongs in the ARB files so it can be '
      'translated:\n\n'
      '1. Add the string to the template ARB file (`lib/l10n/app_en.arb`) '
      'under a descriptive camelCase key, with a `@key` description.\n'
      '2. Add the same key to every other ARB file.\n'
      '3. Read it with `AppLocalizations.of(context)!.yourKey`; a string '
      'with values uses an ARB placeholder such as `{count}`.\n'
      '4. Text users never see (data ids such as Firestore collection and '
      'field names, date formats, map keys, log messages) becomes a named '
      'constant instead.';

  /// What to do before [_hardcodedStringsGuidance] when the project has no
  /// localization yet.
  static const String _setUpLocalizationGuidance =
      'The project is not localized yet: set up `flutter_localizations`, '
      '`generate: true` and `lib/l10n/app_en.arb` first (the Localization '
      'tab does it for you).\n\n';

  /// How to complete translations.
  static const String _localizationGuidance =
      'Every key of the template ARB file needs a real translation in each '
      'language: add missing or empty keys, translate text still in the '
      'base language, keep every `{placeholder}` of the template, and '
      'remove duplicate or unused keys.';

  /// The issue of the analyzer named [domain], or null when it found
  /// nothing that lowered the score.
  QualityIssue? issueFor(fcheck.AnalyzerDomain domain) {
    final key = domain.configName;
    final deduction = analyzerDeductionPercents[key] ?? 0;
    for (final analyzer in analyzerScores) {
      if (analyzer.key == key && analyzer.issueCount > 0 && deduction > 0) {
        return _issue(analyzer, deduction);
      }
    }
    return null;
  }

  /// The hardcoded-string and localization issues, the ones the Localize
  /// panel helps fix.
  List<QualityIssue> get stringIssues => [
    ?_localizationSyncIssue,
    ?issueFor(fcheck.AnalyzerDomain.hardcodedStrings),
    ?issueFor(fcheck.AnalyzerDomain.localization),
  ];

  /// Every analyzer that lowered the score, largest deduction first, then
  /// the checks bypassed by ignore comments.
  List<QualityIssue> get qualityIssues {
    final deductions = analyzerDeductionPercents;
    final failing =
        analyzerScores
            .where(
              (analyzer) =>
                  analyzer.issueCount > 0 && deductions[analyzer.key]! > 0,
            )
            .toList()
          ..sort((a, b) => deductions[b.key]!.compareTo(deductions[a.key]!));
    return [
      for (final analyzer in failing)
        _issue(analyzer, deductions[analyzer.key]!),
      if (suppressionPenaltyPoints > 0)
        QualityIssue(
          label: 'Checks bypassed: -${suppressionPenaltyPoints.localized}%',
        ),
    ];
  }

  /// Translations living in a hand-written Dart class instead of the ARB
  /// files, which `flutter gen-l10n` would drop; null when in sync.
  QualityIssue? get _localizationSyncIssue {
    final sync = localizationSync;
    if (sync == null || sync.isInSync) return null;
    final file = p.basename(sync.generatedFilePath);
    final parts = [
      if (sync.generatedOnlyKeys.isNotEmpty)
        '${sync.generatedOnlyKeys.length.localized} keys',
      if (sync.handWrittenMembers.isNotEmpty)
        '${sync.handWrittenMembers.length.localized} hand-written members',
    ];
    return QualityIssue(
      tone: StatusTone.error,
      label: 'Translations live in $file, not ARB (${parts.join(', ')})',
      guidance:
          '`flutter gen-l10n` writes `$file` from the ARB files, so anything '
          'only in the Dart file is lost the next time it runs: '
          '${sync.handWrittenMembers.isEmpty ? '' : '`${sync.handWrittenMembers.join('`, `')}`, '}'
          '${sync.generatedOnlyKeys.take(_maxListedKeys).map((key) => '`$key`').join(', ')}'
          '${sync.generatedOnlyKeys.length > _maxListedKeys ? '…' : ''}.\n\n'
          'Move every translation into the ARB files once (one per '
          'language), keep hand-written helpers in their own file, and edit '
          'only the ARB files from then on.',
      rootPath: analysisRootPath,
      quickFixes: const [QuickFix.migrateToArb],
    );
  }

  /// The best practice fixing the findings of [domain]; none when null.
  String? _guidance(fcheck.AnalyzerDomain? domain) => switch (domain) {
    fcheck.AnalyzerDomain.hardcodedStrings =>
      usesLocalization
          ? _hardcodedStringsGuidance
          : '$_setUpLocalizationGuidance$_hardcodedStringsGuidance',
    fcheck.AnalyzerDomain.localization => _localizationGuidance,
    _ => null,
  };

  /// What the AI agent does to [domain]'s findings: localize hardcoded
  /// strings and fix the rest; none for translations, which Translate with
  /// AI handles key by key.
  String? _aiVerb(fcheck.AnalyzerDomain? domain) => switch (domain) {
    fcheck.AnalyzerDomain.hardcodedStrings => 'Localize',
    // Translate with AI asks the model per key instead of the agent
    fcheck.AnalyzerDomain.localization => null,
    _ => 'Fix',
  };

  /// The fixes FIDE applies itself to [domain]'s findings: translating
  /// incomplete translations; for hardcoded strings, localizing them once
  /// the project is localized, its translations are in the ARB files, and
  /// some strings have a `BuildContext`, and making the ones without
  /// interpolations constants.
  List<QuickFix> _quickFixes(fcheck.AnalyzerDomain? domain) {
    if (domain == fcheck.AnalyzerDomain.localization) {
      final problems = {
        for (final issue in localizationIssues)
          for (final detail in issue.details) detail.problemType.name,
      };
      return [
        for (final fix in QuickFix.values)
          if (fix.localizationProblems.any(problems.contains)) fix,
      ];
    }
    if (domain != fcheck.AnalyzerDomain.hardcodedStrings) return const [];
    return [
      if (usesLocalization &&
          localizationSync?.isInSync != false &&
          hardcodedStringIssues.any(
            (issue) => issue.site?.buildContextName != null,
          ))
        QuickFix.localizeStrings,
      if (hardcodedStringIssues.any(
        (issue) => issue.site?.interpolations.isEmpty ?? false,
      ))
        QuickFix.makeConstants,
    ];
  }

  /// [analyzer]'s issue, costing [deduction] percent of the score.
  QualityIssue _issue(
    fcheck.AnalyzerScoreBreakdown analyzer,
    double deduction,
  ) {
    final domain = fcheck.AnalyzerDomain.values
        .where((domain) => domain.configName == analyzer.key)
        .firstOrNull;
    final findings = _findings(domain);
    // The count the issue's findings list shows; fCheck counts some
    // analyzers differently, such as localization by language
    final count = findings.isEmpty ? analyzer.issueCount : findings.length;
    return QualityIssue(
      label:
          '${analyzer.label}: -${deduction.localized}% '
          '(${count.localized} issues)',
      guidance: _guidance(domain),
      aiVerb: _aiVerb(domain),
      findings: findings,
      rootPath: analysisRootPath,
      quickFixes: _quickFixes(domain),
    );
  }

  /// Where [domain] found its issues; none for analyzers without
  /// locations, such as code size.
  List<QualityFinding> _findings(fcheck.AnalyzerDomain? domain) =>
      switch (domain) {
        fcheck.AnalyzerDomain.hardcodedStrings => [
          for (final issue in hardcodedStringIssues)
            _finding(issue.filePath, issue.lineNumber, '"${issue.value}"'),
        ],
        fcheck.AnalyzerDomain.localization => [
          for (final issue in localizationIssues)
            for (final detail in issue.details)
              _finding(
                detail.filePath,
                detail.lineNumber,
                '${issue.languageName}: ${detail.key} '
                '(${detail.problemType.name})',
              ),
        ],
        fcheck.AnalyzerDomain.magicNumbers => [
          for (final issue in magicNumberIssues)
            _finding(issue.filePath, issue.lineNumber, issue.value),
        ],
        fcheck.AnalyzerDomain.sourceSorting => [
          for (final issue in sourceSortIssues)
            _finding(issue.filePath, issue.lineNumber, issue.description),
        ],
        fcheck.AnalyzerDomain.layers => [
          for (final issue in layersIssues)
            _finding(issue.filePath, null, issue.message),
        ],
        fcheck.AnalyzerDomain.secrets => [
          for (final issue in secretIssues)
            if (issue.filePath case final path?)
              _finding(path, issue.lineNumber, issue.secretType ?? 'secret'),
        ],
        fcheck.AnalyzerDomain.deadCode => [
          for (final issue in deadCodeIssues)
            _finding(issue.filePath, issue.lineNumber, issue.name),
        ],
        fcheck.AnalyzerDomain.duplicateCode => [
          for (final issue in duplicateCodeIssues)
            _finding(
              issue.firstFilePath,
              issue.firstLineNumber,
              '${issue.firstSymbol} duplicates ${issue.secondSymbol} in '
              '${p.basename(issue.secondFilePath)}',
            ),
        ],
        fcheck.AnalyzerDomain.documentation => [
          for (final issue in documentationIssues)
            _finding(issue.filePath, issue.lineNumber, issue.subject),
        ],
        _ => const [],
      };

  /// A finding at [line] of [path], which fCheck gives absolute or
  /// relative to the analyzed folder; a missing line is the first.
  QualityFinding _finding(String path, int? line, String text) =>
      QualityFinding(
        path: p.normalize(p.join(analysisRootPath, path)),
        line: line ?? 1,
        text: text,
      );
}
