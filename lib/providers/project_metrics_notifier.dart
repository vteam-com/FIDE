part of 'app_providers.dart';

/// The Info panel's metrics for one project, cached per project in
/// preferences: shown at once, whether or not preferences are loaded yet,
/// and saved once they are.
class ProjectMetricsNotifier extends StateNotifier<ProjectMetrics> {
  /// The preferences caching metrics, once loaded.
  final Future<SharedPreferences> _prefs;

  /// Whether [updateMetrics] ran, so the cache no longer overrides the
  /// metrics shown.
  bool _isUpdated = false;

  /// Starts from the cached metrics of the project at [projectPath], if
  /// any, once [_prefs] loads.
  ProjectMetricsNotifier(this._prefs, String? projectPath)
    : super(ProjectMetrics.empty) {
    if (projectPath != null) _loadCachedMetrics(projectPath);
  }

  /// Restores the metrics cached for [projectPath], unless newer ones were
  /// shown meanwhile.
  Future<void> _loadCachedMetrics(String projectPath) async {
    final String? jsonString;
    try {
      jsonString = (await _prefs).getString(_key(projectPath));
    } catch (_) {
      return; // No preferences: nothing cached
    }
    if (jsonString == null || _isUpdated || !mounted) return;
    try {
      state = ProjectMetrics.fromJson(
        jsonDecode(jsonString) as Map<String, dynamic>,
      );
    } catch (_) {
      // Ignore invalid cached data.
    }
  }

  /// Shows [metrics] for [projectPath] and caches them once preferences
  /// load; without preferences they are only shown.
  Future<void> updateMetrics(String projectPath, ProjectMetrics metrics) async {
    _isUpdated = true;
    state = metrics;
    try {
      await (await _prefs).setString(
        _key(projectPath),
        jsonEncode(metrics.toJson()),
      );
    } catch (_) {
      // Caching is optional: the metrics are shown either way
    }
  }

  /// Preferences key of the metrics cached for [projectPath].
  static String _key(String projectPath) =>
      '${PrefKeys.projectMetricsPrefix}$projectPath';
}
