part of 'quick_fix_handler.dart';

/// What a [QuickFixHandler] works from: the project, its fresh analysis
/// and the caller's hooks.
class QuickFixRequest {
  /// Creates the request to fix the project at [projectPath], analyzed as
  /// [metrics].
  const QuickFixRequest({
    required this.projectPath,
    required this.metrics,
    required this.confirm,
    this.onProgress,
    this.cancel,
  });

  /// Root of the project to fix.
  final String projectPath;

  /// fCheck's fresh analysis of the project.
  final fcheck.ProjectMetrics metrics;

  /// Asks the user to confirm the fix, explained by the message; true
  /// when the fix runs unasked.
  final Future<bool> Function(String message) confirm;

  /// Receives each long step, such as a batch of translations.
  final void Function(String)? onProgress;

  /// Stops the fix's model requests.
  final AiCancelToken? cancel;
}
