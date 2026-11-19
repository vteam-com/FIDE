part of 'code_edit_agent.dart';

/// Callbacks a [CodeEditAgent] runs as it works, so the caller can show
/// progress, refresh what the edits touch and rebuild the project.
class CodeEditHooks {
  /// Receives a one-line description of each skill the model runs,
  /// starting with the skill's icon.
  final void Function(String) onStep;

  /// Receives the text of the model's reply in progress as it streams
  /// in; null when nothing shows it.
  final ReplyText? onText;

  /// Runs after a skill writes the file at this absolute path.
  final Future<void> Function(String path) onFileWritten;

  /// Checks the project for compile errors, building it when the caller
  /// needs to; completes with the errors, empty when there are none.
  final Future<String> Function() checkBuild;

  /// Runs a FIDE quick fix on the project and completes with its outcome
  /// for the model; null when the caller offers none.
  final Future<String> Function(QuickFix fix)? runQuickFix;

  /// Creates hooks from the caller's callbacks.
  const CodeEditHooks({
    required this.onStep,
    required this.onFileWritten,
    required this.checkBuild,
    this.runQuickFix,
    this.onText,
  });
}
