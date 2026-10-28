// ignore_for_file: deprecated_member_use

import 'dart:io';

import 'package:fide/constants/constants.dart';
import 'package:fide/models/flutter_platform.dart';
import 'package:fide/models/output_log.dart';
import 'package:fide/providers/app_providers.dart';
import 'package:fide/providers/flutter_build_service.dart';
import 'package:fide/providers/service_providers.dart';
import 'package:fide/widgets/action_tabs.dart';
import 'package:fide/widgets/output_panel.dart';
import 'package:fide/widgets/platform_info_section.dart';
import 'package:fide/widgets/platform_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Panel providing one-click build, run, and clean actions for the loaded Flutter project.
class ExecutePanel extends ConsumerStatefulWidget {
  const ExecutePanel({super.key});

  @override
  ConsumerState<ExecutePanel> createState() => _ExecutePanelState();
}

class _ExecutePanelState extends ConsumerState<ExecutePanel> {
  BuildProcessStatus _cleanStatus = BuildProcessStatus.idle;
  BuildProcessStatus _buildStatus = BuildProcessStatus.idle;
  BuildProcessStatus _runStatus = BuildProcessStatus.idle;
  BuildProcessStatus _debugStatus = BuildProcessStatus.idle;
  BuildProcessStatus _podStatus = BuildProcessStatus.idle;

  late final FlutterBuildService _buildService = ref.read(
    flutterBuildServiceProvider,
  );
  Process? _currentProcess;
  // One log per platform so switching targets keeps each one's output
  final Map<String, OutputLog> _logs = {};
  Set<String> _supportedPlatforms = {};

  @override
  void initState() {
    super.initState();
    ref.read(selectedPlatformProvider.notifier).load();
  }

  /// Ignores state updates once the panel is gone.
  ///
  /// Build, clean, and pod processes keep reporting output and completion
  /// after awaits, often after the panel has been disposed.
  @override
  void setState(VoidCallback fn) {
    if (!mounted) return;
    super.setState(fn);
  }

  /// The chosen build target; `build` watches it so changes rebuild.
  String get _selectedPlatform => ref.read(selectedPlatformProvider);

  /// Output log of the selected platform.
  OutputLog get _log => _logs.putIfAbsent(_selectedPlatform, OutputLog.new);

  /// Output sink that writes command output into the selected platform's log.
  BuildOutput get _buildOutput => BuildOutput(
    onOutput: (text) => setState(() {
      _log.addOutput(text);
    }),
    onError: (text) => setState(() {
      _log.addError(text);
    }),
    onResetErrors: () => setState(_log.clearErrors),
    onProcessStarted: (process) => _currentProcess = process,
  );

  /// Returns a finished action's status indicator to idle after a pause.
  void _resetStatusLater(void Function() resetStatus) {
    Future.delayed(AppDuration.buildStatusResetDelay, () {
      setState(resetStatus);
    });
  }

  /// Runs `pod install --repo-update` for the selected Apple platform.
  Future<void> _updateCocoaPods() => _runAction(
    setStatus: (status) => _podStatus = status,
    startMessages: [
      '📦 Updating CocoaPods dependencies...',
      'Running pod install --repo-update',
    ],
    // Only offered for CocoaPods platforms, whose folder holds the Podfile
    command: (projectPath) => _buildService.podInstall(
      '$projectPath/$_selectedPlatform',
      _buildOutput,
    ),
    successMessage: '✅ CocoaPods update completed successfully',
    failureMessage: (exitCode) =>
        '❌ CocoaPods update failed with exit code $exitCode',
    errorPrefix: '❌ CocoaPods error: ',
  );

  /// Runs one command-backed action for the loaded project: clears the log,
  /// marks the action running with [startMessages], then records success or
  /// failure from the exit code [command] returns or the error it throws.
  ///
  /// The status returns to idle after a pause, except for app runs
  /// ([resetWhenDone] false), whose final state stays visible.
  Future<void> _runAction({
    required void Function(BuildProcessStatus) setStatus,
    required List<String> startMessages,
    required Future<int> Function(String) command,
    required String successMessage,
    required String Function(int) failureMessage,
    required String errorPrefix,
    bool resetWhenDone = true,
  }) async {
    final projectPath = ref.read(currentProjectPathProvider);
    if (projectPath == null) return;

    _clearOutput();
    setState(() {
      setStatus(BuildProcessStatus.running);
      startMessages.forEach(_log.addOutput);
    });

    try {
      final exitCode = await command(projectPath);
      setState(() {
        if (exitCode == 0) {
          setStatus(BuildProcessStatus.success);
          _log.addOutput(successMessage);
        } else {
          setStatus(BuildProcessStatus.error);
          _log.addError(failureMessage(exitCode));
        }
      });
    } catch (e) {
      setState(() {
        setStatus(BuildProcessStatus.error);
        _log.addError('$errorPrefix$e');
      });
    } finally {
      _currentProcess = null;
      if (resetWhenDone) {
        _resetStatusLater(() => setStatus(BuildProcessStatus.idle));
      }
    }
  }

  @override
  void dispose() {
    _currentProcess?.kill();
    super.dispose();
  }

  /// Whether the host OS can build [platform].
  bool _canBuildOnCurrentPlatform(String platform) {
    return FlutterPlatform.fromId(platform)?.canBuildOnHost ?? false;
  }

  /// Handles `_getPlatformInstructions`.
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

  /// Handles `_buildExecutePanelContent`.
  Widget _buildExecutePanelContent(String currentProjectPath) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: AppSpacing.xLarge,
      children: [
        // Platform Selection Section
        PlatformSelector(
          supportedPlatforms: _supportedPlatforms,
          selectedPlatform: _selectedPlatform,
          onPlatformSelected: ref
              .read(selectedPlatformProvider.notifier)
              .select,
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
        /// Handles `_buildActionsSection`.
        _buildActionsSection(),

        // Output Section - shows the output of the actions
        /// Handles `_buildOutputSection`.
        _buildOutputSection(),
      ],
    );
  }

  /// Handles `_buildActionsSection`.
  Widget _buildActionsSection() {
    final colorScheme = Theme.of(context).colorScheme;
    final canBuild =
        _supportedPlatforms.contains(_selectedPlatform) &&
        _canBuildOnCurrentPlatform(_selectedPlatform);

    if (!canBuild) {
      // Instructions for unsupported platforms
      return Container(
        padding: const EdgeInsets.all(AppSpacing.large),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(AppRadius.medium),
          border: Border.all(
            color: colorScheme.outline.withValues(alpha: AppOpacity.divider),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.info_outline,
              size: AppIconSize.large,
              color: colorScheme.secondary,
            ),
            const SizedBox(width: AppSpacing.large),
            Expanded(
              child: Text(
                _getPlatformInstructions(_selectedPlatform),
                style: TextStyle(
                  fontSize: AppFontSize.caption,
                  color: colorScheme.onSurface,
                  height: AppLineHeight.relaxed,
                ),
              ),
            ),
          ],
        ),
      );
    }

    /// Handles `_buildActionTabsWithDetails`.
    return _buildActionTabsWithDetails();
  }

  /// Handles `_buildActionTabsWithDetails`.
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
        'color': AppColor.nativeDependencyAccent,
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
        'color': AppColor.nativeDependencyAccent,
        'action': _updateCocoaPods,
        'status': _podStatus,
      });
    }

    return ActionTabsWithExecute(actions: actions);
  }

  /// Handles `_buildOutputSection`.
  Widget _buildOutputSection() {
    if (_log.hasOutput || _log.hasErrors) {
      return OutputPanel(
        title: 'Output',
        isExpanded: true,
        text:
            '═══════ Errors ═══════\n${_log.errors}═══════ Error End ═══════\n'
            '═══════ Output ═══════\n${_log.output}═══════ Output End ═══════',
        onClear: _clearOutput,
      );
    }
    return SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    final currentProjectPath = ref.watch(currentProjectPathProvider);
    ref.watch(selectedPlatformProvider);

    if (currentProjectPath == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.build_circle_outlined,
              size: AppIconSize.emptyState,
              color: Theme.of(context).colorScheme.onSurface
                  .withValues(alpha: AppOpacity.divider),
            ),
            const SizedBox(height: AppSpacing.xLarge),
            Text(
              'Load a project to use\nBuild/Run/Debug features',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface
                    .withValues(alpha: AppOpacity.secondaryText),
                fontSize: AppFontSize.label,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    _supportedPlatforms = FlutterPlatform.configuredIn(currentProjectPath);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Main Content Area with Platform Selector as Top Section
          Padding(
            padding: const EdgeInsets.all(AppSpacing.medium),
            child: _buildExecutePanelContent(currentProjectPath),
          ),
        ],
      ),
    );
  }

  /// Cleans the project; macOS targets on a Mac get a deep clean that also
  /// refreshes CocoaPods and rebuilds.
  Future<void> _cleanFlutterApp() {
    final projectPath = ref.read(currentProjectPathProvider);
    final shouldDoDeepClean =
        Platform.isMacOS &&
        _selectedPlatform == FlutterPlatform.macos.name &&
        projectPath != null &&
        Directory('$projectPath/macos').existsSync();

    return _runAction(
      setStatus: (status) => _cleanStatus = status,
      startMessages: shouldDoDeepClean
          ? [
              '🧹 Performing deep clean for macOS project...',
              '📦 This will update CocoaPods and rebuild dependencies',
            ]
          : ['🧹 Cleaning Flutter project...'],
      // Clean steps throw on failure, so reaching the end means success
      command: (projectPath) async {
        if (shouldDoDeepClean) {
          await _buildService.deepCleanMacOS(projectPath, _buildOutput);
        } else {
          await _buildService.clean(projectPath, _buildOutput);
        }
        return 0;
      },
      successMessage: '✓ Project cleaned successfully',
      failureMessage: (exitCode) => '✗ Clean failed with exit code $exitCode',
      errorPrefix: '✗ Clean error: ',
    );
  }

  /// Builds the app for [target] (a platform id, `apk` or `aab`).
  Future<void> _buildFlutterApp(String target) => _runAction(
    setStatus: (status) => _buildStatus = status,
    startMessages: ['Building for $target...'],
    command: (projectPath) =>
        _buildService.build(projectPath, target, _buildOutput),
    successMessage: '✓ Build completed successfully for $target',
    failureMessage: (exitCode) => '✗ Build failed with exit code $exitCode',
    errorPrefix: '✗ Build error: ',
  );

  /// Device id for `flutter run -d` when targeting [platform].
  String _getDeviceTarget(String platform) {
    return FlutterPlatform.fromId(platform)?.deviceTarget ?? platform;
  }

  /// Runs the app on the selected platform in debug or release mode.
  Future<void> _runFlutterApp({required bool isDebug}) => _runAction(
    setStatus: isDebug
        ? (status) => _debugStatus = status
        : (status) => _runStatus = status,
    startMessages: ['${isDebug ? 'Debugging' : 'Running'} Flutter app...'],
    // Process runs continuously until stopped
    command: (projectPath) => _buildService.run(
      projectPath,
      _getDeviceTarget(_selectedPlatform),
      _buildOutput,
      isDebug: isDebug,
    ),
    successMessage: '✓ App ${isDebug ? 'debugged' : 'ran'} successfully',
    failureMessage: (exitCode) =>
        '✗ App ${isDebug ? 'debug' : 'run'} failed with exit code $exitCode',
    errorPrefix: '✗ Run error: ',
    resetWhenDone: false,
  );

  void _clearOutput() => setState(_log.clear);

  /// Handles `_ExecutePanelState.appendOutput`.
  void appendOutput(String text) => setState(() => _log.writeOutput(text));

  /// Handles `_ExecutePanelState.appendError`.
  void appendError(String text) => setState(() => _log.writeError(text));

  /// Human-readable name for [platform].
  String getPlatformDisplayName(String platform) {
    return FlutterPlatform.fromId(platform)?.displayName ?? platform;
  }
}
