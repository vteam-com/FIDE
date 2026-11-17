import 'package:fide/constants/core_constants.dart';
import 'package:fide/models/dart_analysis.dart_diagnostic.dart';
import 'package:fide/models/locale_number.dart';
import 'package:fide/models/quality_issue.dart';
import 'package:fide/models/quality_issue.quality_finding.dart';
import 'package:fide/models/status_tone.dart';
import 'package:path/path.dart' as p;

/// What `dart analyze` found in a project: compile errors, warnings and the
/// lints of its `analysis_options.yaml`, with the analyzer's own output and
/// the points they cost the quality score.
class DartAnalysis {
  /// Creates the analysis of the project at [rootPath].
  const DartAnalysis({
    required this.rootPath,
    required this.diagnostics,
    required this.output,
  });

  /// Reads the [output] of `dart analyze` run in [rootPath]: one
  /// `severity - path:line:column - message - code` line per diagnostic,
  /// `•` separating them in a terminal instead.
  factory DartAnalysis.parse(String output, {required String rootPath}) =>
      DartAnalysis(
        rootPath: rootPath,
        output: output,
        diagnostics: [
          for (final match in _diagnosticLine.allMatches(output))
            DartDiagnostic(
              path: p.normalize(p.join(rootPath, match.namedGroup('path'))),
              line: int.parse(match.namedGroup('line')!),
              tone: switch (match.namedGroup('severity')) {
                'error' => StatusTone.error,
                'warning' => StatusTone.warning,
                _ => StatusTone.info,
              },
              message: match.namedGroup('message')!,
              code: match.namedGroup('code')!,
            ),
        ],
      );

  /// One diagnostic line: severity, `path:line:column`, message, code.
  static final RegExp _diagnosticLine = RegExp(
    r'^\s*(?<severity>error|warning|info) [-•] (?<path>.+?):(?<line>\d+):\d+ '
    r'[-•] (?<message>.+) [-•] (?<code>\w+)\s*$',
    multiLine: true,
  );

  /// The kind of problem every issue names.
  static const String title = 'Dart analyzer';

  /// For each severity, the most serious first: what `dart analyze` calls
  /// it, the quality-score points each diagnostic costs and the most they
  /// cost together.
  static const Map<StatusTone, ({String noun, int points, int maxPoints})>
  _severities = {
    StatusTone.error: (
      noun: 'error',
      points: AppMetric.dartErrorPoints,
      maxPoints: AppMetric.dartErrorPointsMax,
    ),
    StatusTone.warning: (
      noun: 'warning',
      points: AppMetric.dartWarningPoints,
      maxPoints: AppMetric.dartWarningPointsMax,
    ),
    StatusTone.info: (
      noun: 'info',
      points: AppMetric.dartInfoPoints,
      maxPoints: AppMetric.dartInfoPointsMax,
    ),
  };

  /// How to clear the analyzer's diagnostics.
  static const String _guidance =
      '`dart analyze` reports what the Dart compiler and the lints of '
      '`analysis_options.yaml` find. Fix the errors first: the app does '
      'not build with them. Many warnings and lints have an automatic '
      'fix: run `dart fix --apply` in the terminal, then fix the rest.';

  /// Every problem found, in the analyzer's order.
  final List<DartDiagnostic> diagnostics;

  /// What `dart analyze` printed, as it printed it.
  final String output;

  /// The analyzed project folder.
  final String rootPath;

  /// Quality-score points the diagnostics cost, every severity capped.
  int get deduction =>
      _severities.keys.fold(0, (sum, tone) => sum + _deductionOf(tone));

  /// One issue per severity found, errors first, each with what it costs
  /// the score and where its diagnostics are.
  List<QualityIssue> get issues => [
    for (final MapEntry(key: tone, value: severity) in _severities.entries)
      if (_found(tone) case final found when found.isNotEmpty)
        QualityIssue(
          label:
              '$title: -${_deductionOf(tone).localized}% '
              '(${found.length.count(severity.noun)})',
          title: title,
          tone: tone,
          guidance: _guidance,
          rootPath: rootPath,
          findings: [
            for (final diagnostic in found)
              QualityFinding(
                path: diagnostic.path,
                line: diagnostic.line,
                text: '${diagnostic.message} (${diagnostic.code})',
              ),
          ],
        ),
  ];

  /// Points the diagnostics of [tone] cost, capped.
  int _deductionOf(StatusTone tone) {
    final severity = _severities[tone]!;
    return (_found(tone).length * severity.points).clamp(0, severity.maxPoints);
  }

  /// The diagnostics of [tone], in the analyzer's order.
  List<DartDiagnostic> _found(StatusTone tone) => [
    for (final diagnostic in diagnostics)
      if (diagnostic.tone == tone) diagnostic,
  ];
}
