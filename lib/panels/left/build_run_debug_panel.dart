// ignore_for_file: deprecated_member_use

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Providers
import '../../providers/app_providers.dart';

class BuildRunDebugPanel extends ConsumerStatefulWidget {
  const BuildRunDebugPanel({super.key});

  @override
  ConsumerState<BuildRunDebugPanel> createState() => _BuildRunDebugPanelState();
}

class _BuildRunDebugPanelState extends ConsumerState<BuildRunDebugPanel> {
  BuildProcessStatus _buildStatus = BuildProcessStatus.idle;
  BuildProcessStatus _runStatus = BuildProcessStatus.idle;
  BuildProcessStatus _debugStatus = BuildProcessStatus.idle;

  Process? _currentProcess;
  StringBuffer _outputBuffer = StringBuffer();
  StringBuffer _errorBuffer = StringBuffer();
  bool _hasErrors = false;
  bool _hasOutput = false;

  String get _displayOutput => _outputBuffer.toString();
  String get _displayErrors => _errorBuffer.toString();

  @override
  void dispose() {
    _currentProcess?.kill();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final currentProjectPath = ref.watch(currentProjectPathProvider);

    if (currentProjectPath == null) {
      return const Center(
        child: Text(
          'Load a project to use\nBuild/Run/Debug features',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey, fontSize: 12),
        ),
      );
    }

    return Container(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Device selector
          Container(
            padding: const EdgeInsets.all(12),
            child: DropdownButton<String>(
              value: 'Android',
              isExpanded: true,
              items: const [
                DropdownMenuItem(value: 'Android', child: Text('Android')),
                DropdownMenuItem(value: 'iOS', child: Text('iOS')),
                DropdownMenuItem(value: 'Web', child: Text('Web')),
                DropdownMenuItem(value: 'Windows', child: Text('Windows')),
                DropdownMenuItem(value: 'Linux', child: Text('Linux')),
                DropdownMenuItem(value: 'macOS', child: Text('macOS')),
              ],
              onChanged: (value) {
                // TODO: Implement device selection
              },
            ),
          ),

          // Action buttons (vertical layout)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Column(
              children: [
                _buildPanelButton(
                  label: 'Build',
                  description: 'Build app',
                  icon: Icons.build,
                  onPressed: _showBuildMenu,
                  isActive: _buildStatus == BuildProcessStatus.running,
                  isSuccess: _buildStatus == BuildProcessStatus.success,
                  isError: _buildStatus == BuildProcessStatus.error,
                ),

                const SizedBox(height: 8),

                _buildPanelButton(
                  label: 'Run',
                  description: 'Run in release mode',
                  icon: Icons.play_arrow,
                  onPressed: () => _runFlutterApp(isDebug: false),
                  isActive: _runStatus == BuildProcessStatus.running,
                  isSuccess: _runStatus == BuildProcessStatus.success,
                  isError: _runStatus == BuildProcessStatus.error,
                ),

                const SizedBox(height: 8),

                _buildPanelButton(
                  label: 'Debug',
                  description: 'Run with hot reload',
                  icon: Icons.bug_report,
                  onPressed: () => _runFlutterApp(isDebug: true),
                  isActive: _debugStatus == BuildProcessStatus.running,
                  isSuccess: _debugStatus == BuildProcessStatus.success,
                  isError: _debugStatus == BuildProcessStatus.error,
                ),

                const SizedBox(height: 8),

                _buildPanelButton(
                  label: 'Stop',
                  description: 'Stop running process',
                  icon: Icons.stop,
                  onPressed: _stopCurrentProcess,
                  backgroundColor: colorScheme.errorContainer,
                  foregroundColor: colorScheme.onErrorContainer,
                ),
              ],
            ),
          ),

          // Output areas with scrollable content
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Error output (shown first if errors exist)
                  if (_hasErrors && _displayErrors.isNotEmpty) ...[
                    Row(
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 14,
                          color: colorScheme.error,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          'Errors:',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.error,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Container(
                      constraints: const BoxConstraints(maxHeight: 70),
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: colorScheme.errorContainer,
                        border: Border.all(color: colorScheme.error, width: 1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: SingleChildScrollView(
                        child: SelectableText(
                          _displayErrors,
                          style: TextStyle(
                            fontSize: 10,
                            color: colorScheme.onErrorContainer,
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.w500,
                          ),
                          showCursor: true,
                          cursorColor: colorScheme.onErrorContainer,
                          selectionControls: materialTextSelectionControls,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],

                  // Regular output
                  if (_hasOutput && _displayOutput.isNotEmpty) ...[
                    Row(
                      children: [
                        Icon(
                          Icons.output,
                          size: 14,
                          color: colorScheme.onSurface,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          'Output:',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        Spacer(),
                        // Clear button
                        Align(
                          alignment: Alignment.centerRight,
                          child: IconButton(
                            onPressed: _clearOutput,
                            icon: const Icon(
                              Icons.backspace_outlined,
                              size: 12,
                            ),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              minimumSize: Size.zero,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: SingleChildScrollView(
                          child: SelectableText(
                            _displayOutput,
                            style: TextStyle(
                              fontSize: 10,
                              color: colorScheme.onSurfaceVariant,
                              fontFamily: 'monospace',
                            ),
                            showCursor: true,
                            cursorColor: colorScheme.onSurfaceVariant,
                            selectionControls: materialTextSelectionControls,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPanelButton({
    required String label,
    required String description,
    required IconData icon,
    required VoidCallback? onPressed,
    bool isActive = false,
    bool isSuccess = false,
    bool isError = false,
    Color? backgroundColor,
    Color? foregroundColor,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    Color bgColor = backgroundColor ?? colorScheme.primaryContainer;
    Color fgColor = foregroundColor ?? colorScheme.onPrimaryContainer;

    if (isActive) {
      bgColor = colorScheme.secondaryContainer;
      fgColor = colorScheme.onSecondaryContainer;
    } else if (isSuccess) {
      bgColor = colorScheme.primary;
      fgColor = colorScheme.onPrimary;
    } else if (isError) {
      bgColor = colorScheme.error;
      fgColor = colorScheme.onError;
    }

    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: fgColor.withOpacity(0.2), width: 1),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: fgColor),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: fgColor,
                    ),
                  ),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 11,
                      color: fgColor.withOpacity(0.8),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showBuildMenu() {
    final currentProjectPath = ref.read(currentProjectPathProvider);
    if (currentProjectPath == null) return;

    showMenu<String>(
      context: context,
      position: const RelativeRect.fromLTRB(50, 50, 100, 100),
      items: [
        const PopupMenuItem(value: 'apk', child: Text('Build APK')),
        const PopupMenuItem(value: 'aab', child: Text('Build AAB')),
        const PopupMenuItem(value: 'ipa', child: Text('Build IPA')),
        const PopupMenuItem(value: 'web', child: Text('Build Web')),
        const PopupMenuItem(value: 'windows', child: Text('Build Windows')),
        const PopupMenuItem(value: 'linux', child: Text('Build Linux')),
        const PopupMenuItem(value: 'macos', child: Text('Build macOS')),
      ],
    ).then((value) {
      if (value != null) {
        _buildFlutterApp(value);
      }
    });
  }

  Future<void> _buildFlutterApp(String target) async {
    final currentProjectPath = ref.read(currentProjectPathProvider);
    if (currentProjectPath == null) return;

    _clearOutput();
    setState(() {
      _buildStatus = BuildProcessStatus.running;
      _outputBuffer.writeln('Building for $target...');
      _hasOutput = true;
    });

    // Build command with optimization flags
    final List<String> buildArgs = ['build', target];
    if (target == 'web') {
      buildArgs.add('--no-wasm-dry-run');
    }

    try {
      final process = await Process.start(
        'flutter',
        buildArgs,
        workingDirectory: currentProjectPath,
        runInShell: true,
      );

      _currentProcess = process;

      // Handle stdout
      process.stdout.transform(const SystemEncoding().decoder).listen((data) {
        if (data.trim().isNotEmpty) {
          setState(() {
            _outputBuffer.writeln(data.trim());
            _hasOutput = true;
          });
        }
      });

      // Handle stderr as errors
      process.stderr.transform(const SystemEncoding().decoder).listen((data) {
        if (data.trim().isNotEmpty) {
          setState(() {
            _errorBuffer.writeln(data.trim());
            _hasErrors = true;
          });
        }
      });

      final exitCode = await process.exitCode;

      if (exitCode == 0) {
        setState(() {
          _buildStatus = BuildProcessStatus.success;
          _outputBuffer.writeln('✓ Build completed successfully for $target');
        });
      } else {
        setState(() {
          _buildStatus = BuildProcessStatus.error;
          _errorBuffer.writeln('✗ Build failed with exit code $exitCode');
        });
      }
    } catch (e) {
      setState(() {
        _buildStatus = BuildProcessStatus.error;
        _errorBuffer.writeln('✗ Build error: $e');
        _hasErrors = true;
      });
    } finally {
      _currentProcess = null;
      // Reset status after a delay
      Future.delayed(const Duration(seconds: 5), () {
        if (mounted) {
          setState(() {
            _buildStatus = BuildProcessStatus.idle;
          });
        }
      });
    }
  }

  Future<void> _runFlutterApp({required bool isDebug}) async {
    final currentProjectPath = ref.read(currentProjectPathProvider);
    if (currentProjectPath == null) return;

    final status = isDebug ? _debugStatus : _runStatus;
    final setStatus = isDebug
        ? (BuildProcessStatus s) => _debugStatus = s
        : (BuildProcessStatus s) => _runStatus = s;

    _clearOutput();
    setState(() {
      setStatus(BuildProcessStatus.running);
      _outputBuffer.writeln(
        '${isDebug ? 'Debugging' : 'Running'} Flutter app...',
      );
      _hasOutput = true;
    });

    try {
      final process = await Process.start(
        'flutter',
        isDebug ? ['run'] : ['run', '--release'],
        workingDirectory: currentProjectPath,
        runInShell: true,
      );

      _currentProcess = process;

      // Handle stdout
      process.stdout.transform(const SystemEncoding().decoder).listen((data) {
        if (data.trim().isNotEmpty) {
          setState(() {
            _outputBuffer.writeln(data.trim());
            _hasOutput = true;
          });
        }
      });

      // Handle stderr as errors
      process.stderr.transform(const SystemEncoding().decoder).listen((data) {
        if (data.trim().isNotEmpty) {
          setState(() {
            _errorBuffer.writeln(data.trim());
            _hasErrors = true;
          });
        }
      });

      // Process runs continuously until stopped
      final exitCode = await process.exitCode;

      if (exitCode == 0) {
        setState(() {
          setStatus(BuildProcessStatus.success);
          _outputBuffer.writeln(
            '✓ App ${isDebug ? 'debugged' : 'ran'} successfully',
          );
        });
      } else {
        setState(() {
          setStatus(BuildProcessStatus.error);
          _errorBuffer.writeln(
            '✗ App ${isDebug ? 'debug' : 'run'} failed with exit code $exitCode',
          );
        });
      }
    } catch (e) {
      setState(() {
        setStatus(BuildProcessStatus.error);
        _errorBuffer.writeln('✗ Run error: $e');
        _hasErrors = true;
      });
    }
  }

  void _stopCurrentProcess() {
    if (_currentProcess != null) {
      _currentProcess!.kill(ProcessSignal.sigterm);
      _currentProcess = null;

      setState(() {
        _buildStatus = BuildProcessStatus.idle;
        _runStatus = BuildProcessStatus.idle;
        _debugStatus = BuildProcessStatus.idle;
        _outputBuffer.writeln('Process stopped');
        _hasOutput = true;
      });
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
}

enum BuildProcessStatus { idle, running, success, error }
