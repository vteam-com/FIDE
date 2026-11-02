import 'package:code_forge/code_forge.dart';
import 'package:fide/models/quality_issue.dart';
import 'package:fide/models/status_tone.dart';
import 'package:path/path.dart' as p;

/// fCheck's findings shown in a [CodeForge] editor as diagnostics: a wavy
/// underline, a gutter mark and a minimap stripe on each finding's line.
extension QualityDiagnostics on CodeForgeController {
  /// LSP severity of an error.
  static const int _errorSeverity = 1;

  /// LSP severity of a hint, for tones that are not a problem.
  static const int _hintSeverity = 4;

  /// LSP severity of an information.
  static const int _infoSeverity = 3;

  /// LSP severity of a warning.
  static const int _warningSeverity = 2;

  /// The findings on 0-based [line], most severe first, as one message
  /// with its tone; null when the line has none.
  ({StatusTone tone, String message})? findingsAt(int line) {
    final onLine = [
      for (final diagnostic in diagnostics)
        if (diagnostic.range['start']?['line'] == line) diagnostic,
    ]..sort((a, b) => a.severity.compareTo(b.severity));
    if (onLine.isEmpty) return null;
    return (
      tone: _toneOf(onLine.first.severity),
      message: onLine.map((diagnostic) => diagnostic.message).join(' · '),
    );
  }

  /// Underlines the findings of [issues] located in the file at
  /// [filePath], the text this controller holds; clears them when
  /// [issues] is null. Findings past the last line are skipped.
  void showFindings(List<QualityIssue>? issues, String filePath) {
    final path = p.normalize(filePath);
    diagnosticsNotifier.value = [
      for (final issue in issues ?? const <QualityIssue>[])
        for (final finding in issue.findings)
          if (p.equals(finding.path, path) && finding.line <= lineCount)
            _lineDiagnostic(
              finding.line - 1,
              _severityOf(issue.tone),
              issue.describe(finding),
            ),
    ];
  }

  /// A diagnostic of [severity] saying [message], underlining 0-based
  /// [line] from its first non-blank character to its end.
  DiagnosticLine _lineDiagnostic(int line, int severity, String message) {
    final text = getLineText(line);
    final indent = text.length - text.trimLeft().length;
    return DiagnosticLine(
      severity: severity,
      range: {
        'start': {'line': line, 'character': indent},
        'end': {'line': line, 'character': text.length},
      },
      message: message,
    );
  }

  /// The LSP severity marking [tone].
  static int _severityOf(StatusTone tone) => switch (tone) {
    StatusTone.error => _errorSeverity,
    StatusTone.warning => _warningSeverity,
    StatusTone.info => _infoSeverity,
    StatusTone.success || StatusTone.neutral => _hintSeverity,
  };

  /// The tone of the LSP [severity].
  static StatusTone _toneOf(int severity) => switch (severity) {
    _errorSeverity => StatusTone.error,
    _warningSeverity => StatusTone.warning,
    _infoSeverity => StatusTone.info,
    _ => StatusTone.neutral,
  };
}
