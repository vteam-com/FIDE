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
  BuildProcessStatus _podStatus = BuildProcessStatus.idle;

  Process? _currentProcess;
  final StringBuffer _outputBuffer = StringBuffer();
  final StringBuffer _errorBuffer = StringBuffer();
  bool _hasErrors = false;
  bool _hasOutput = false;
  String _selectedPlatform = 'android';
  Set<String> _supportedPlatforms = {};

  String get _displayOutput => _outputBuffer.toString();
  String get _displayErrors => _errorBuffer.toString();

  Future<void> _updateCocoaPods() async {
    final currentProjectPath = ref.read(currentProjectPathProvider);
    if (currentProjectPath == null) return;

    _clearOutput();
    setState(() {
      _podStatus = BuildProcessStatus.running;
      _outputBuffer.writeln('📦 Updating CocoaPods dependencies...');
      _outputBuffer.writeln('Running pod install --repo-update');
      _hasOutput = true;
    });

    try {
      final podProcess = await Process.start(
        'pod',
        ['install', '--repo-update'],
        workingDirectory: _selectedPlatform == 'ios'
            ? '$currentProjectPath/ios'
            : '$currentProjectPath/macos',
        runInShell: true,
      );

      _currentProcess = podProcess;

      // Handle stdout
      podProcess.stdout.transform(const SystemEncoding().decoder).listen((
        data,
      ) {
        if (data.trim().isNotEmpty) {
          setState(() {
            _outputBuffer.writeln(data.trim());
            _hasOutput = true;
          });
        }
      });

      // Handle stderr as errors
      podProcess.stderr.transform(const SystemEncoding().decoder).listen((
        data,
      ) {
        if (data.trim().isNotEmpty) {
          setState(() {
            _errorBuffer.writeln(data.trim());
            _hasErrors = true;
          });
        }
      });

      final exitCode = await podProcess.exitCode;

      if (exitCode == 0) {
        setState(() {
          _podStatus = BuildProcessStatus.success;
          _outputBuffer.writeln('✅ CocoaPods update completed successfully');
        });
      } else {
        setState(() {
          _podStatus = BuildProcessStatus.error;
          _errorBuffer.writeln(
            '❌ CocoaPods update failed with exit code $exitCode',
          );
        });
      }
    } catch (e) {
      setState(() {
        _podStatus = BuildProcessStatus.error;
        _errorBuffer.writeln('❌ CocoaPods error: $e');
        _hasErrors = true;
      });
    } finally {
      _currentProcess = null;
      // Reset status after a delay
      Future.delayed(const Duration(seconds: 5), () {
        if (mounted) {
          setState(() {
            _podStatus = BuildProcessStatus.idle;
          });
        }
      });
    }
  }

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
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.build_circle_outlined,
              size: 48,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'Load a project to use\nBuild/Run/Debug features',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    _supportedPlatforms = _getSupportedPlatforms(currentProjectPath);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Clean Header - Platform Selector Only
          PlatformSelector(
            supportedPlatforms: _supportedPlatforms,
            selectedPlatform: _selectedPlatform,
            onPlatformSelected: (platform) =>
                setState(() => _selectedPlatform = platform),
          ),

          // Main Content Area - No inner scrolling
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: _buildPlatformContent(context, currentProjectPath),
          ),
        ],
      ),
    );
  }

  Widget _buildPlatformContent(
    BuildContext context,
    final String currentProjectPath,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final canBuild =
        _supportedPlatforms.contains(_selectedPlatform) &&
        _canBuildOnCurrentPlatform(_selectedPlatform);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 16,
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

        // Action Buttons - No section header needed
        if (!canBuild) ...[
          // Instructions for unsupported platforms
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: colorScheme.outline.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 20,
                  color: colorScheme.secondary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _getPlatformInstructions(_selectedPlatform),
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.onSurface,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ] else ...[
          // Build Action Grid for supported platforms
          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.start,
            children: [
              // Clean action - always available
              _buildActionCard(
                icon: Icons.cleaning_services_rounded,
                label: 'Clean',
                subtitle: 'Clear cache',
                color: colorScheme.secondary,
                onPressed: _cleanFlutterApp,
                status: _cleanStatus,
                onCancel: _cancelCurrentProcess,
              ),

              // Build actions
              if (_selectedPlatform == 'android') ...[
                _buildActionCard(
                  icon: Icons.phone_android_rounded,
                  label: 'APK',
                  subtitle: 'Android app',
                  color: colorScheme.primary,
                  onPressed: () => _buildFlutterApp('apk'),
                  status: _buildStatus,
                  onCancel: _cancelCurrentProcess,
                ),
                _buildActionCard(
                  icon: Icons.archive_rounded,
                  label: 'AAB',
                  subtitle: 'Play Store',
                  color: colorScheme.tertiary,
                  onPressed: () => _buildFlutterApp('aab'),
                  status: _buildStatus,
                  onCancel: _cancelCurrentProcess,
                ),
              ] else
                _buildActionCard(
                  icon: Icons.build_rounded,
                  label: 'Build',
                  subtitle: getPlatformDisplayName(_selectedPlatform),
                  color: colorScheme.primary,
                  onPressed: () => _buildFlutterApp(_selectedPlatform),
                  status: _buildStatus,
                  onCancel: _cancelCurrentProcess,
                ),

              // CocoaPods for iOS/macOS
              if (_selectedPlatform == 'ios' && Platform.isMacOS) ...[
                _buildActionCard(
                  icon: Icons.developer_mode, // Xcode-like icon
                  label: 'iOS Pods',
                  subtitle: 'Update deps',
                  color: const Color(0xFF007ACC), // Xcode blue
                  onPressed: _updateCocoaPods,
                  status: _podStatus,
                  onCancel: _cancelCurrentProcess,
                ),
              ] else if (_selectedPlatform == 'macos' && Platform.isMacOS) ...[
                _buildActionCard(
                  icon: Icons.developer_mode, // Xcode-like icon
                  label: 'macOS Pods',
                  subtitle: 'Update deps',
                  color: const Color(0xFF007ACC), // Xcode blue
                  onPressed: _updateCocoaPods,
                  status: _podStatus,
                  onCancel: _cancelCurrentProcess,
                ),
              ],

              // Run actions
              _buildActionCard(
                icon: Icons.rocket_launch_rounded,
                label: 'Run',
                subtitle: 'Release mode',
                color: Colors.green,
                onPressed: () => _runFlutterApp(isDebug: false),
                status: _runStatus,
                onCancel: _cancelCurrentProcess,
              ),
              _buildActionCard(
                icon: Icons.bug_report_rounded,
                label: 'Debug',
                subtitle: 'Hot reload',
                color: Colors.orange,
                onPressed: () => _runFlutterApp(isDebug: true),
                status: _debugStatus,
                onCancel: _cancelCurrentProcess,
              ),
            ],
          ),
        ],

        // Output section - Direct display no expansion
        if (_hasOutput || _hasErrors)
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: colorScheme.outline.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Output header with clear button
                Row(
                  children: [
                    Icon(
                      _hasErrors ? Icons.error_outline : Icons.output,
                      size: 18,
                      color: _hasErrors
                          ? colorScheme.error
                          : colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Output',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: _clearOutput,
                      icon: const Icon(Icons.backspace_outlined, size: 16),
                      tooltip: 'Clear output',
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.all(4),
                        minimumSize: Size.zero,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Output content
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Error output
                    if (_hasErrors && _displayErrors.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.all(4),
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: colorScheme.errorContainer.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: colorScheme.error.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: SelectableText(
                          '═══════ Errors ═══════\n$_displayErrors═══════ Error End ═══════',
                          style: TextStyle(
                            fontSize: 10,
                            color: colorScheme.onErrorContainer,
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
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: colorScheme.surface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: colorScheme.outline.withOpacity(0.2),
                            width: 1,
                          ),
                        ),
                        child: SelectableText(
                          '═══════ Output ═══════\n$_displayOutput═══════ Output End ═══════',
                          style: TextStyle(
                            fontSize: 10,
                            color: colorScheme.onSurface,
                            fontFamily: 'monospace',
                          ),
                          showCursor: true,
                          cursorColor: colorScheme.onSurface,
                          selectionControls: materialTextSelectionControls,
                        ),
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

  void _cancelCurrentProcess() {
    _currentProcess?.kill();
    setState(() {
      _cleanStatus = BuildProcessStatus.idle;
      _buildStatus = BuildProcessStatus.idle;
      _runStatus = BuildProcessStatus.idle;
      _debugStatus = BuildProcessStatus.idle;
      _podStatus = BuildProcessStatus.idle;
      _outputBuffer.writeln('⚠️ Operation cancelled by user');
      _hasOutput = true;
    });
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

  String getPlatformDisplayName(String platform) {
    switch (platform) {
      case 'macos':
        return 'macOS';
      case 'windows':
        return 'Windows';
      case 'linux':
        return 'Linux';
      case 'web':
        return 'Web';
      case 'android':
        return 'Android';
      case 'ios':
        return 'iOS';
      default:
        return platform;
    }
  }

  Widget _buildActionCard({
    required IconData icon,
    required String label,
    required String subtitle,
    required Color color,
    required VoidCallback? onPressed,
    required BuildProcessStatus status,
    VoidCallback? onCancel,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDisabled = onPressed == null;
    final isRunning = status == BuildProcessStatus.running;

    // Determine colors based on status
    Color backgroundColor;
    Color foregroundColor;
    Color iconColor;

    switch (status) {
      case BuildProcessStatus.running:
        backgroundColor = Colors.amber.shade100;
        foregroundColor = Colors.amber.shade900;
        iconColor = Colors.amber.shade700;
        break;
      case BuildProcessStatus.success:
        backgroundColor = Colors.green.shade100;
        foregroundColor = Colors.green.shade900;
        iconColor = Colors.green.shade700;
        break;
      case BuildProcessStatus.error:
        backgroundColor = Colors.red.shade100;
        foregroundColor = Colors.red.shade900;
        iconColor = Colors.red.shade700;
        break;
      case BuildProcessStatus.idle:
        backgroundColor = color.withOpacity(isDisabled ? 0.1 : 0.15);
        foregroundColor = isDisabled
            ? colorScheme.onSurface.withOpacity(0.4)
            : color.withOpacity(0.9);
        iconColor = isDisabled
            ? colorScheme.onSurface.withOpacity(0.3)
            : color.withOpacity(0.8);
        break;
    }

    return InkWell(
      onTap: isRunning ? onCancel : onPressed,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 120,
        height: 80,
        padding: const EdgeInsets.all(8), // Reduced padding to fit content
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDisabled
                ? colorScheme.outline.withOpacity(0.3)
                : color.withOpacity(0.2),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min, // Use min to prevent overflow
          children: [
            // Show spinner + cancel button when running
            if (isRunning) ...[
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(iconColor),
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    onPressed: onCancel,
                    icon: Icon(Icons.stop, size: 20, color: iconColor),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    tooltip: 'Cancel operation',
                  ),
                ],
              ),
            ] else ...[
              Icon(
                status == BuildProcessStatus.success
                    ? Icons.check_circle_rounded
                    : status == BuildProcessStatus.error
                    ? Icons.error_outline_rounded
                    : icon,
                size: 20, // Slightly smaller icon
                color: iconColor,
              ),
            ],
            const SizedBox(height: 2), // Reduced spacing
            Flexible(
              // Add flexible to prevent overflow
              child: Text(
                isRunning ? 'Running...' : label,
                style: TextStyle(
                  fontSize: isRunning ? 10 : 11, // Smaller font when running
                  fontWeight: FontWeight.w600,
                  color: foregroundColor,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 1), // Reduced spacing
            Flexible(
              // Add flexible to prevent overflow
              child: Text(
                isRunning ? 'Tap to cancel' : subtitle,
                style: TextStyle(
                  fontSize: isRunning ? 7 : 8, // Smaller subtitle when running
                  color: foregroundColor.withOpacity(0.7),
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum BuildProcessStatus { idle, running, success, error }
