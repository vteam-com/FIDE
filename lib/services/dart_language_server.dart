import 'dart:async';

import 'package:code_forge/code_forge.dart';
import 'package:fide/constants/core_constants.dart';
import 'package:fide/services/file_type_utils.dart';
import 'package:fide/services/login_shell_environment.dart';
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;

part 'dart_language_server.server_diagnostics.dart';

/// The Dart SDK's analysis server (`dart language-server`) for one
/// project: the code editor asks it for completions, hover documentation
/// and parameter hints, and it reports the [diagnostics] of the code as
/// typed, unsaved edits included.
///
/// The editor's [CodeForgeController] talks to it through [config]. The
/// server's own requests are answered here, as it waits for its settings
/// before analyzing anything, whether an editor is open yet or not. It
/// runs until [dispose].
class DartLanguageServer {
  DartLanguageServer._(this._config, String projectPath)
    : diagnostics = ServerDiagnostics(projectPath) {
    _messages = _config.responses.listen(_onMessage);
    unawaited(_config.exitCode.then(_onExit));
  }

  /// Arguments of the Dart tool running the server over stdin and stdout.
  static const List<String> arguments = ['language-server', '--protocol=lsp'];

  /// The LSP features the editor uses: completion, hover documentation
  /// and parameter hints. FIDE does the others itself (folding, Go to
  /// Definition, rename, quick fixes) or keeps its own look (syntax
  /// colors).
  static const LspClientCapabilities capabilities = LspClientCapabilities(
    semanticHighlighting: false,
    codeAction: false,
    documentColor: false,
    documentHighlight: false,
    codeFolding: false,
    inlayHint: false,
    goToDefinition: false,
    rename: false,
  );

  /// The LSP language id of Dart files.
  static const String languageId = 'dart';

  /// The server's request for the client's settings, which it waits for
  /// before analyzing.
  static const String _configurationRequest = 'workspace/configuration';

  /// The server's notice of a file's diagnostics.
  static const String _publishDiagnostics = 'textDocument/publishDiagnostics';

  final LspStdioConfig _config;

  /// What the server last reported for each file of the project.
  final ServerDiagnostics diagnostics;

  bool _isDisposed = false;

  final Logger _logger = Logger('DartLanguageServer');

  late final StreamSubscription<Map<String, dynamic>> _messages;

  /// The connection a [CodeForgeController] is given to use the server.
  LspConfig get config => _config;

  /// Completes with the exit code once the server stops, by itself or
  /// through [dispose].
  Future<int> get exited => _config.exitCode;

  /// Starts the server of the project at [projectPath] with the Dart tool
  /// [dart] and waits for it to be ready; throws when it can't start or
  /// doesn't answer within [AppDuration.languageServerStart].
  static Future<DartLanguageServer> start({
    required String dart,
    required String projectPath,
  }) async {
    final config = await LspStdioConfig.start(
      executable: dart,
      args: arguments,
      workspacePath: projectPath,
      languageId: languageId,
      capabilities: capabilities,
      environment: await LoginShellEnvironment.overrides,
    );
    // Listening before it starts, to answer its first requests
    final server = DartLanguageServer._(config, projectPath);
    try {
      await config.initialize().timeout(AppDuration.languageServerStart);
    } catch (_) {
      server.dispose();
      rethrow;
    }
    return server;
  }

  /// Whether the server analyzes [filePath]: a Dart file of the project.
  bool analyzes(String filePath) => diagnostics.analyzes(filePath);

  /// Stops showing [filePath] to the server, which then analyzes the file
  /// as saved instead of as the editor last showed it.
  void close(String filePath) {
    if (_isDisposed) return;
    unawaited(_close(filePath));
  }

  /// Stops the server.
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    unawaited(_messages.cancel());
    diagnostics.dispose();
    _config.dispose();
  }

  /// Sends the closing of [filePath], logging a failure, as nothing waits
  /// for it.
  Future<void> _close(String filePath) async {
    try {
      await _config.closeDocument(filePath);
    } catch (error) {
      _logger.fine("Couldn't close $filePath in the language server: $error");
    }
  }

  /// Records the diagnostics the server publishes and answers its request
  /// for settings with none (its defaults), one per item it asks for.
  void _onMessage(Map<String, dynamic> message) {
    final params = message['params'];
    if (params is! Map<String, dynamic>) return;
    switch (message['method']) {
      case _publishDiagnostics:
        diagnostics.publish(params);
      case _configurationRequest:
        final items = params['items'];
        unawaited(
          _config.sendResponse(message['id'] as Object, [
            for (final _ in items is List ? items : const []) const {},
          ]),
        );
    }
  }

  /// Logs that the server stopped by itself, with its [exitCode].
  void _onExit(int exitCode) {
    if (_isDisposed) return;
    _logger.warning('The Dart language server stopped (exit code $exitCode)');
  }
}
