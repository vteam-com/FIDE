import 'package:fcheck/fcheck.dart' as fcheck;
import 'package:fide/models/locale_number.dart';
import 'package:fide/models/quality_issue.dart';
import 'package:fide/models/quality_issue.quality_finding.dart';
import 'package:path/path.dart' as p;

/// fCheck's results as [QualityIssue]s: one per analyzer that lowered the
/// score, with its findings and, where one applies, the best practice
/// that fixes them.
extension QualityIssues on fcheck.ProjectMetrics {
  /// How to localize hardcoded strings.
  static const String _hardcodedStringsGuidance =
      'Text shown to users belongs in the ARB files so it can be '
      'translated:\n\n'
      '1. Add the string to the template ARB file (`lib/l10n/app_en.arb`) '
      'under a descriptive camelCase key, with a `@key` description.\n'
      '2. Add the same key to every other ARB file.\n'
      '3. Read it with `AppLocalizations.of(context)!.yourKey`; a string '
      'with values uses an ARB placeholder such as `{count}`.\n'
      '4. Text users never see (date formats, map keys, identifiers, log '
      'messages) becomes a named constant instead.';

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

  /// The best practice fixing the findings of [domain]; none when null.
  String? _guidance(fcheck.AnalyzerDomain? domain) => switch (domain) {
    fcheck.AnalyzerDomain.hardcodedStrings =>
      usesLocalization
          ? _hardcodedStringsGuidance
          : '$_setUpLocalizationGuidance$_hardcodedStringsGuidance',
    fcheck.AnalyzerDomain.localization => _localizationGuidance,
    _ => null,
  };

  /// [analyzer]'s issue, costing [deduction] percent of the score.
  QualityIssue _issue(
    fcheck.AnalyzerScoreBreakdown analyzer,
    double deduction,
  ) {
    final domain = fcheck.AnalyzerDomain.values
        .where((domain) => domain.configName == analyzer.key)
        .firstOrNull;
    return QualityIssue(
      label:
          '${analyzer.label}: -${deduction.localized}% '
          '(${analyzer.issueCount.localized} issues)',
      guidance: _guidance(domain),
      findings: _findings(domain),
      rootPath: analysisRootPath,
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
