part of 'core_constants.dart';

/// SharedPreferences keys, so each persisted setting is named in one place.
class PrefKeys {
  /// Which review the Analyzer tab shows: `layout` or `repeated`.
  static const String analyzerReview = 'analyzer_review';

  /// Which way the Architecture view stacks its layers: `topDown` or
  /// `leftToRight`.
  static const String architectureOrientation = 'architecture_orientation';

  /// Local model the AI panel answers with, as a `LocalModel` name.
  static const String localModel = 'local_model';

  /// Absolute path of the file last opened in the editor.
  static const String lastOpenedFile = 'last_opened_file';

  /// Whether the editor shows Markdown files rendered rather than as text.
  static const String markdownPreview = 'markdown_preview';

  /// Recently opened project folders, newest first.
  static const String mruFolders = 'mru_folders';

  /// Which previews the Preview panel lists: `file` or `project`.
  static const String previewScope = 'preview_scope';

  /// Prefix for a project's cached Info panel metrics; the project path follows.
  static const String projectMetricsPrefix = 'project_metrics_';

  /// Target platform last chosen in the Execute panel.
  static const String selectedPlatform = 'selected_platform';

  /// Theme mode name: `light`, `dark` or `system`.
  static const String themeMode = 'theme_mode';

  /// Zoom of the whole UI, `1` for actual size.
  static const String zoom = 'zoom';
}
