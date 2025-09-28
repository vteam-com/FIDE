// ignore_for_file: deprecated_member_use

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Providers
import '../../providers/app_providers.dart';
// Widgets
import '../../widgets/platform_selector.dart';

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
  final StringBuffer _outputBuffer = StringBuffer();
  final StringBuffer _errorBuffer = StringBuffer();
  bool _hasErrors = false;
  bool _hasOutput = false;
  String _selectedPlatform = 'android';
  Set<String> _supportedPlatforms = {};

  String get _displayOutput => _outputBuffer.toString();
  String get _displayErrors => _errorBuffer.toString();

  @override
  void dispose() {
    _currentProcess?.kill();
    super.dispose();
  }

  Set<String> _getSupportedPlatforms(String projectPath) {
    final supported = <String>{};
    final projectDir = Directory(projectPath);

    if (Directory('${projectDir.path}/android').existsSync()) {
      supported.add('android');
    }
    if (Directory('${projectDir.path}/ios').existsSync()) {
      supported.add('ios');
    }
    if (Directory('${projectDir.path}/web').existsSync()) {
      supported.add('web');
    }
    if (Directory('${projectDir.path}/windows').existsSync()) {
      supported.add('windows');
    }
    if (Directory('${projectDir.path}/linux').existsSync()) {
      supported.add('linux');
    }
    if (Directory('${projectDir.path}/macos').existsSync()) {
      supported.add('macos');
    }

    return supported;
  }

  bool _canBuildOnCurrentPlatform(String targetPlatform) {
    final currentPlatform = Platform.operatingSystem;

    // Web can be built from any platform
    if (targetPlatform == 'web') return true;

    // Mobile platforms - android can be built from any, ios only from macOS
    if (targetPlatform == 'android') return true;
    if (targetPlatform == 'ios') return currentPlatform == 'macos';

    // Desktop platforms - can only be built on the same platform
    if (targetPlatform == 'windows') return currentPlatform == 'windows';
    if (targetPlatform == 'linux') return currentPlatform == 'linux';
    if (targetPlatform == 'macos') return currentPlatform == 'macos';

    return false;
  }

  String _getPlatformInstructions(String platform) {
    final currentPlatform = Platform.operatingSystem;
    final isProjectSupported = _supportedPlatforms.contains(platform);
    final canBuildOnCurrent = _canBuildOnCurrentPlatform(platform);

    if (!isProjectSupported) {
      // Project doesn't support this platform
      switch (platform) {
        case 'android':
          return 'Android support is configured.\nYou can build and run Android apps.';
        case 'ios':
          return 'iOS support is configured.\nYou can build and run iOS apps.';
        case 'web':
          return 'To enable Flutter web:\nflutter config --enable-web\n\nThen restart the IDE.';
        case 'windows':
          return 'To enable Flutter Windows desktop:\nflutter config --enable-windows-desktop\n\nThen restart the IDE.';
        case 'linux':
          return 'To enable Flutter Linux desktop:\nflutter config --enable-linux-desktop\n\nThen restart the IDE.';
        case 'macos':
          return 'To enable Flutter macOS desktop:\nflutter config --enable-macos-desktop\n\nThen restart the IDE.';
        default:
          return 'Platform not recognized.';
      }
    } else if (!canBuildOnCurrent) {
      // Project supports it but current platform can't build it
      if (platform == 'ios' && currentPlatform != 'macos') {
        return 'iOS builds require a macOS machine.\n\nYou cannot build iOS apps from $currentPlatform.';
      } else {
        return '$platform builds require a $platform machine.\n\nYou cannot build $platform apps from $currentPlatform.';
      }
    }

    return 'Platform configuration verified.';
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

    _supportedPlatforms = _getSupportedPlatforms(currentProjectPath);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PlatformSelector(
          supportedPlatforms: _supportedPlatforms,
          selectedPlatform: _selectedPlatform,
          onPlatformSelected: (platform) =>
              setState(() => _selectedPlatform = platform),
        ),

        // Action buttons (vertical layout)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Column(
            children: [
              if (_supportedPlatforms.contains(_selectedPlatform) &&
                  _canBuildOnCurrentPlatform(_selectedPlatform)) ...[
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
              ] else
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Center(
                    child: SelectableText(
                      _getPlatformInstructions(_selectedPlatform),
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 12,
                        fontFamily: 'monospace',
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ),

        // Collapsible Output section
        if (_hasOutput || _hasErrors)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: ExpansionTile(
              title: Row(
                children: [
                  Icon(
                    _hasErrors ? Icons.error_outline : Icons.output,
                    size: 16,
                    color: _hasErrors
                        ? colorScheme.error
                        : colorScheme.onSurface,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Output',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _hasErrors
                          ? colorScheme.error
                          : colorScheme.onSurface,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: _clearOutput,
                    icon: const Icon(Icons.backspace_outlined, size: 14),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 4,
                      ),
                      minimumSize: Size.zero,
                    ),
                  ),
                ],
              ),
              initiallyExpanded: true,
              children: [
                Container(
                  constraints: BoxConstraints(
                    maxHeight:
                        MediaQuery.of(context).size.height *
                        0.4, // Responsive max height
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Error output
                        if (_hasErrors && _displayErrors.isNotEmpty) ...[
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: SelectableText(
                              '═══════ Errors ═══════\n$_displayErrors',
                              style: TextStyle(
                                fontSize: 10,
                                color: colorScheme.error,
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.w500,
                              ),
                              showCursor: true,
                              cursorColor: colorScheme.error,
                              selectionControls: materialTextSelectionControls,
                            ),
                          ),
                        ],

                        // Regular output
                        if (_hasOutput && _displayOutput.isNotEmpty) ...[
                          SelectableText(
                            '═══════ Output ═══════\n$_displayOutput═══════ Log End ═══════\n',
                            style: TextStyle(
                              fontSize: 10,
                              color: colorScheme.onSurfaceVariant,
                              fontFamily: 'monospace',
                            ),
                            showCursor: true,
                            cursorColor: colorScheme.onSurfaceVariant,
                            selectionControls: materialTextSelectionControls,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: const Center(
                child: Text(
                  'No output yet',
                  style: TextStyle(color: Colors.grey, fontSize: 11),
                ),
              ),
            ),
          ),
      ],
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

    List<PopupMenuEntry<String>> menuItems = [];

    switch (_selectedPlatform) {
      case 'android':
        menuItems = const [
          PopupMenuItem(value: 'apk', child: Text('Build APK')),
          PopupMenuItem(value: 'aab', child: Text('Build AAB')),
        ];
        break;
      case 'ios':
        menuItems = const [
          PopupMenuItem(value: 'ipa', child: Text('Build IPA')),
        ];
        break;
      case 'web':
        menuItems = const [
          PopupMenuItem(value: 'web', child: Text('Build Web')),
        ];
        break;
      case 'windows':
        menuItems = const [
          PopupMenuItem(value: 'windows', child: Text('Build Windows')),
        ];
        break;
      case 'linux':
        menuItems = const [
          PopupMenuItem(value: 'linux', child: Text('Build Linux')),
        ];
        break;
      case 'macos':
        menuItems = const [
          PopupMenuItem(value: 'macos', child: Text('Build macOS')),
        ];
        break;
      default:
        menuItems = const [
          PopupMenuItem(value: 'apk', child: Text('Build APK')),
        ];
    }

    showMenu<String>(
      context: context,
      position: const RelativeRect.fromLTRB(50, 50, 100, 100),
      items: menuItems,
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
      List<String> args = isDebug ? ['run'] : ['run', '--release'];
      if (_selectedPlatform.isNotEmpty) {
        args.addAll(['-d', _selectedPlatform]);
      }
      final process = await Process.start(
        'flutter',
        args,
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
