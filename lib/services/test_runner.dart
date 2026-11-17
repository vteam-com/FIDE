import 'package:fide/models/test_suite.dart';
import 'package:fide/services/flutter_build_service.dart';
import 'package:fide/services/test_suite_inspector.dart';

/// Picks the test files of a project's suite to run.
typedef TestSelection = List<String> Function(TestSuite suite);

/// Runs a project's tests, every one or the kind a [TestSelection] picks
/// from its suite, and reports how the suite is organized.
class TestRunner {
  /// Exit code when there are no tests to run or report.
  static const int noTestsExitCode = 1;

  final FlutterBuildService _builds;
  final TestSuiteInspector _inspector;

  /// Creates a runner running `flutter test` with [_builds] on the tests
  /// [_inspector] finds.
  const TestRunner(this._builds, this._inspector);

  /// Runs `flutter test` in [projectPath] on the files [select] picks from
  /// the suite (every test when null), streaming to [output]; returns the
  /// exit code, [noTestsExitCode] when [select] picks none.
  Future<int> run(
    String projectPath,
    BuildOutput output, {
    TestSelection? select,
    bool coverage = false,
  }) async {
    if (select == null) {
      return _builds.test(projectPath, output, coverage: coverage);
    }
    final suite = await _inspector.inspect(projectPath) ?? const TestSuite();
    final paths = select(suite);
    if (paths.isEmpty) {
      output.onError('No matching test files found under test/');
      return noTestsExitCode;
    }
    return _builds.test(projectPath, output, paths: paths, coverage: coverage);
  }

  /// Writes the structure of the suite in [projectPath] to [output];
  /// returns [noTestsExitCode] when the project has no tests folder.
  Future<int> reportStructure(String projectPath, BuildOutput output) async {
    final suite = await _inspector.inspect(projectPath);
    if (suite == null) return noTestsExitCode;
    suite.reportLines.forEach(output.onOutput);
    return 0;
  }
}
