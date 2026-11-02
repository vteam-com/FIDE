import 'package:path/path.dart' as p;

/// The choices the new-project wizard collects before creation starts.
class ProjectCreationRequest {
  /// Language the template ARB file uses when none is chosen.
  static const String englishLanguage = 'en';

  /// Pub package name for the new project.
  final String name;

  /// Directory the project folder is created in.
  final String parentDirectory;

  /// Languages to set up; null skips localization entirely.
  final Set<String>? languages;

  /// Language the generated app falls back to: its template ARB file and
  /// first supported locale.
  final String defaultLanguage;

  /// What the app should do, in the user's words; empty for a generic app.
  final String description;

  /// Whether to replace the template files with AI-generated ones.
  final bool useAi;

  /// Whether to create a Git repository with an initial commit.
  final bool initGit;

  /// Whether the Flutter tool was found; creation fails fast without it.
  final bool flutterAvailable;

  /// Creates a request for a project named [name] inside [parentDirectory].
  const ProjectCreationRequest({
    required this.name,
    required this.parentDirectory,
    required this.flutterAvailable,
    this.languages,
    this.defaultLanguage = englishLanguage,
    this.description = '',
    this.useAi = false,
    this.initGit = false,
  });

  /// Full path of the project folder to create.
  String get projectPath => p.join(parentDirectory, name);
}
