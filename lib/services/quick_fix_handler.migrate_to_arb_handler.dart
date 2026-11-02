part of 'quick_fix_handler.dart';

/// Runs [QuickFix.migrateToArb] once the user confirms the move.
class MigrateToArbHandler implements QuickFixHandler {
  /// Creates the handler migrating through [_migrator].
  const MigrateToArbHandler(this._migrator);

  final ArbMigrator _migrator;

  @override
  Future<QuickFixOutcome?> run(QuickFixRequest request) async {
    final sync = request.metrics.localizationSync;
    if (sync == null || sync.isInSync) {
      return _nothingToDo('Already migrated to ARB');
    }
    final moved = sync.handWrittenMembers;
    if (!await request.confirm(
      'Every translation in ${p.basename(sync.generatedFilePath)} and its '
      'locale files moves to the ARB files, '
      '${moved.isEmpty ? '' : '${moved.join(', ')} move to their own file, '}'
      'and flutter gen-l10n regenerates the classes. If the project ends '
      'up with more analyzer errors, every file is restored.',
    )) {
      return null;
    }
    final result = await _migrator.migrate(request.projectPath, sync);
    return (summary: result.summary, changedFiles: result.changedFiles);
  }
}
