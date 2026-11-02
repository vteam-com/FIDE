import 'package:fide/constants/constants.dart';
import 'package:fide/models/test_suite.dart';
import 'package:fide/providers/command_runner.dart';
import 'package:fide/providers/service_providers.dart';
import 'package:fide/services/flutter_build_service.dart';
import 'package:fide/services/test_suite_inspector.dart';
import 'package:fide/widgets/command_action_list.dart';
import 'package:fide/widgets/command_output.dart';
import 'package:fide/widgets/inline_spinner.dart';
import 'package:fide/widgets/message_box.dart';
import 'package:fide/widgets/panel_action.dart';
import 'package:fide/widgets/section_title.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Runs the project's tests, or a kind of them, and checks how they are
/// organized. The runs belong to [commandRunnerProvider], so they keep
/// going while the panel is hidden.
class TestPanel extends ConsumerWidget {
  /// Key of the log every test action writes to.
  static const String _logKey = 'test';

  /// Id of the action running every test.
  static const String _allTestsId = 'run_all_tests';

  /// Id of the action running the unit tests.
  static const String _unitTestsId = 'run_unit_tests';

  /// Id of the action running the widget tests.
  static const String _widgetTestsId = 'run_widget_tests';

  /// Id of the action running the tests with coverage.
  static const String _coverageId = 'run_coverage';

  /// Id of the action validating the test structure.
  static const String _validateId = 'check_test_structure';

  /// Every action of the panel: one runs at a time.
  static const List<String> _actionIds = [
    _allTestsId,
    _unitTestsId,
    _widgetTestsId,
    _coverageId,
    _validateId,
  ];

  /// Exit code reported when there are no tests to run or validate.
  static const int _noTestsExitCode = 1;

  /// Folder of the project whose tests run.
  final String projectPath;

  /// Creates the panel for the project at [projectPath].
  const TestPanel({super.key, required this.projectPath});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actions = _actions(context, ref);
    final isRunning = ref.watch(commandRunnerProvider).isAnyRunning(_actionIds);
    return SingleChildScrollView(
      child: Padding(
        padding: AppPadding.panelContent,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: AppSpacing.xLarge,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionTitle('Test Suite'),
                      Text(
                        'Run and manage Flutter tests',
                        style: AppTextStyle.secondary(context),
                      ),
                    ],
                  ),
                ),
                if (isRunning) const InlineSpinner(),
              ],
            ),
            CommandActionList(actions: actions),
            const CommandOutput(logKey: _logKey),
          ],
        ),
      ),
    );
  }

  /// The test actions.
  List<PanelAction> _actions(BuildContext context, WidgetRef ref) {
    /// Runs `flutter test` on the files [select] picks (every test when it
    /// is null) as action [id].
    void runTests(
      String id, {
      List<String> Function(TestSuite suite)? select,
      bool coverage = false,
    }) => _runTests(context, ref, id, select: select, coverage: coverage);

    return [
      PanelAction(
        id: _allTestsId,
        title: 'Run All Tests',
        description: 'Run all Flutter tests in the project',
        details: '''
Runs every test under test/: unit tests and widget tests.

• Executes flutter test command
• Runs in parallel for better performance
• Reports test failures
• Integration tests (integration_test/) need a device and are not included
        ''',
        icon: Icons.play_circle_fill,
        onRun: () => runTests(_allTestsId),
      ),
      PanelAction(
        id: _unitTestsId,
        title: 'Unit Tests',
        description: 'Run only unit tests',
        details: '''
Runs the test files under test/ that have no widget tests (no testWidgets).

• Fast execution for pure Dart business logic
• No Flutter rendering or UI dependencies
• Good for TDD and continuous integration
• Typically the largest set of tests
        ''',
        icon: Icons.science,
        onRun: () => runTests(_unitTestsId, select: (suite) => suite.unitTests),
      ),
      PanelAction(
        id: _widgetTestsId,
        title: 'Widget Tests',
        description: 'Run Flutter widget tests',
        details: '''
Runs the test files under test/ that call testWidgets.

• Tests individual widgets and their behavior
• Verifies UI interactions and rendering
• Useful for component testing
• Require test environment setup
        ''',
        icon: Icons.widgets,
        onRun: () =>
            runTests(_widgetTestsId, select: (suite) => suite.widgetTests),
      ),
      PanelAction(
        id: _coverageId,
        title: 'Test Coverage',
        description: 'Run tests with coverage reporting',
        details: '''
Runs tests with code coverage collection.

• Measures how much code is tested
• Writes coverage/lcov.info
• Helps identify untested code paths
• Requires lcov package for HTML reports
        ''',
        icon: Icons.analytics,
        onRun: () => runTests(_coverageId, coverage: true),
      ),
      PanelAction(
        id: _validateId,
        title: 'Validate Tests',
        description: 'Check test file structure and naming',
        details: '''
Validates test organization and naming conventions.

• Checks test file locations
• Validates test naming patterns
• Sorts tests into unit and widget tests
• Helps maintain test quality standards
        ''',
        icon: Icons.rule,
        onRun: () => _validateTestStructure(ref),
      ),
    ];
  }

  /// Runs `flutter test` as test action [id], on the files [select] picks
  /// from the suite (every test when null); one test run at a time.
  Future<void> _runTests(
    BuildContext context,
    WidgetRef ref,
    String id, {
    List<String> Function(TestSuite suite)? select,
    bool coverage = false,
  }) async {
    final runner = ref.read(commandRunnerProvider.notifier);
    if (ref.read(commandRunnerProvider).isAnyRunning(_actionIds)) {
      MessageBox.showInfo(context, 'Tests are already running');
      return;
    }
    final buildService = ref.read(flutterBuildServiceProvider);
    final inspector = ref.read(testSuiteInspectorProvider);

    final succeeded = await runner.run(
      id,
      logKey: _logKey,
      startMessages: ['Running flutter test${coverage ? ' --coverage' : ''}'],
      command: (output) async {
        final paths = select == null
            ? const <String>[]
            : select(await inspector.inspect(projectPath) ?? const TestSuite());
        if (select != null && paths.isEmpty) {
          output.onError('No matching test files found under test/');
          return _noTestsExitCode;
        }
        return buildService.test(
          projectPath,
          output,
          paths: paths,
          coverage: coverage,
        );
      },
      successMessage: '✅ Tests completed successfully',
      failureMessage: (exitCode) => '❌ Tests failed with exit code: $exitCode',
      errorPrefix: '❌ Error running tests: ',
    );
    if (!context.mounted) return;
    if (succeeded) {
      MessageBox.showSuccess(context, 'Tests completed successfully');
    } else {
      MessageBox.showError(context, 'Some tests failed');
    }
  }

  /// Reports how the project's tests are organized.
  Future<void> _validateTestStructure(WidgetRef ref) {
    final inspector = ref.read(testSuiteInspectorProvider);
    return ref
        .read(commandRunnerProvider.notifier)
        .run(
          _validateId,
          logKey: _logKey,
          startMessages: const [],
          command: (output) => _reportTestStructure(inspector, output),
          successMessage: '✅ Test structure validated',
          failureMessage: (_) =>
              '⚠️ No test directory found: create test/ to add tests',
          errorPrefix: '❌ Error analyzing test structure: ',
        );
  }

  /// Writes the test suite's structure to [output]; exits non-zero when
  /// the project has no tests folder.
  Future<int> _reportTestStructure(
    TestSuiteInspector inspector,
    BuildOutput output,
  ) async {
    final suite = await inspector.inspect(projectPath);
    if (suite == null) return _noTestsExitCode;
    suite.reportLines.forEach(output.onOutput);
    return 0;
  }
}
