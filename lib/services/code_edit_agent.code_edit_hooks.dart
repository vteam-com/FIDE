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

  /// Runs a command in the absolute folder given, inside the project, and
  /// completes with how it went for the model; null when the caller runs
  /// none.
  final Future<String> Function(ProjectCommand command, String directory)?
  runCommand;

  /// Renames or moves the file or folder at the first absolute path to
  /// the second, both inside the project, as the project tree does: every
  /// import, export and part naming a Dart file it moves follows it.
  /// Completes with the absolute paths of the files it wrote; throws a
  /// [StateError] or [FileSystemException] when it can't. Null when the
  /// caller renames none.
  final Future<Iterable<String>> Function(String from, String to)? renameFile;

  /// Creates hooks from the caller's callbacks.
  const CodeEditHooks({
    required this.onStep,
    required this.onFileWritten,
    required this.checkBuild,
    this.runQuickFix,
    this.runCommand,
    this.renameFile,
    this.onText,
  });
}
