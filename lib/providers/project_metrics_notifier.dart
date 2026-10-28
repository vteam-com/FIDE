part of 'app_providers.dart';

/// The Info panel's metrics for the current project, cached per project in
/// preferences.
class ProjectMetricsNotifier extends StateNotifier<ProjectMetrics> {
  final Ref ref;
  final SharedPreferences? prefs;

  /// Starts from the cached metrics of the current project, if any.
  ProjectMetricsNotifier(this.ref, this.prefs) : super(ProjectMetrics.empty) {
    _loadCachedMetrics();
  }

  /// Restores previously persisted project metrics from SharedPreferences on startup.
  void _loadCachedMetrics() {
    if (prefs == null) return;

    final projectPath = ref.read(currentProjectPathProvider);
    if (projectPath != null) {
      final key = '${PrefKeys.projectMetricsPrefix}$projectPath';
      final jsonString = prefs!.getString(key);
      if (jsonString != null) {
        try {
          state = ProjectMetrics.fromJson(
            jsonDecode(jsonString) as Map<String, dynamic>,
          );
        } catch (_) {
          // Ignore invalid cached data.
        }
      }
    }
  }

  /// Shows [metrics] for [projectPath] and caches them.
  Future<void> updateMetrics(String projectPath, ProjectMetrics metrics) async {
    if (prefs == null) return;

    state = metrics;
    final key = '${PrefKeys.projectMetricsPrefix}$projectPath';
    await prefs!.setString(key, jsonEncode(metrics.toJson()));
  }
}
