import 'package:path/path.dart' as p;

/// The choices the new-project wizard collects before creation starts.
class ProjectCreationRequest {
  /// Pub package name for the new project.
  final String name;

  /// Directory the project folder is created in.
  final String parentDirectory;

  /// Languages to set up; null skips localization entirely.
  final Set<String>? languages;

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
    this.useAi = false,
    this.initGit = false,
  });

  /// Full path of the project folder to create.
  String get projectPath => p.join(parentDirectory, name);
}
