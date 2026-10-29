// ignore_for_file: deprecated_member_use

import 'dart:io';

import 'package:fide/constants/constants.dart';
import 'package:fide/models/action_status.dart';
import 'package:fide/models/output_log.dart';
import 'package:fide/models/panel_action.dart';
import 'package:fide/panels/left/command_actions.dart';
import 'package:fide/providers/service_providers.dart';
import 'package:fide/widgets/inline_spinner.dart';
import 'package:fide/widgets/message_box.dart';
import 'package:fide/widgets/output_panel.dart';
import 'package:fide/widgets/status_indicator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Represents `TestPanel`.
class TestPanel extends ConsumerStatefulWidget {
  final String projectPath;

  const TestPanel({super.key, required this.projectPath});

  @override
  ConsumerState<TestPanel> createState() => _TestPanelState();
}

class _TestPanelState extends ConsumerState<TestPanel> with CommandActions {
  final OutputLog _log = OutputLog();

  @override
  OutputLog get actionLog => _log;

  /// The test actions with their current status.
  List<PanelAction> get _testActions => [
    PanelAction(
      id: 'run_all_tests',
      title: 'Run All Tests',
      description: 'Run all Flutter tests in the project',
      details: '''
Runs all Flutter tests including unit tests, widget tests, and integration tests.

• Executes flutter test command
• Includes code coverage (if available)
• Runs in parallel for better performance
• Reports test failures and suggestions
        ''',
      icon: Icons.play_circle_fill,
      color: Colors.green,
      onRun: () => _runTests('run_all_tests', ['test']),
      status: statusOf('run_all_tests'),
    ),
    PanelAction(
      id: 'run_unit_tests',
      title: 'Unit Tests',
      description: 'Run only unit tests',
      details: '''
Runs unit tests located in the test/ directory.

• Fast execution for pure Dart business logic
• No Flutter rendering or UI dependencies
• Good for TDD and continuous integration
• Typically the largest set of tests
        ''',
      icon: Icons.science,
      color: Colors.blue,
      onRun: () =>
          _runTests('run_unit_tests', ['test', '--plain-name', 'unit|test']),
      status: statusOf('run_unit_tests'),
    ),
    PanelAction(
      id: 'run_widget_tests',
      title: 'Widget Tests',
      description: 'Run Flutter widget tests',
      details: '''
Runs widget tests that test Flutter UI components.

• Tests individual widgets and their behavior
• Verifies UI interactions and rendering
• Useful for component testing
• Require test environment setup
        ''',
      icon: Icons.widgets,
      color: Colors.orange,
      onRun: () =>
          _runTests('run_widget_tests', ['test', '--plain-name', 'widget']),
      status: statusOf('run_widget_tests'),
    ),
    PanelAction(
      id: 'run_coverage',
      title: 'Test Coverage',
      description: 'Run tests with coverage reporting',
      details: '''
Runs tests with code coverage collection.

• Measures how much code is tested
• Generates coverage reports
• Helps identify untested code paths
• Requires lcov package
        ''',
      icon: Icons.analytics,
      color: Colors.purple,
      onRun: () => _runTests('run_coverage', ['test', '--coverage']),
      status: statusOf('run_coverage'),
    ),
    PanelAction(
      id: 'check_test_structure',
      title: 'Validate Tests',
      description: 'Check test file structure and naming',
      details: '''
Validates test organization and naming conventions.

• Checks test file locations
• Validates test naming patterns
• Ensures proper test grouping
• Helps maintain test quality standards
        ''',
      icon: Icons.rule,
      color: Colors.teal,
      onRun: _validateTestStructure,
    ),
  ];

  /// Runs `flutter` with [arguments] as test action [id]; one test run at
  /// a time.
  Future<void> _runTests(String id, List<String> arguments) async {
    if (isAnyActionRunning) {
      MessageBox.showInfo(context, 'Tests are already running');
      return;
    }

    final succeeded = await runCommandAction(
      id,
      startMessages: ['Running flutter ${arguments.join(' ')}'],
      command: () => ref
          .read(processRunnerProvider)
          .stream(
            'flutter',
            arguments,
            workingDirectory: widget.projectPath,
            // Streamed chunks arrive trimmed and non-empty
            onStdout: (text) => setState(() => _log.addOutput(text)),
            onStderr: (text) => setState(() => _log.addError(text)),
            onStarted: (process) => trackProcess(id, process),
          ),
      successMessage: '✅ Tests completed successfully',
      failureMessage: (exitCode) => '❌ Tests failed with exit code: $exitCode',
      errorPrefix: '❌ Error running tests: ',
    );
    if (!mounted) return;
    if (succeeded) {
      MessageBox.showSuccess(context, 'Tests completed successfully');
    } else {
      MessageBox.showError(context, 'Some tests failed');
    }
  }

  /// Ignores output that arrives after the panel is gone.
  @override
  void setState(VoidCallback fn) {
    if (mounted) super.setState(fn);
  }

  /// Handles `_validateTestStructure`.
  Future<void> _validateTestStructure() async {
    _clearOutput();

    try {
      final testDir = Directory('${widget.projectPath}/test');
      if (!testDir.existsSync()) {
        setState(() {
          _log.addOutput('⚠️ No test directory found');
          _log.addOutput('Create test/ directory to add tests');
        });
        MessageBox.showInfo(context, 'No test directory found');
        return;
      }

      final testFiles = <String>[];
      final otherFiles = <String>[];

      await for (final entity in testDir.list(recursive: true)) {
        if (entity is File && entity.path.endsWith('_test.dart')) {
          testFiles.add(entity.path.replaceFirst('${widget.projectPath}/', ''));
        } else if (entity is File) {
          otherFiles.add(
            entity.path.replaceFirst('${widget.projectPath}/', ''),
          );
        }
      }

      setState(() {
        _log.addOutput('📊 Test Structure Analysis:');
        _log.addOutput('Test files found: ${testFiles.length}');

        if (testFiles.isNotEmpty) {
          _log.addOutput('Valid test files:');
          for (final file in testFiles) {
            _log.addOutput('  ✓ $file');
          }
        }

        if (otherFiles.isNotEmpty) {
          _log.addOutput('Non-test files in test/:');
          for (final file in otherFiles) {
            _log.addOutput('  ⚠️ $file');
          }
        }

        // Check for integration_test directory
        final integrationTestDir = Directory(
          '${widget.projectPath}/integration_test',
        );
        if (integrationTestDir.existsSync()) {
          _log.addOutput('✓ Integration tests directory found');
        } else {
          _log.addOutput(
            'ℹ️ Consider adding integration_test/ directory for end-to-end tests',
          );
        }
      });

      if (mounted) {
        MessageBox.showSuccess(context, 'Test structure validated');
      }
    } catch (e) {
      setState(() {
        _log.addError('❌ Error analyzing test structure: $e');
      });
      if (mounted) {
        MessageBox.showError(context, 'Error analyzing test structure');
      }
    }
  }

  void _clearOutput() => setState(_log.clear);

  /// Handles `_buildTestActions`.
  Widget _buildTestActions() {
    final colorScheme = Theme.of(context).colorScheme;

    final testActions = _testActions;

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            itemCount: testActions.length,
            itemBuilder: (_, index) {
              final action = testActions[index];
              return Card(
                margin: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.medium,
                  vertical: AppSpacing.tiny,
                ),
                child: ListTile(
                  leading: Icon(
                    action.icon,
                    color: action.color,
                    size: AppIconSize.xLarge,
                  ),
                  title: Text(
                    action.title,
                    style: TextStyle(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  subtitle: Text(
                    action.description,
                    style: TextStyle(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: AppFontSize.caption,
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Status indicator
                      if (action.isRunning)
                        const InlineSpinner()
                      else if (action.status == ActionStatus.success)
                        StatusIndicator(
                          icon: Icons.check_circle,
                          label: '',
                          color: Colors.green,
                        )
                      else if (action.status == ActionStatus.error)
                        StatusIndicator(
                          icon: Icons.error,
                          label: '',
                          color: Colors.red,
                        ),
                      // Tooltip with details
                      IconButton(
                        icon: const Icon(
                          Icons.info_outline,
                          size: AppIconSize.mediumLarge,
                        ),
                        onPressed: () => _showActionDetails(action),
                        tooltip: 'Details',
                      ),
                    ],
                  ),
                  onTap: action.isRunning ? null : action.onRun,
                ),
              );
            },
          ),
        ),

        // Output section
        if (_log.hasErrors)
          OutputPanel(
            title: 'Errors',
            text: _log.errors,
            onClear: _clearOutput,
          ),

        if (_log.hasOutput)
          OutputPanel(
            title: 'Output',
            text: _log.output,
            onClear: _clearOutput,
          ),
      ],
    );
  }

  /// Handles `_showActionDetails`.
  void _showActionDetails(PanelAction action) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(action.icon, color: action.color),
            const SizedBox(width: AppSpacing.large),
            Text(action.title),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                action.description,
                style: const TextStyle(
                  fontSize: AppFontSize.title,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: AppSpacing.xLarge),
              const Text(
                'Details:',
                style: TextStyle(
                  fontSize: AppFontSize.label,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppSpacing.medium),
              Text(
                action.details,
                style: TextStyle(
                  fontSize: AppFontSize.caption,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  height: AppLineHeight.relaxed,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              action.onRun();
            },
            child: const Text('Run'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.medium),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(AppSpacing.xLarge),
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Test Suite',
                      style: TextStyle(
                        fontSize: AppIconSize.mediumLarge,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      'Run and manage Flutter tests',
                      style: TextStyle(
                        fontSize: AppFontSize.caption,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                if (isAnyActionRunning) const InlineSpinner(),
              ],
            ),
          ),

          // Test Actions
          Expanded(child: _buildTestActions()),
        ],
      ),
    );
  }
}
