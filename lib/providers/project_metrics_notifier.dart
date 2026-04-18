part of 'app_providers.dart';

/// Represents `ProjectMetricsNotifier`.
class ProjectMetricsNotifier extends StateNotifier<Map<String, dynamic>> {
  final Ref ref;
  final SharedPreferences? prefs;

  ProjectMetricsNotifier(this.ref, this.prefs) : super({}) {
    _loadCachedMetrics();
  }

  /// Restores previously persisted project metrics from SharedPreferences on startup.
  void _loadCachedMetrics() {
    if (prefs == null) return;

    final projectPath = ref.read(currentProjectPathProvider);
    if (projectPath != null) {
      final key = 'project_metrics_$projectPath';
      final jsonString = prefs!.getString(key);
      if (jsonString != null) {
        try {
          final cached = jsonDecode(jsonString) as Map<String, dynamic>;
          state = cached;
        } catch (_) {
          // Ignore invalid cached data.
        }
      }
    }
  }

  /// Handles `ProjectMetricsNotifier.updateMetrics`.
  Future<void> updateMetrics(
    String projectPath,
    Map<String, dynamic> metrics,
  ) async {
    if (prefs == null) return;

    state = metrics;
    final key = 'project_metrics_$projectPath';
    final jsonString = jsonEncode(metrics);
    await prefs!.setString(key, jsonString);
  }
}
