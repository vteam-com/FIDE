import 'dart:io';

import 'package:fide/models/project_files.dart';
import 'package:fide/models/project_paths.dart';
import 'package:fide/models/test_suite.dart';
import 'package:path/path.dart' as p;

/// Finds a Flutter project's tests and sorts them into unit and widget
/// tests, for the Test panel.
class TestSuiteInspector {
  /// Folder holding a project's integration tests.
  static const String integrationTestFolder = 'integration_test';

  /// Suffix `flutter test` looks for in test file names.
  static const String testFileSuffix = '_test.dart';

  /// Call that marks a test file as a widget test.
  static const String _widgetTestCall = 'testWidgets(';

  /// Creates an inspector.
  const TestSuiteInspector();

  /// The tests of the project at [projectPath], each list sorted by path;
  /// null when it has no [ProjectPaths.testFolder].
  Future<TestSuite?> inspect(String projectPath) async {
    final testDir = Directory(p.join(projectPath, ProjectPaths.testFolder));
    if (!await testDir.exists()) return null;

    final unitTests = <String>[];
    final widgetTests = <String>[];
    final otherFiles = <String>[];
    await for (final file in ProjectFiles.walk(testDir.path)) {
      final path = p.relative(file.path, from: projectPath);
      if (!path.endsWith(testFileSuffix)) {
        otherFiles.add(path);
      } else if ((await file.readAsString()).contains(_widgetTestCall)) {
        widgetTests.add(path);
      } else {
        unitTests.add(path);
      }
    }
    return TestSuite(
      unitTests: unitTests..sort(),
      widgetTests: widgetTests..sort(),
      otherFiles: otherFiles..sort(),
      hasIntegrationTests: await Directory(
        p.join(projectPath, integrationTestFolder),
      ).exists(),
    );
  }
}
