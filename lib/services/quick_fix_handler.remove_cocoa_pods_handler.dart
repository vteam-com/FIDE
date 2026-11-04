part of 'quick_fix_handler.dart';

/// Runs [QuickFix.removeCocoaPods] once nothing needs CocoaPods and the
/// user confirms.
class RemoveCocoaPodsHandler implements QuickFixHandler {
  /// Creates the handler removing through [_migrator], finding the
  /// project's platforms with [_config].
  const RemoveCocoaPodsHandler(this._migrator, this._config);

  final ProjectConfigReader _config;

  final CocoaPodsMigrator _migrator;

  @override
  Future<QuickFixOutcome?> run(QuickFixRequest request) async {
    final migration = _migrator.inspect(
      request.projectPath,
      _config.platforms(request.projectPath),
      request.metrics.packagePlatformWarnings,
    );
    if (migration.podPlatforms.isEmpty) {
      return _nothingToDo('CocoaPods is already gone');
    }
    if (!migration.canRemove) {
      return _nothingToDo(
        'CocoaPods is still needed: '
        '${migration.issues.map((issue) => issue.label).join(', ')}',
      );
    }
    final platforms = migration.podPlatforms
        .map((platform) => platform.displayName)
        .join(', ');
    if (!await request.confirm(
      'pod deintegrate runs for $platforms, then the Podfile, Podfile.lock, '
      'Pods and .symlinks are deleted and the CocoaPods #include lines '
      'leave the xcconfig files. Build each platform afterwards.',
    )) {
      return null;
    }
    final changed = await _migrator.remove(migration);
    return (
      summary: 'Removed CocoaPods from $platforms: build to check',
      changedFiles: changed,
    );
  }
}
