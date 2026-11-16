import 'package:fide/models/flutter_platform.dart';
import 'package:path/path.dart' as p;

/// Well-known file and folder locations inside a Flutter project.
class ProjectPaths {
  /// The project's root directory.
  final String root;

  /// Creates the locations for the project at [root].
  const ProjectPaths(this.root);

  /// The `build/` output directory.
  String get buildDir => p.join(root, 'build');

  /// Line coverage report written by `flutter test --coverage`.
  String get coverageLcov => p.join(root, 'coverage', 'lcov.info');

  /// Throws when [executable], the running app's, was built into
  /// [buildDir]: cleaning would delete the running app's own assets.
  void ensureCleanable(String executable) {
    if (p.isWithin(buildDir, executable)) {
      throw 'This project is the running app; cleaning it would delete the '
          "app's own files. Quit the app and clean from a terminal instead.";
    }
  }

  /// The `lib/` source directory.
  String get libDir => p.join(root, 'lib');

  /// The folder of [platform]'s native project, such as `ios/`.
  String platformDir(FlutterPlatform platform) => p.join(root, platform.name);

  /// The app entry point.
  String get mainDart => p.join(libDir, 'main.dart');

  /// The package manifest.
  String get pubspec => p.join(root, 'pubspec.yaml');

  /// The resolved dependency lock file.
  String get pubspecLock => p.join(root, 'pubspec.lock');
}
