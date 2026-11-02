import 'dart:io';
import 'dart:isolate';

import 'package:fcheck/fcheck.dart' as fcheck;

/// Checks a project's app icons with fCheck's [fcheck.AppIconChecker], on a
/// background isolate; the seam tests replace to skip the disk.
class AppIconInspector {
  /// Creates a stateless inspector.
  const AppIconInspector();

  /// The app icon slots and problems of the project at [projectPath].
  Future<fcheck.AppIconReport> inspect(String projectPath) => Isolate.run(
    () => const fcheck.AppIconChecker().inspect(Directory(projectPath)),
  );
}
