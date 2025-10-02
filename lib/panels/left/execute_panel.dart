// ignore_for_file: deprecated_member_use

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Providers
import '../../providers/app_providers.dart';
// Widgets
import '../../widgets/platform_selector.dart';
import '../../widgets/platform_info_section.dart';

enum BuildProcessStatus { idle, running, success, error }

class ExecutePanel extends ConsumerStatefulWidget {
  const ExecutePanel({super.key});

  @override
  ConsumerState<ExecutePanel> createState() => ExecutePanelState();
}

class ExecutePanelState extends ConsumerState<ExecutePanel> {
  BuildProcessStatus _cleanStatus = BuildProcessStatus.idle;
  BuildProcessStatus _buildStatus = BuildProcessStatus.idle;
  BuildProcessStatus _runStatus = BuildProcessStatus.idle;
  BuildProcessStatus _debugStatus = BuildProcessStatus.idle;
  BuildProcessStatus _podStatus = BuildProcessStatus.idle;

  Process? _currentProcess;
  final Map<String, StringBuffer> _outputBuffers = {};
  final Map<String, StringBuffer> _errorBuffers = {};
  final Map<String, bool> _hasErrorsMap = {};
  final Map<String, bool> _hasOutputMap = {};
  String _selectedPlatform = 'android';
  Set<String> _supportedPlatforms = {};

  @override
  void initState() {
    super.initState();
    _loadSelectedPlatform();
  }

  Future<void> _loadSelectedPlatform() async {
    final prefs = await SharedPreferences.getInstance();
    final savedPlatform = prefs.getString('selected_platform') ?? 'android';
    setState(() {
      _selectedPlatform = savedPlatform;
    });
  }

  Future<void> _saveSelectedPlatform(String platform) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_platform', platform);
  }

  String get _displayOutput =>
      _outputBuffers[_selectedPlatform]?.toString() ?? '';
  String get _displayErrors =>
      _errorBuffers[_selectedPlatform]?.toString() ?? '';

  // Ensure platform buffers are initialized
  void _ensurePlatformBuffers(String platform) {
    _outputBuffers.putIfAbsent(platform, () => StringBuffer());
    _errorBuffers.putIfAbsent(platform, () => StringBuffer());
    _hasErrorsMap.putIfAbsent(platform, () => false);
    _hasOutputMap.putIfAbsent(platform, () => false);
  }

  // Platform-specific getters
  StringBuffer get _outputBuffer {
    _ensurePlatformBuffers(_selectedPlatform);
    return _outputBuffers[_selectedPlatform]!;
  }

  StringBuffer get _errorBuffer {
    _ensurePlatformBuffers(_selectedPlatform);
    return _errorBuffers[_selectedPlatform]!;
  }

  bool get _hasErrors {
    _ensurePlatformBuffers(_selectedPlatform);
    return _hasErrorsMap[_selectedPlatform]!;
  }

  set _hasErrors(bool value) {
    _ensurePlatformBuffers(_selectedPlatform);
    setState(() => _hasErrorsMap[_selectedPlatform] = value);
  }

  bool get _hasOutput {
    _ensurePlatformBuffers(_selectedPlatform);
    return _hasOutputMap[_selectedPlatform]!;
  }

  set _hasOutput(bool value) {
    _ensurePlatformBuffers(_selectedPlatform);
    setState(() => _hasOutputMap[_selectedPlatform] = value);
  }

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

  Widget _buildExecutePanelContent(
    BuildContext context,
    String currentProjectPath,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 16,
      children: [
        // Platform Selection Section
        PlatformSelector(
          supportedPlatforms: _supportedPlatforms,
          selectedPlatform: _selectedPlatform,
          onPlatformSelected: (platform) async {
            await _saveSelectedPlatform(platform);
            setState(() => _selectedPlatform = platform);
          },
        ),

        // Platform Information Section - shows details about selected platform
        PlatformInfoSection(
          selectedPlatform: _selectedPlatform,
          isSupported: _supportedPlatforms.contains(_selectedPlatform),
          canBuild: _canBuildOnCurrentPlatform(_selectedPlatform),
          projectPath: currentProjectPath,
          currentHostPlatform: Platform.operatingSystem,
          onAppendOutput: appendOutput,
          onAppendError: appendError,
        ),

        // Actions Section - actions that can be performed on selected platform
        _buildActionsSection(),

        // Output Section - shows the output of the actions
        _buildOutputSection(),
      ],
    );
  }

  Widget _buildActionsSection() {
    final colorScheme = Theme.of(context).colorScheme;
    final canBuild =
        _supportedPlatforms.contains(_selectedPlatform) &&
        _canBuildOnCurrentPlatform(_selectedPlatform);

    if (!canBuild) {
      // Instructions for unsupported platforms
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: colorScheme.outline.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline, size: 20, color: colorScheme.secondary),
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
      );
    }

    return _buildActionTabsWithDetails();
  }

  Widget _buildActionTabsWithDetails() {
    final colorScheme = Theme.of(context).colorScheme;

    // Prepare actions based on platform
    final actions = <Map<String, dynamic>>[];

    // Clean action - always available
    actions.add({
      'id': 'clean',
      'icon': Icons.cleaning_services_rounded,
      'title': 'Clean',
      'description': 'Clean build artifacts, cache, and temporary files',
      'details': '''
Cleans the Flutter build cache and artifacts.

• Removes build/ directory contents
• Clears pub cache
• Removes platform-specific build outputs
• Prepares for fresh build
      ''',
      'color': colorScheme.secondary,
      'action': _cleanFlutterApp,
      'status': _cleanStatus,
    });

    // Build actions
    if (_selectedPlatform == 'android') {
      actions.add({
        'id': 'build_apk',
        'icon': Icons.phone_android_rounded,
        'title': 'Build APK',
        'description': 'Build Android App Bundle for Play Store',
        'details': '''
Builds an Android app package (APK) for the selected platform.

• Compiles Dart code to native ARM/x86 binaries
• Bundles Flutter engine and assets
• Creates installable .apk file
• Targets debug or release configurations
        ''',
        'color': colorScheme.primary,
        'action': () => _buildFlutterApp('apk'),
        'status': _buildStatus,
      });
      actions.add({
        'id': 'build_aab',
        'icon': Icons.archive_rounded,
        'title': 'Build AAB',
        'description': 'Build Android App Bundle for Play Store',
        'details': '''
Builds an Android App Bundle (AAB) for Google Play Store.

• Contains optimized app binaries for multiple ABIs
• Includes assets and Flutter engine
• Smaller downloads through dynamic feature delivery
• Required format for Play Store submissions
        ''',
        'color': colorScheme.tertiary,
        'action': () => _buildFlutterApp('aab'),
        'status': _buildStatus,
      });
    } else {
      actions.add({
        'id': 'build',
        'icon': Icons.build_rounded,
        'title': 'Build ${getPlatformDisplayName(_selectedPlatform)}',
        'description':
            'Build application for ${getPlatformDisplayName(_selectedPlatform)} platform',
        'details': '''
Builds the Flutter application for the selected platform.

• Compiles Dart code to native platform binaries
• Bundles Flutter engine and platform-specific files
• Creates platform-specific application bundle
• Optimizes for target platform requirements
        ''',
        'color': colorScheme.primary,
        'action': () => _buildFlutterApp(_selectedPlatform),
        'status': _buildStatus,
      });
    }

    // Run actions
    actions.add({
      'id': 'run',
      'icon': Icons.rocket_launch_rounded,
      'title': 'Run Release',
      'description': 'Run application in release mode',
      'details': '''
Runs the Flutter application in release mode.

• Builds and launches the app
• Uses optimized production binaries
• Hot reload disabled for performance
• Designed for production deployment
      ''',
      'color': Colors.green,
      'action': () => _runFlutterApp(isDebug: false),
      'status': _runStatus,
    });

    actions.add({
      'id': 'debug',
      'icon': Icons.bug_report_rounded,
      'title': 'Run Debug',
      'description': 'Run application in debug mode with hot reload',
      'details': '''
Runs the Flutter application in debug mode.

• Enables hot reload for fast development
• Includes debugging tools and assertions
• Allows real-time code modification
• Development and testing mode
      ''',
      'color': Colors.orange,
      'action': () => _runFlutterApp(isDebug: true),
      'status': _debugStatus,
    });

    // CocoaPods actions (separate)
    if (_selectedPlatform == 'ios' && Platform.isMacOS) {
      actions.add({
        'id': 'cocoapods',
        'icon': Icons.developer_mode,
        'title': 'Update iOS Pods',
        'description': 'Update CocoaPods dependencies for iOS',
        'details': '''
Updates iOS CocoaPods dependencies.

• Updates pod repository
• Installs/Updates iOS framework dependencies
• Ensures native iOS code compatibility
• Required before iOS builds
        ''',
        'color': const Color(0xFF007ACC),
        'action': _updateCocoaPods,
        'status': _podStatus,
      });
    } else if (_selectedPlatform == 'macos' && Platform.isMacOS) {
      actions.add({
        'id': 'cocoapods',
        'icon': Icons.developer_mode,
        'title': 'Update macOS Pods',
        'description': 'Update CocoaPods dependencies for macOS',
        'details': '''
Updates macOS CocoaPods dependencies.

• Updates pod repository
• Installs/Updates macOS framework dependencies
• Ensures native macOS code compatibility
• Required before macOS builds
        ''',
        'color': const Color(0xFF007ACC),
        'action': _updateCocoaPods,
        'status': _podStatus,
      });
    }

    return ActionTabsWithExecute(actions: actions);
  }

  Widget _buildOutputSection() {
    final colorScheme = Theme.of(context).colorScheme;

    if (_hasOutput || _hasErrors) {
      return Container(
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
                  color: _hasErrors ? colorScheme.error : colorScheme.primary,
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
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: const Center(
        child: Text(
          'No output yet',
          style: TextStyle(color: Colors.grey, fontSize: 11),
        ),
      ),
    );
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
          // Main Content Area with Platform Selector as Top Section
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: _buildExecutePanelContent(context, currentProjectPath),
          ),
        ],
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
}

class ActionTabsWithExecute extends StatefulWidget {
  final List<Map<String, dynamic>> actions;

  const ActionTabsWithExecute({super.key, required this.actions});

  @override
  State<ActionTabsWithExecute> createState() => _ActionTabsWithExecuteState();
}

class _ActionTabsWithExecuteState extends State<ActionTabsWithExecute>
    with TickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: widget.actions.length, vsync: this);
  }

  @override
  void didUpdateWidget(ActionTabsWithExecute oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.actions.length != widget.actions.length) {
      _tabController.dispose();
      _tabController = TabController(
        length: widget.actions.length,
        vsync: this,
      );
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final showLabels =
            constraints.maxWidth > 240; // Show labels if wider than 240px

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: colorScheme.outline.withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // TabBar with action tabs
              TabBar(
                controller: _tabController,
                tabs: widget.actions.map((action) {
                  final status = action['status'] as BuildProcessStatus;
                  final isRunning = status == BuildProcessStatus.running;
                  final icon = action['icon'] as IconData;

                  return Tab(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isRunning)
                          SizedBox(
                            width: showLabels ? 20 : 24,
                            height: showLabels ? 20 : 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.amber,
                              ),
                            ),
                          )
                        else
                          Icon(
                            status == BuildProcessStatus.success
                                ? Icons.check_circle
                                : status == BuildProcessStatus.error
                                ? Icons.error
                                : icon,
                            size: showLabels ? 20 : 22,
                          ),
                        if (showLabels) ...[
                          const SizedBox(height: 4),
                          Text(
                            action['title'] as String,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ],
                    ),
                  );
                }).toList(),
                labelColor: colorScheme.primary,
                unselectedLabelColor: colorScheme.onSurface.withOpacity(0.6),
                indicatorColor: colorScheme.primary,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                labelPadding: EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: showLabels ? 4 : 8,
                ),
              ),

              const SizedBox(height: 16),

              // Content area showing selected action details
              SizedBox(
                height:
                    220, // Fixed height for content area - increased for no scroll
                child: TabBarView(
                  controller: _tabController,
                  physics: const NeverScrollableScrollPhysics(),
                  children: widget.actions.map((action) {
                    final status = action['status'] as BuildProcessStatus;
                    final isRunning = status == BuildProcessStatus.running;
                    final color = action['color'] as Color;

                    return Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Action title and description
                          Row(
                            children: [
                              Icon(
                                action['icon'] as IconData,
                                size: 24,
                                color: color,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      action['title'] as String,
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: colorScheme.onSurface,
                                      ),
                                    ),
                                    Text(
                                      action['description'] as String,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: colorScheme.onSurface
                                            .withOpacity(0.7),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 12),

                          // Action details - reduced size and made expandable
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: colorScheme.surfaceContainerHighest
                                    .withOpacity(0.3),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: SingleChildScrollView(
                                // Keep only this for the details text
                                child: Text(
                                  action['details'] as String,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: colorScheme.onSurface.withOpacity(
                                      0.8,
                                    ),
                                    height: 1.3,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 12),

                          // Execute button and status in a compact footer
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: isRunning
                                      ? null // Disable when running
                                      : () {
                                          final onPressed =
                                              action['action'] as VoidCallback?;
                                          onPressed?.call();
                                        },
                                  icon: isRunning
                                      ? SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                  Colors.white,
                                                ),
                                          ),
                                        )
                                      : Icon(Icons.play_arrow, size: 18),
                                  label: Text(
                                    isRunning ? 'Running...' : 'Execute',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: isRunning
                                        ? Colors.grey
                                        : color,
                                    foregroundColor: Colors.white,
                                    padding: EdgeInsets.symmetric(vertical: 10),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                              ),

                              // Status message - compact
                              SizedBox(height: 6),
                              if (isRunning)
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.hourglass_top, size: 14),
                                    const SizedBox(width: 6),
                                    Text(
                                      'In progress...',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: colorScheme.onSurface
                                            .withOpacity(0.6),
                                      ),
                                    ),
                                  ],
                                )
                              else if (status == BuildProcessStatus.success)
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.check_circle,
                                      size: 14,
                                      color: Colors.green,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Success',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.green,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                )
                              else if (status == BuildProcessStatus.error)
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.error,
                                      size: 14,
                                      color: Colors.red,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Failed',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.red,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
