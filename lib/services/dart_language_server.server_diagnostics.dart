part of 'dart_language_server.dart';

/// The diagnostics a language server last published for each file of a
/// project: it reports on every file it analyzes, not only the one an
/// editor shows. Listeners are told each time a file's change.
class ServerDiagnostics extends ChangeNotifier {
  /// Creates the diagnostics of the project at [projectPath], none yet.
  ServerDiagnostics(String projectPath)
    : _projectPath = p.normalize(projectPath);

  /// The LSP severity of an error, which a diagnostic giving none has.
  static const int _errorSeverity = 1;

  /// Each file's diagnostics, by normalized path; files without any are
  /// left out.
  final Map<String, List<LspErrors>> _byFile = {};

  final String _projectPath;

  /// Whether the server analyzes [filePath]: a Dart file of the project.
  bool analyzes(String filePath) =>
      FileTypeUtils.isDartFile(filePath) &&
      p.isWithin(_projectPath, p.normalize(filePath));

  /// The diagnostics last published for [filePath], in the server's
  /// order; the same list until the server publishes the file's again.
  List<LspErrors> of(String filePath) =>
      _byFile[p.normalize(filePath)] ?? const [];

  /// Records the `textDocument/publishDiagnostics` notice [params]: a
  /// file's URI and its diagnostics, which replace those it had.
  void publish(Map<String, dynamic> params) {
    final uri = Uri.tryParse('${params['uri']}');
    if (uri == null || !uri.isScheme('file')) return;
    final path = p.normalize(uri.toFilePath());
    final items = params['diagnostics'];
    final diagnostics = [
      for (final item in items is List ? items : const [])
        if (item case {
          'range': final Map<String, dynamic> range,
          'message': final String message,
        })
          LspErrors(
            severity: item['severity'] as int? ?? _errorSeverity,
            range: range,
            message: message,
          ),
    ];
    if (diagnostics.isEmpty) {
      if (_byFile.remove(path) == null) return;
    } else {
      _byFile[path] = diagnostics;
    }
    notifyListeners();
  }
}
