import 'dart:convert';

import 'package:fide/constants/constants.dart';
import 'package:fide/models/project_metrics.dart';
import 'package:fide/providers/persisted_notifier.dart';
import 'package:fide/providers/project_lifecycle_providers.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The Info panel's metrics of the current project, starting again from
/// the cached ones when another project opens.
final projectMetricsProvider =
    StateNotifierProvider<ProjectMetricsNotifier, ProjectMetrics>(
      (ref) => ProjectMetricsNotifier(
        ref.watch(sharedPreferencesProvider.future),
        ref.watch(currentProjectPathProvider),
      ),
    );

/// The Info panel's metrics for one project, cached per project in
/// preferences: shown at once, whether or not preferences are loaded yet,
/// and saved once they are; cached metrics never replace newer ones.
class ProjectMetricsNotifier extends PersistedNotifier<ProjectMetrics> {
  /// Starts from the cached metrics of the project at [projectPath], if
  /// any, once [prefs] loads.
  ProjectMetricsNotifier(Future<SharedPreferences> prefs, this._projectPath)
    : super(prefs, ProjectMetrics.empty) {
    if (_projectPath != null) load();
  }

  /// The project whose metrics are shown and cached; null without one.
  String? _projectPath;

  /// The metrics cached for the project, or null when none were; throws
  /// for invalid cached data, which [load] ignores.
  @override
  ProjectMetrics? read(SharedPreferences prefs) {
    final projectPath = _projectPath;
    final json = projectPath == null
        ? null
        : prefs.getString(_key(projectPath));
    return json == null
        ? null
        : ProjectMetrics.fromJson(jsonDecode(json) as Map<String, dynamic>);
  }

  /// Shows [metrics], measured in the project at [projectPath], and caches
  /// them for it once preferences load; without preferences they are only
  /// shown.
  Future<void> updateMetrics(String projectPath, ProjectMetrics metrics) {
    _projectPath = projectPath;
    return persist(metrics);
  }

  /// Caches [metrics] for the project.
  @override
  Future<void> write(SharedPreferences prefs, ProjectMetrics metrics) async {
    final projectPath = _projectPath;
    if (projectPath == null) return;
    await prefs.setString(_key(projectPath), jsonEncode(metrics.toJson()));
  }

  /// Preferences key of the metrics cached for [projectPath].
  static String _key(String projectPath) =>
      '${PrefKeys.projectMetricsPrefix}$projectPath';
}
