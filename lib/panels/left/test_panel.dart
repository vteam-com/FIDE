// ignore_for_file: deprecated_member_use

import 'dart:io';

import 'package:fide/constants.dart';
import 'package:fide/utils/message_box.dart';
import 'package:fide/widgets/output_panel.dart';
import 'package:fide/widgets/status_indicator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

part 'test_panel.test_action.dart';

enum TestStatus { idle, running, success, failure }

/// Represents `TestPanel`.
class TestPanel extends ConsumerStatefulWidget {
  final String projectPath;

  const TestPanel({super.key, required this.projectPath});

  @override
  ConsumerState<TestPanel> createState() => _TestPanelState();
}

class _TestPanelState extends ConsumerState<TestPanel> {
  Process? _currentProcess;
  final StringBuffer _outputBuffer = StringBuffer();
  final StringBuffer _errorBuffer = StringBuffer();
  bool _hasErrors = false;
  bool _hasOutput = false;

  List<TestAction> _testActions = [];
  bool _isRunningTests = false;

  @override
  void initState() {
    super.initState();

    /// Handles `_initializeTestActions`.
    _initializeTestActions();
  }

  @override
  void dispose() {
    _currentProcess?.kill();
    super.dispose();
  }

  /// Handles `_initializeTestActions`.
  void _initializeTestActions() {
    _testActions = [
      TestAction(
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
        action: () => _runTests(['flutter', 'test']),
      ),
      TestAction(
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
        action: () =>
            /// Handles `_runTests`.
            _runTests(['flutter', 'test', '--plain-name', 'unit|test']),
      ),
      TestAction(
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
        action: () => _runTests(['flutter', 'test', '--plain-name', 'widget']),
      ),
      TestAction(
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
        action: () => _runTests(['flutter', 'test', '--coverage']),
      ),
      TestAction(
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
        action: _validateTestStructure,
      ),
    ];
  }

  void _handleOutput(String data) {
    if (data.trim().isNotEmpty && mounted) {
      setState(() {
        _outputBuffer.writeln(data.trim());
        _hasOutput = true;
      });
    }
  }

  void _handleError(String data) {
    if (data.trim().isNotEmpty && mounted) {
      setState(() {
        _errorBuffer.writeln(data.trim());
        _hasErrors = true;
      });
    }
  }

  /// Handles `_runTests`.
  Future<void> _runTests(List<String> commandArgs) async {
    if (_isRunningTests) {
      MessageBox.showInfo(context, 'Tests are already running');
      return;
    }

    _clearOutput();
    setState(() => _isRunningTests = true);

    try {
      final process = await Process.start(
        commandArgs[0],
        commandArgs.sublist(1),
        workingDirectory: widget.projectPath,
        runInShell: true,
      );

      _currentProcess = process;

      // Handle stdout
      process.stdout
          .transform(const SystemEncoding().decoder)
          .listen((data) => _handleOutput(data));

      // Handle stderr as errors
      process.stderr
          .transform(const SystemEncoding().decoder)
          .listen((data) => _handleError(data));

      final exitCode = await process.exitCode;

      if (mounted) {
        if (exitCode == 0) {
          setState(() => _hasOutput = true);
          _outputBuffer.writeln('✅ Tests completed successfully');
          MessageBox.showSuccess(context, 'Tests completed successfully');
        } else {
          setState(() => _hasErrors = true);
          _errorBuffer.writeln('❌ Tests failed with exit code: $exitCode');
          MessageBox.showError(context, 'Some tests failed');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _hasErrors = true);
        _errorBuffer.writeln('❌ Error running tests: $e');
        MessageBox.showError(context, 'Error running tests: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isRunningTests = false);
      }
      _currentProcess = null;
    }
  }

  /// Handles `_validateTestStructure`.
  Future<void> _validateTestStructure() async {
    _clearOutput();

    try {
      final testDir = Directory('${widget.projectPath}/test');
      if (!testDir.existsSync()) {
        setState(() {
          _outputBuffer.writeln('⚠️ No test directory found');
          _outputBuffer.writeln('Create test/ directory to add tests');
          _hasOutput = true;
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
        _outputBuffer.writeln('📊 Test Structure Analysis:');
        _outputBuffer.writeln('Test files found: ${testFiles.length}');

        if (testFiles.isNotEmpty) {
          _outputBuffer.writeln('Valid test files:');
          for (final file in testFiles) {
            _outputBuffer.writeln('  ✓ $file');
          }
        }

        if (otherFiles.isNotEmpty) {
          _outputBuffer.writeln('Non-test files in test/:');
          for (final file in otherFiles) {
            _outputBuffer.writeln('  ⚠️ $file');
          }
        }

        // Check for integration_test directory
        final integrationTestDir = Directory(
          '${widget.projectPath}/integration_test',
        );
        if (integrationTestDir.existsSync()) {
          _outputBuffer.writeln('✓ Integration tests directory found');
        } else {
          _outputBuffer.writeln(
            'ℹ️ Consider adding integration_test/ directory for end-to-end tests',
          );
        }

        _hasOutput = true;
      });

      MessageBox.showSuccess(context, 'Test structure validated');
    } catch (e) {
      setState(() {
        _errorBuffer.writeln('❌ Error analyzing test structure: $e');
        _hasErrors = true;
      });
      MessageBox.showError(context, 'Error analyzing test structure');
    }
  }

  void _clearOutput() {
    setState(() {
      _outputBuffer.clear();
      _errorBuffer.clear();
      _hasErrors = false;
      _hasOutput = false;
    });
  }

  /// Handles `_buildTestActions`.
  Widget _buildTestActions() {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            itemCount: _testActions.length,
            itemBuilder: (_, index) {
              final action = _testActions[index];
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
                      if (action.status == TestStatus.running)
                        const SizedBox(
                          width: AppIconSize.large,
                          height: AppIconSize.large,
                          child: CircularProgressIndicator(
                            strokeWidth: AppBorderWidth.medium,
                          ),
                        )
                      else if (action.status == TestStatus.success)
                        StatusIndicator(
                          icon: Icons.check_circle,
                          label: '',
                          color: Colors.green,
                        )
                      else if (action.status == TestStatus.failure)
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
                  onTap: action.status == TestStatus.running
                      ? null
                      : action.action,
                ),
              );
            },
          ),
        ),

        // Output section
        if (_hasErrors)
          OutputPanel(
            title: 'Errors',
            text: _errorBuffer.toString(),
            onClear: _clearOutput,
          ),

        if (_hasOutput)
          OutputPanel(
            title: 'Output',
            text: _outputBuffer.toString(),
            onClear: _clearOutput,
          ),
      ],
    );
  }

  /// Handles `_showActionDetails`.
  void _showActionDetails(TestAction action) {
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
              action.action();
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
                if (_isRunningTests)
                  const SizedBox(
                    width: AppIconSize.large,
                    height: AppIconSize.large,
                    child: CircularProgressIndicator(
                      strokeWidth: AppBorderWidth.medium,
                    ),
                  ),
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
