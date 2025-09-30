// ignore_for_file: deprecated_member_use

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Providers
import '../../providers/app_providers.dart';
// Widgets
import '../../widgets/platform_selector.dart';
import '../../widgets/platform_info_section.dart';

class BuildRunDebugPanel extends ConsumerStatefulWidget {
  const BuildRunDebugPanel({super.key});

  @override
  ConsumerState<BuildRunDebugPanel> createState() => BuildRunDebugPanelState();
}

class BuildRunDebugPanelState extends ConsumerState<BuildRunDebugPanel> {
  BuildProcessStatus _cleanStatus = BuildProcessStatus.idle;
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
        Expanded(
          child: SingleChildScrollView(
            child: _buildPlatformContent(context, currentProjectPath),
          ),
        ),
      ],
    );
  }

  Widget _buildPlatformContent(
    BuildContext context,
    final String currentProjectPath,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Platform Information Section
        PlatformInfoSection(
          selectedPlatform: _selectedPlatform,
          isSupported: _supportedPlatforms.contains(_selectedPlatform),
          canBuild: _canBuildOnCurrentPlatform(_selectedPlatform),
          projectPath: currentProjectPath,
          currentHostPlatform: Platform.operatingSystem,
          onAppendOutput: appendOutput,
          onAppendError: appendError,
        ),

        // Action buttons (vertical layout)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Column(
            // spacing: 8, // Column does not have spacing property, so removed
            children: [
              // Clean button (always available)
              _buildPanelButton(
                label: 'Clean',
                description: 'Clean build artifacts',
                onPressed: _cleanFlutterApp,
                isActive: _cleanStatus == BuildProcessStatus.running,
                isSuccess: _cleanStatus == BuildProcessStatus.success,
                isError: _cleanStatus == BuildProcessStatus.error,
                backgroundColor: Theme.of(
                  context,
                ).colorScheme.secondaryContainer,
                foregroundColor: Theme.of(
                  context,
                ).colorScheme.onSecondaryContainer,
              ),

              if (_supportedPlatforms.contains(_selectedPlatform) &&
                  _canBuildOnCurrentPlatform(_selectedPlatform)) ...[
                if (_selectedPlatform == 'android') ...[
                  Row(
                    children: [
                      Expanded(
                        child: _buildPanelButton(
                          label: 'APK',
                          description: 'Build APK',
                          onPressed: () => _buildFlutterApp('apk'),
                          isActive: _buildStatus == BuildProcessStatus.running,
                          isSuccess: _buildStatus == BuildProcessStatus.success,
                          isError: _buildStatus == BuildProcessStatus.error,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildPanelButton(
                          label: 'AAB',
                          description: 'Build AAB',
                          onPressed: () => _buildFlutterApp('aab'),
                          isActive: _buildStatus == BuildProcessStatus.running,
                          isSuccess: _buildStatus == BuildProcessStatus.success,
                          isError: _buildStatus == BuildProcessStatus.error,
                        ),
                      ),
                    ],
                  ),
                ] else
                  _buildPanelButton(
                    label: 'Build',
                    description: 'Build app',
                    onPressed: () => _buildFlutterApp(_selectedPlatform),
                    isActive: _buildStatus == BuildProcessStatus.running,
                    isSuccess: _buildStatus == BuildProcessStatus.success,
                    isError: _buildStatus == BuildProcessStatus.error,
                  ),

                _buildPanelButton(
                  label: 'Run',
                  description: 'Run in release mode',
                  onPressed: () => _runFlutterApp(isDebug: false),
                  isActive: _runStatus == BuildProcessStatus.running,
                  isSuccess: _runStatus == BuildProcessStatus.success,
                  isError: _runStatus == BuildProcessStatus.error,
                ),

                _buildPanelButton(
                  label: 'Debug',
                  description: 'Run with hot reload',
                  onPressed: () => _runFlutterApp(isDebug: true),
                  isActive: _debugStatus == BuildProcessStatus.running,
                  isSuccess: _debugStatus == BuildProcessStatus.success,
                  isError: _debugStatus == BuildProcessStatus.error,
                ),
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
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
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
              ],
            ),
          )
        else
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: const Center(
              child: Text(
                'No output yet',
                style: TextStyle(color: Colors.grey, fontSize: 11),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPanelButton({
    required String label,
    required String description,
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
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: fgColor,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(fontSize: 11, color: fgColor.withOpacity(0.8)),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _cleanFlutterApp() async {
    final currentProjectPath = ref.read(currentProjectPathProvider);
    if (currentProjectPath == null) return;

    // Check if we should do deep macOS clean
    final isMacOSHost = Platform.isMacOS;
    final isMacOSTarget = _selectedPlatform == 'macos';
    final hasMacOSDirectory = Directory(
      '$currentProjectPath/macos',
    ).existsSync();
    final shouldDoDeepClean = isMacOSHost && isMacOSTarget && hasMacOSDirectory;

    _clearOutput();
    setState(() {
      _cleanStatus = BuildProcessStatus.running;
      if (shouldDoDeepClean) {
        _outputBuffer.writeln('🧹 Performing deep clean for macOS project...');
        _outputBuffer.writeln(
          '📦 This will update CocoaPods and rebuild dependencies',
        );
      } else {
        _outputBuffer.writeln('🧹 Cleaning Flutter project...');
      }
      _hasOutput = true;
    });

    try {
      if (shouldDoDeepClean) {
        await _performDeepMacOSClean(currentProjectPath);
      } else {
        await _performStandardClean(currentProjectPath);
      }

      setState(() {
        _cleanStatus = BuildProcessStatus.success;
        _outputBuffer.writeln('✓ Project cleaned successfully');
      });
    } catch (e) {
      setState(() {
        _cleanStatus = BuildProcessStatus.error;
        _errorBuffer.writeln('✗ Clean error: $e');
        _hasErrors = true;
      });
    } finally {
      _currentProcess = null;
      // Reset status after a delay
      Future.delayed(const Duration(seconds: 5), () {
        if (mounted) {
          setState(() {
            _cleanStatus = BuildProcessStatus.idle;
          });
        }
      });
    }
  }

  Future<void> _performStandardClean(String projectPath) async {
    await _performStandardCleanInternal(projectPath, false);
  }

  Future<void> _performStandardCleanInternal(
    String projectPath,
    bool isRetry,
  ) async {
    final process = await Process.start(
      'flutter',
      ['clean'],
      workingDirectory: projectPath,
      runInShell: true,
    );

    _currentProcess = process;

    bool hasCocoapodsError = false;

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
        // Check for CocoaPods repository out-of-date errors
        if (data.contains("CocoaPods's specs repository is too out-of-date") ||
            data.contains("out-of-date source repos") ||
            (data.contains("pod repo update") &&
                data.contains("You have either"))) {
          hasCocoapodsError = true;
          setState(() {
            _outputBuffer.writeln(
              '🛠️ CocoaPods repository error detected in output line: "${data.trim()}"',
            );
            _hasOutput = true;
          });
        }
        setState(() {
          _errorBuffer.writeln(data.trim());
          _hasErrors = true;
        });
      }
    });

    final exitCode = await process.exitCode;

    if (exitCode == 0) {
      // Success
    } else if (hasCocoapodsError && !isRetry) {
      // Automatically run pod repo update and retry for clean
      setState(() {
        _outputBuffer.writeln(
          '🔧 Detected CocoaPods repository issue during clean. Running pod repo update...',
        );
        _hasOutput = true;
      });

      try {
        final podProcess = await Process.start('pod', [
          'repo',
          'update',
        ], runInShell: true);

        // Handle pod repo update output
        podProcess.stdout.transform(const SystemEncoding().decoder).listen((
          data,
        ) {
          if (data.trim().isNotEmpty) {
            setState(() {
              _outputBuffer.writeln('POD: ${data.trim()}');
              _hasOutput = true;
            });
          }
        });

        podProcess.stderr.transform(const SystemEncoding().decoder).listen((
          data,
        ) {
          if (data.trim().isNotEmpty) {
            setState(() {
              _errorBuffer.writeln('POD: ${data.trim()}');
              _hasErrors = true;
            });
          }
        });

        final podExitCode = await podProcess.exitCode;

        if (podExitCode == 0) {
          setState(() {
            _outputBuffer.writeln(
              '✅ CocoaPods repository updated successfully',
            );
            _outputBuffer.writeln('🔄 Retrying Flutter clean...');
            _hasOutput = true;
          });

          // Clear error state for retry
          _errorBuffer.clear();
          _hasErrors = false;

          // Retry the clean after successful pod update
          await _performStandardCleanInternal(projectPath, true);
          return;
        } else {
          setState(() {
            _errorBuffer.writeln('❌ Failed to update CocoaPods repository');
          });
        }
      } catch (podError) {
        setState(() {
          _errorBuffer.writeln('❌ Error running pod repo update: $podError');
        });
      }
      throw 'Flutter clean failed with exit code $exitCode after attempting CocoaPods fix';
    } else {
      throw 'Flutter clean failed with exit code $exitCode';
    }
  }

  Future<void> _performDeepMacOSClean(String projectPath) async {
    // Step 1: Update pod repo in macOS directory
    setState(() {
      _outputBuffer.writeln('📦 Updating CocoaPods repository...');
      _hasOutput = true;
    });

    final macOSPath = '$projectPath/macos';
    var podProcess = await Process.start(
      'pod',
      ['repo', 'update'],
      workingDirectory: macOSPath,
      runInShell: true,
    );

    // Handle pod repo update output
    podProcess.stdout.transform(const SystemEncoding().decoder).listen((data) {
      if (data.trim().isNotEmpty) {
        setState(() {
          _outputBuffer.writeln('POD: ${data.trim()}');
          _hasOutput = true;
        });
      }
    });

    podProcess.stderr.transform(const SystemEncoding().decoder).listen((data) {
      if (data.trim().isNotEmpty) {
        setState(() {
          _errorBuffer.writeln('POD: ${data.trim()}');
          _hasErrors = true;
        });
      }
    });

    var podExitCode = await podProcess.exitCode;

    if (podExitCode != 0) {
      setState(() {
        _outputBuffer.writeln(
          '⚠️ Pod repo update failed, continuing with pod install...',
        );
        _hasOutput = true;
      });
    }

    // Step 2: Run pod install --repo-update
    setState(() {
      _outputBuffer.writeln('🔧 Running pod install with repo update...');
      _hasOutput = true;
    });

    podProcess = await Process.start(
      'pod',
      ['install', '--repo-update'],
      workingDirectory: macOSPath,
      runInShell: true,
    );

    // Handle pod install output
    podProcess.stdout.transform(const SystemEncoding().decoder).listen((data) {
      if (data.trim().isNotEmpty) {
        setState(() {
          _outputBuffer.writeln('POD: ${data.trim()}');
          _hasOutput = true;
        });
      }
    });

    podProcess.stderr.transform(const SystemEncoding().decoder).listen((data) {
      if (data.trim().isNotEmpty) {
        setState(() {
          _errorBuffer.writeln('POD: ${data.trim()}');
          _hasErrors = true;
        });
      }
    });

    podExitCode = await podProcess.exitCode;

    if (podExitCode != 0) {
      setState(() {
        _outputBuffer.writeln(
          '⚠️ Pod install failed with exit code $podExitCode, continuing with Flutter cleanup...',
        );
        _outputBuffer.writeln(
          '🔄 CocoaPods issues will require manual resolution',
        );
        _hasOutput = true;
      });
      // Don't throw - continue with Flutter steps
    } else {
      setState(() {
        _outputBuffer.writeln('✅ CocoaPods dependencies updated successfully');
        _hasOutput = true;
      });
    }

    // Step 3: Flutter clean
    setState(() {
      _outputBuffer.writeln('🧹 Running flutter clean...');
      _hasOutput = true;
    });

    var flutterProcess = await Process.start(
      'flutter',
      ['clean'],
      workingDirectory: projectPath,
      runInShell: true,
    );

    flutterProcess.stdout.transform(const SystemEncoding().decoder).listen((
      data,
    ) {
      if (data.trim().isNotEmpty) {
        setState(() {
          _outputBuffer.writeln(data.trim());
          _hasOutput = true;
        });
      }
    });

    flutterProcess.stderr.transform(const SystemEncoding().decoder).listen((
      data,
    ) {
      if (data.trim().isNotEmpty) {
        setState(() {
          _errorBuffer.writeln(data.trim());
          _hasErrors = true;
        });
      }
    });

    var flutterExitCode = await flutterProcess.exitCode;

    if (flutterExitCode != 0) {
      throw 'Flutter clean failed with exit code $flutterExitCode';
    }

    // Step 4: Flutter pub get
    setState(() {
      _outputBuffer.writeln('📦 Running flutter pub get...');
      _hasOutput = true;
    });

    flutterProcess = await Process.start(
      'flutter',
      ['pub', 'get'],
      workingDirectory: projectPath,
      runInShell: true,
    );

    flutterProcess.stdout.transform(const SystemEncoding().decoder).listen((
      data,
    ) {
      if (data.trim().isNotEmpty) {
        setState(() {
          _outputBuffer.writeln(data.trim());
          _hasOutput = true;
        });
      }
    });

    flutterProcess.stderr.transform(const SystemEncoding().decoder).listen((
      data,
    ) {
      if (data.trim().isNotEmpty) {
        setState(() {
          _errorBuffer.writeln(data.trim());
          _hasErrors = true;
        });
      }
    });

    flutterExitCode = await flutterProcess.exitCode;

    if (flutterExitCode != 0) {
      throw 'Flutter pub get failed with exit code $flutterExitCode';
    }

    // Step 5: Flutter build macos
    setState(() {
      _outputBuffer.writeln('🔨 Running flutter build macos...');
      _hasOutput = true;
    });

    flutterProcess = await Process.start(
      'flutter',
      ['build', 'macos'],
      workingDirectory: projectPath,
      runInShell: true,
    );

    flutterProcess.stdout.transform(const SystemEncoding().decoder).listen((
      data,
    ) {
      if (data.trim().isNotEmpty) {
        setState(() {
          _outputBuffer.writeln(data.trim());
          _hasOutput = true;
        });
      }
    });

    flutterProcess.stderr.transform(const SystemEncoding().decoder).listen((
      data,
    ) {
      if (data.trim().isNotEmpty) {
        setState(() {
          _errorBuffer.writeln(data.trim());
          _hasErrors = true;
        });
      }
    });

    flutterExitCode = await flutterProcess.exitCode;

    if (flutterExitCode != 0) {
      throw 'Flutter build macos failed with exit code $flutterExitCode';
    }

    setState(() {
      _outputBuffer.writeln('✨ Deep clean and rebuild completed successfully!');
      _hasOutput = true;
    });
  }

  Future<void> _buildFlutterApp(String target) async {
    await _buildFlutterAppInternal(target, false);
  }

  Future<void> _buildFlutterAppInternal(String target, bool isRetry) async {
    final currentProjectPath = ref.read(currentProjectPathProvider);
    if (currentProjectPath == null) return;

    _clearOutput();
    setState(() {
      _buildStatus = BuildProcessStatus.running;
      _outputBuffer.writeln(
        isRetry ? 'Retrying build for $target...' : 'Building for $target...',
      );
      _hasOutput = true;
    });

    // Build command with optimization flags
    final List<String> buildArgs = ['build', target];
    if (target == 'web') {
      buildArgs.add('--no-wasm-dry-run');
    }

    bool hasCocoapodsError = false;

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
          // Check for CocoaPods repository out-of-date errors
          if (data.contains(
                "CocoaPods's specs repository is too out-of-date",
              ) ||
              data.contains("out-of-date source repos") ||
              (data.contains("pod repo update") &&
                  data.contains("You have either"))) {
            hasCocoapodsError = true;
            setState(() {
              _outputBuffer.writeln(
                '🛠️ CocoaPods repository error detected in output line: "${data.trim()}"',
              );
              _hasOutput = true;
            });
          }
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
      } else if (hasCocoapodsError && target == 'macos' && !isRetry) {
        // Automatically run pod repo update and retry for macOS
        setState(() {
          _outputBuffer.writeln(
            '🔧 Detected CocoaPods repository issue. Running pod repo update...',
          );
          _hasOutput = true;
        });

        try {
          final podProcess = await Process.start('pod', [
            'repo',
            'update',
          ], runInShell: true);

          // Handle pod repo update output
          podProcess.stdout.transform(const SystemEncoding().decoder).listen((
            data,
          ) {
            if (data.trim().isNotEmpty) {
              setState(() {
                _outputBuffer.writeln('POD: ${data.trim()}');
                _hasOutput = true;
              });
            }
          });

          podProcess.stderr.transform(const SystemEncoding().decoder).listen((
            data,
          ) {
            if (data.trim().isNotEmpty) {
              setState(() {
                _errorBuffer.writeln('POD: ${data.trim()}');
                _hasErrors = true;
              });
            }
          });

          final podExitCode = await podProcess.exitCode;

          if (podExitCode == 0) {
            setState(() {
              _outputBuffer.writeln(
                '✅ CocoaPods repository updated successfully',
              );
              _outputBuffer.writeln('🔄 Retrying Flutter build...');
              _hasOutput = true;
            });

            // Clear error state for retry
            _errorBuffer.clear();
            _hasErrors = false;

            // Retry the build after successful pod update
            await _buildFlutterAppInternal(target, true);
            return;
          } else {
            setState(() {
              _errorBuffer.writeln('❌ Failed to update CocoaPods repository');
              _buildStatus = BuildProcessStatus.error;
            });
          }
        } catch (podError) {
          setState(() {
            _errorBuffer.writeln('❌ Error running pod repo update: $podError');
            _buildStatus = BuildProcessStatus.error;
          });
        }
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
      if (!hasCocoapodsError || isRetry) {
        // Reset status after a delay (don't reset for CocoaPods auto-fix)
        Future.delayed(const Duration(seconds: 5), () {
          if (mounted) {
            setState(() {
              _buildStatus = BuildProcessStatus.idle;
            });
          }
        });
      }
    }
  }

  String _getDeviceTarget(String platform) {
    switch (platform) {
      case 'macos':
        return 'macos';
      case 'windows':
        return 'windows';
      case 'linux':
        return 'linux';
      case 'web':
        return 'chrome';
      case 'android':
        return 'android'; // Flutter will auto-select available device
      case 'ios':
        return 'ios'; // Flutter will auto-select available simulator/device
      default:
        return platform;
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

      final deviceTarget = _getDeviceTarget(_selectedPlatform);
      args.addAll(['-d', deviceTarget]);

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

  void _clearOutput() {
    setState(() {
      _outputBuffer.clear();
      _errorBuffer.clear();
      _hasErrors = false;
      _hasOutput = false;
    });
  }

  void appendOutput(String text) {
    setState(() {
      _outputBuffer.write(text);
      _hasOutput = true;
    });
  }

  void appendError(String text) {
    setState(() {
      _errorBuffer.write(text);
      _hasErrors = true;
    });
  }
}

enum BuildProcessStatus { idle, running, success, error }
