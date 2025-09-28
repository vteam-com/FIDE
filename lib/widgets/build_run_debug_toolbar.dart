// ignore_for_file: deprecated_member_use

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Providers
import '../providers/app_providers.dart';

class BuildRunDebugToolbar extends ConsumerStatefulWidget {
  const BuildRunDebugToolbar({super.key});

  @override
  ConsumerState<BuildRunDebugToolbar> createState() =>
      _BuildRunDebugToolbarState();
}

class _BuildRunDebugToolbarState extends ConsumerState<BuildRunDebugToolbar> {
  BuildProcessStatus _buildStatus = BuildProcessStatus.idle;
  BuildProcessStatus _runStatus = BuildProcessStatus.idle;
  BuildProcessStatus _debugStatus = BuildProcessStatus.idle;

  Process? _currentProcess;
  String? _buildOutput;

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
      return const SizedBox.shrink();
    }

    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: colorScheme.outline.withOpacity(0.2),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // Build buttons
          _buildToolbarButton(
            label: 'Build',
            icon: Icons.build,
            onPressed: _showBuildMenu,
            isActive: _buildStatus == BuildProcessStatus.running,
            isSuccess: _buildStatus == BuildProcessStatus.success,
            isError: _buildStatus == BuildProcessStatus.error,
          ),

          // Run button
          _buildToolbarButton(
            label: 'Run',
            icon: Icons.play_arrow,
            onPressed: () => _runFlutterApp(isDebug: false),
            isActive: _runStatus == BuildProcessStatus.running,
            isSuccess: _runStatus == BuildProcessStatus.success,
            isError: _runStatus == BuildProcessStatus.error,
          ),

          // Debug button
          _buildToolbarButton(
            label: 'Debug',
            icon: Icons.bug_report,
            onPressed: () => _runFlutterApp(isDebug: true),
            isActive: _debugStatus == BuildProcessStatus.running,
            isSuccess: _debugStatus == BuildProcessStatus.success,
            isError: _debugStatus == BuildProcessStatus.error,
          ),

          // Stop button
          _buildToolbarButton(
            label: 'Stop',
            icon: Icons.stop,
            onPressed: _stopCurrentProcess,
            color: colorScheme.error,
          ),

          // Separator
          Container(
            width: 1,
            height: 20,
            color: colorScheme.outline.withOpacity(0.2),
            margin: const EdgeInsets.symmetric(horizontal: 8),
          ),

          // Device selector placeholder
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: DropdownButton<String>(
              value: 'Android',
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
              underline: const SizedBox(),
              isDense: true,
            ),
          ),

          // Build output display
          if (_buildOutput != null && _buildOutput!.isNotEmpty)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  _buildOutput!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurface.withOpacity(0.8),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildToolbarButton({
    required String label,
    required IconData icon,
    required VoidCallback? onPressed,
    bool isActive = false,
    bool isSuccess = false,
    bool isError = false,
    Color? color,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    Color buttonColor = color ?? colorScheme.primary;
    if (isActive) {
      buttonColor = colorScheme.secondary;
    } else if (isSuccess) {
      buttonColor = colorScheme.primary;
    } else if (isError) {
      buttonColor = colorScheme.error;
    }

    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16, color: buttonColor),
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: buttonColor,
          fontWeight: FontWeight.w500,
        ),
      ),
      style: TextButton.styleFrom(
        foregroundColor: buttonColor,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        minimumSize: const Size(60, 32),
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

    setState(() {
      _buildStatus = BuildProcessStatus.running;
      _buildOutput = 'Building for $target...';
    });

    try {
      final process = await Process.start(
        'flutter',
        ['build', target],
        workingDirectory: currentProjectPath,
        runInShell: true,
      );

      _currentProcess = process;

      // Handle stdout
      process.stdout.transform(const SystemEncoding().decoder).listen((data) {
        setState(() {
          _buildOutput = data.trim();
        });
      });

      // Handle stderr
      process.stderr.transform(const SystemEncoding().decoder).listen((data) {
        setState(() {
          _buildOutput = 'Error: ${data.trim()}';
        });
      });

      final exitCode = await process.exitCode;

      if (exitCode == 0) {
        setState(() {
          _buildStatus = BuildProcessStatus.success;
          _buildOutput = 'Build completed successfully for $target';
        });
      } else {
        setState(() {
          _buildStatus = BuildProcessStatus.error;
          _buildOutput = 'Build failed with exit code $exitCode';
        });
      }
    } catch (e) {
      setState(() {
        _buildStatus = BuildProcessStatus.error;
        _buildOutput = 'Build error: $e';
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

    setState(() {
      setStatus(BuildProcessStatus.running);
      _buildOutput = '${isDebug ? 'Debugging' : 'Running'} Flutter app...';
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
        setState(() {
          _buildOutput = data.trim();
        });
      });

      // Handle stderr
      process.stderr.transform(const SystemEncoding().decoder).listen((data) {
        setState(() {
          _buildOutput = 'Error: ${data.trim()}';
        });
      });

      // Process runs continuously until stopped
      final exitCode = await process.exitCode;

      if (exitCode == 0) {
        setState(() {
          setStatus(BuildProcessStatus.success);
          _buildOutput = 'App ${isDebug ? 'debugged' : 'ran'} successfully';
        });
      } else {
        setState(() {
          setStatus(BuildProcessStatus.error);
          _buildOutput =
              'App ${isDebug ? 'debug' : 'run'} failed with exit code $exitCode';
        });
      }
    } catch (e) {
      setState(() {
        setStatus(BuildProcessStatus.error);
        _buildOutput = 'Run error: $e';
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
        _buildOutput = 'Process stopped';
      });
    }
  }
}

enum BuildProcessStatus { idle, running, success, error }
