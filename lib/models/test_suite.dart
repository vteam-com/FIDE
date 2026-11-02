/// The tests of a Flutter project, sorted by kind, as relative paths.
class TestSuite {
  /// `_test.dart` files under `test/` without widget tests.
  final List<String> unitTests;

  /// `_test.dart` files under `test/` that call `testWidgets`.
  final List<String> widgetTests;

  /// Files under `test/` that are not tests (helpers, fixtures...).
  final List<String> otherFiles;

  /// Whether the project has an `integration_test/` folder.
  final bool hasIntegrationTests;

  /// Creates a suite from its sorted files.
  const TestSuite({
    this.unitTests = const [],
    this.widgetTests = const [],
    this.otherFiles = const [],
    this.hasIntegrationTests = false,
  });

  /// Every test file, unit tests first.
  List<String> get testFiles => [...unitTests, ...widgetTests];

  /// The suite's structure, one line each, for an output log.
  List<String> get reportLines => [
    '📊 Test Structure Analysis:',
    'Test files found: ${testFiles.length} '
        '(${unitTests.length} unit, ${widgetTests.length} widget)',
    if (testFiles.isNotEmpty) ...[
      'Valid test files:',
      for (final file in testFiles) '  ✓ $file',
    ],
    if (otherFiles.isNotEmpty) ...[
      'Non-test files in test/:',
      for (final file in otherFiles) '  ⚠️ $file',
    ],
    hasIntegrationTests
        ? '✓ Integration tests directory found'
        : 'ℹ️ Consider adding integration_test/ directory for end-to-end tests',
  ];
}
