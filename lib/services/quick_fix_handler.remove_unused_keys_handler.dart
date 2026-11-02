part of 'quick_fix_handler.dart';

/// Runs [QuickFix.removeUnusedKeys] once the user confirms the keys.
class RemoveUnusedKeysHandler implements QuickFixHandler {
  /// Creates the handler removing keys through [_remover].
  const RemoveUnusedKeysHandler(this._remover);

  final ArbKeyRemover _remover;

  @override
  Future<QuickFixOutcome?> run(QuickFixRequest request) async {
    final keys = ArbKeyRemover.unusedKeys(request.metrics);
    if (keys.isEmpty) return _nothingToDo('No unused keys');
    if (!await request.confirm(
      '${keys.join(', ')} ${keys.length == 1 ? 'is' : 'are'} not used '
      'by the code: each is removed from every ARB file with its '
      'metadata, and the classes are regenerated.',
    )) {
      return null;
    }
    final result = await _remover.apply(request.projectPath, keys);
    return (summary: result.summary, changedFiles: result.changedFiles);
  }
}
