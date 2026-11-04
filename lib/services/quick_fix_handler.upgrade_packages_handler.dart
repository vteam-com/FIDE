part of 'quick_fix_handler.dart';

/// Runs [QuickFix.upgradePackages] once the user confirms the upgrade.
class UpgradePackagesHandler implements QuickFixHandler {
  /// Creates the handler upgrading through [_maintenance].
  const UpgradePackagesHandler(this._maintenance);

  final ProjectMaintenanceService _maintenance;

  @override
  Future<QuickFixOutcome?> run(QuickFixRequest request) async {
    if (!await request.confirm(
      'Every dependency constraint in pubspec.yaml rises to its latest '
      'resolvable version, then flutter pub get runs. Packages still on '
      'CocoaPods afterwards need a replacement.',
    )) {
      return null;
    }
    final upgraded = await _maintenance.upgradeToResolvable(
      request.projectPath,
    );
    if (upgraded.isEmpty) {
      return _nothingToDo('Every package is at its latest resolvable version');
    }
    return (
      summary: 'Upgraded ${upgraded.length.count('package')}',
      changedFiles: [ProjectPaths(request.projectPath).pubspec],
    );
  }
}
