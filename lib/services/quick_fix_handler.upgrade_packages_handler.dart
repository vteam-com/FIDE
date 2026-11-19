part of 'quick_fix_handler.dart';

/// Runs [QuickFix.upgradePackages] once the user confirms the upgrade,
/// through the one upgrade the Packages section shows: its busy bar, its
/// version conflicts and its measures again.
class UpgradePackagesHandler implements QuickFixHandler {
  /// Creates the handler upgrading the open project with [_upgrade].
  const UpgradePackagesHandler(this._upgrade);

  /// Upgrades the open project's packages; null without a project.
  final Future<ActionOutcome?> Function() _upgrade;

  @override
  Future<QuickFixOutcome?> run(QuickFixRequest request) async {
    if (!await request.confirm(
      'Every dependency constraint in pubspec.yaml rises to its latest '
      'resolvable version, then flutter pub get runs. Packages still on '
      'CocoaPods afterwards need a replacement.',
    )) {
      return null;
    }
    final outcome = await _upgrade();
    if (outcome == null) return null;
    return switch (outcome.tone) {
      StatusTone.success => (
        summary: outcome.message,
        changedFiles: [ProjectPaths(request.projectPath).pubspec],
      ),
      StatusTone.error => throw Exception(outcome.message),
      _ => _nothingToDo(outcome.message),
    };
  }
}
