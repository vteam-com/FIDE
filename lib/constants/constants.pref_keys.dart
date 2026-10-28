part of 'constants.dart';

/// SharedPreferences keys, so each persisted setting is named in one place.
class PrefKeys {
  /// Absolute path of the file last opened in the editor.
  static const String lastOpenedFile = 'last_opened_file';

  /// Recently opened project folders, newest first.
  static const String mruFolders = 'mru_folders';

  /// Prefix for a project's cached Info panel metrics; the project path follows.
  static const String projectMetricsPrefix = 'project_metrics_';

  /// Target platform last chosen in the Execute panel.
  static const String selectedPlatform = 'selected_platform';

  /// Theme mode name: `light`, `dark` or `system`.
  static const String themeMode = 'theme_mode';
}
