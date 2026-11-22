import 'dart:async';

import 'package:fide/constants/core_constants.dart';
import 'package:fide/providers/project_lifecycle_providers.dart';
import 'package:fide/providers/service_providers.dart';
import 'package:fide/services/dart_language_server.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

/// Logs why the Dart language server couldn't start.
final Logger _logger = Logger('DartLanguageServer');

/// The open project's Dart language server, started when an editor first
/// shows and kept until the project closes; null without a project, or
/// when it can't start (no Dart SDK), the editor then working without it.
///
/// A server that stops by itself is started again, unless it stopped
/// within [AppDuration.languageServerMinUptime] of starting.
final dartLanguageServerProvider = FutureProvider<DartLanguageServer?>((ref) {
  final projectPath = ref.watch(currentProjectPathProvider);
  // At once, so an editor without a project doesn't wait a frame
  if (projectPath == null) return null;
  return _startLanguageServer(ref, projectPath);
});

/// Starts the server of the project at [projectPath] for
/// [dartLanguageServerProvider], building with [ref], as it describes.
Future<DartLanguageServer?> _startLanguageServer(
  Ref ref,
  String projectPath,
) async {
  DartLanguageServer? started;
  var isDisposed = false;
  ref.onDispose(() {
    isDisposed = true;
    started?.dispose();
  });
  try {
    final dart = await ref
        .read(bundledDartProvider.future)
        .timeout(AppDuration.languageServerStart);
    final server = await DartLanguageServer.start(
      dart: dart,
      projectPath: projectPath,
    );
    // The project closed while the server started
    if (isDisposed) {
      server.dispose();
      return null;
    }
    started = server;
    final uptime = Stopwatch()..start();
    unawaited(
      server.exited.then((_) {
        if (!isDisposed &&
            uptime.elapsed >= AppDuration.languageServerMinUptime) {
          ref.invalidateSelf();
        }
      }),
    );
    return server;
  } catch (error) {
    _logger.warning("The Dart language server didn't start: $error");
    return null;
  }
}
