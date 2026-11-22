import 'package:code_forge/code_forge.dart';
import 'package:fide/models/dart_analysis.dart';
import 'package:fide/models/quality_issue.dart';
import 'package:fide/models/status_tone.dart';
import 'package:fide/services/dart_language_server.dart';
import 'package:path/path.dart' as p;

/// What a [CodeForge] editor marks in its file, each as a wavy underline,
/// a gutter mark and a minimap stripe: the diagnostics the Dart language
/// server reports on the text as typed, then the quality findings of the
/// file as last saved, less `dart analyze`'s where the server reports the
/// same diagnostics, newer.
///
/// CodeForge shows the server's diagnostics of whichever file the server
/// reports on, as the server reports on every file of the project: this
/// puts the editor's file's back each time.
class EditorDiagnostics {
  /// Creates the diagnostics [_code] shows, the language server's from
  /// [server] when there is one.
  EditorDiagnostics(this._code, {ServerDiagnostics? server})
    : _server = server {
    _code.diagnosticsNotifier.addListener(_keepShown);
    server?.addListener(_onServerChanged);
  }

  /// LSP severity of an error.
  static const int _errorSeverity = 1;

  /// LSP severity of a hint, for tones that are not a problem.
  static const int _hintSeverity = 4;

  /// LSP severity of an information.
  static const int _infoSeverity = 3;

  /// LSP severity of a warning.
  static const int _warningSeverity = 2;

  final CodeForgeController _code;

  String _filePath = '';

  /// The server's diagnostics of [_filePath] in [_shown], telling a
  /// change of them from one of another file's.
  List<LspErrors> _fromServer = const [];

  List<QualityIssue>? _issues;

  final ServerDiagnostics? _server;

  /// What the editor shows.
  List<LspErrors> _shown = const [];

  /// Stops following the editor and the server.
  void dispose() {
    _code.diagnosticsNotifier.removeListener(_keepShown);
    _server?.removeListener(_onServerChanged);
  }

  /// The diagnostics on 0-based [line], most severe first, as one message
  /// with its tone; null when the line has none.
  ({StatusTone tone, String message})? onLine(int line) {
    final onLine = [
      for (final diagnostic in _shown)
        if (diagnostic.range['start']?['line'] == line) diagnostic,
    ]..sort((a, b) => a.severity.compareTo(b.severity));
    if (onLine.isEmpty) return null;
    return (
      tone: _toneOf(onLine.first.severity),
      message: onLine.map((diagnostic) => diagnostic.message).join(' · '),
    );
  }

  /// Marks the diagnostics of [filePath], the file whose text the editor
  /// holds: the language server's, then the findings of [issues] located
  /// there, findings past the last line skipped; no findings when
  /// [issues] is null.
  void show(String filePath, List<QualityIssue>? issues) {
    _filePath = p.normalize(filePath);
    _issues = issues;
    _update();
  }

  /// Puts [_shown] back when CodeForge replaced it with the server's
  /// diagnostics of another file.
  void _keepShown() {
    final notifier = _code.diagnosticsNotifier;
    if (!identical(notifier.value, _shown)) notifier.value = _shown;
  }

  /// A diagnostic of [severity] saying [message], underlining 0-based
  /// [line] from its first non-blank character to its end.
  DiagnosticLine _lineDiagnostic(int line, int severity, String message) {
    final text = _code.getLineText(line);
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

  /// Shows the server's newer diagnostics of [_filePath]; another file's
  /// change nothing.
  void _onServerChanged() {
    if (!identical(_server?.of(_filePath), _fromServer)) _update();
  }

  /// The diagnostics of [_filePath] as [show] describes them.
  void _update() {
    final server = _server;
    final isAnalyzed = server != null && server.analyzes(_filePath);
    _fromServer = isAnalyzed ? server.of(_filePath) : const [];
    _shown = [
      ..._fromServer,
      for (final issue in _issues ?? const <QualityIssue>[])
        if (!isAnalyzed || issue.title != DartAnalysis.title)
          for (final finding in issue.findings)
            if (p.equals(finding.path, _filePath) &&
                finding.line <= _code.lineCount)
              _lineDiagnostic(
                finding.line - 1,
                _severityOf(issue.tone),
                issue.describe(finding),
              ),
    ];
    _code.diagnosticsNotifier.value = _shown;
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
