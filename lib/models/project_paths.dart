import 'package:path/path.dart' as p;

/// Well-known file and folder locations inside a Flutter project.
class ProjectPaths {
  /// The project's root directory.
  final String root;

  /// Creates the locations for the project at [root].
  const ProjectPaths(this.root);

  /// The `build/` output directory.
  String get buildDir => p.join(root, 'build');

  /// Generated localizations class written by `flutter gen-l10n`.
  String get generatedLocalizations =>
      p.join(l10nDir, 'app_localizations.dart');

  /// Folder holding the ARB translation files.
  String get l10nDir => p.join(libDir, 'l10n');

  /// The `lib/` source directory.
  String get libDir => p.join(root, 'lib');

  /// The app entry point.
  String get mainDart => p.join(libDir, 'main.dart');

  /// The package manifest.
  String get pubspec => p.join(root, 'pubspec.yaml');

  /// The resolved dependency lock file.
  String get pubspecLock => p.join(root, 'pubspec.lock');
}
