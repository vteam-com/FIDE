// ignore_for_file: deprecated_member_use

import 'dart:io';

import 'package:fide/constants/constants.dart';
import 'package:fide/models/flutter_platform.dart';
import 'package:fide/models/output_log.dart';
import 'package:fide/models/panel_action.dart';
import 'package:fide/panels/left/command_actions.dart';
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

class _ExecutePanelState extends ConsumerState<ExecutePanel>
    with CommandActions {
  late final FlutterBuildService _buildService = ref.read(
    flutterBuildServiceProvider,
  );
  // One log per platform so switching targets keeps each one's output
  final Map<FlutterPlatform, OutputLog> _logs = {};
  Set<FlutterPlatform> _supportedPlatforms = {};

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

  @override
  OutputLog get actionLog => _log;

  /// The chosen build target; `build` watches it so changes rebuild.
  FlutterPlatform get _selectedPlatform => ref.read(selectedPlatformProvider);

  /// Output log of the selected platform.
  OutputLog get _log => _logs.putIfAbsent(_selectedPlatform, OutputLog.new);

  /// Output sink that writes command output into the selected platform's
  /// log and tracks the processes action [id] starts.
  BuildOutput _buildOutputFor(String id) => BuildOutput(
    onOutput: (text) => setState(() {
      _log.addOutput(text);
    }),
    onError: (text) => setState(() {
      _log.addError(text);
    }),
    onResetErrors: () => setState(_log.clearErrors),
    onProcessStarted: (process) => trackProcess(id, process),
  );

  /// Runs `pod install --repo-update` for the selected Apple platform.
  Future<void> _updateCocoaPods(String id) => _runProjectAction(
    id,
    startMessages: [
      '📦 Updating CocoaPods dependencies...',
      'Running pod install --repo-update',
    ],
    // Only offered for CocoaPods platforms, whose folder holds the Podfile
    command: (projectPath) => _buildService.podInstall(
      '$projectPath/${_selectedPlatform.name}',
      _buildOutputFor(id),
    ),
    successMessage: '✅ CocoaPods update completed successfully',
    failureMessage: (exitCode) =>
        '❌ CocoaPods update failed with exit code $exitCode',
    errorPrefix: '❌ CocoaPods error: ',
  );

  /// Runs action [id] against the loaded project; does nothing when no
  /// project is loaded. See [runCommandAction].
  Future<void> _runProjectAction(
    String id, {
    required List<String> startMessages,
    required Future<int> Function(String) command,
    required String successMessage,
    required String Function(int) failureMessage,
    required String errorPrefix,
    bool resetWhenDone = true,
  }) async {
    final projectPath = ref.read(currentProjectPathProvider);
    if (projectPath == null) return;
    await runCommandAction(
      id,
      startMessages: startMessages,
      command: () => command(projectPath),
      successMessage: successMessage,
      failureMessage: failureMessage,
      errorPrefix: errorPrefix,
      resetWhenDone: resetWhenDone,
    );
  }

  /// Why the selected platform can't be built here, or how to add it.
  String _getPlatformInstructions(FlutterPlatform platform) {
    if (!_supportedPlatforms.contains(platform)) {
      return platform.enableInstructions;
    }
    if (!platform.canBuildOnHost) {
      return platform.cannotBuildOn(Platform.operatingSystem);
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
          canBuild: _selectedPlatform.canBuildOnHost,
          projectPath: currentProjectPath,
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
        _selectedPlatform.canBuildOnHost;

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

  /// Action [id] with its current status and a Stop for its process.
  PanelAction _action(
    String id, {
    required IconData icon,
    required String title,
    required String description,
    required String details,
    required Color color,
    required VoidCallback onRun,
  }) {
    return PanelAction(
      id: id,
      title: title,
      description: description,
      details: details,
      icon: icon,
      color: color,
      onRun: onRun,
      onStop: () => stopAction(id),
      status: statusOf(id),
    );
  }

  /// The actions offered for the selected platform.
  Widget _buildActionTabsWithDetails() {
    final colorScheme = Theme.of(context).colorScheme;
    final platform = _selectedPlatform;

    final actions = <PanelAction>[
      _action(
        'clean',
        icon: Icons.cleaning_services_rounded,
        title: 'Clean',
        description: 'Clean build artifacts, cache, and temporary files',
        details: '''
Cleans the Flutter build cache and artifacts.

• Removes build/ directory contents
• Clears pub cache
• Removes platform-specific build outputs
• Prepares for fresh build
      ''',
        color: colorScheme.primary,
        onRun: _cleanFlutterApp,
      ),
      if (platform == FlutterPlatform.android) ...[
        _action(
          'build_apk',
          icon: Icons.phone_android_rounded,
          title: 'Build APK',
          description: 'Build an installable Android package (APK)',
          details: '''
Builds an Android app package (APK) for the selected platform.

• Compiles Dart code to native ARM/x86 binaries
• Bundles Flutter engine and assets
• Creates installable .apk file
• Targets debug or release configurations
        ''',
          color: colorScheme.primary,
          onRun: () => _buildFlutterApp('build_apk', 'apk'),
        ),
        _action(
          'build_aab',
          icon: Icons.archive_rounded,
          title: 'Build AAB',
          description: 'Build Android App Bundle for Play Store',
          details: '''
Builds an Android App Bundle (AAB) for Google Play Store.

• Contains optimized app binaries for multiple ABIs
• Includes assets and Flutter engine
• Smaller downloads through dynamic feature delivery
• Required format for Play Store submissions
        ''',
          color: colorScheme.primary,
          onRun: () => _buildFlutterApp('build_aab', 'aab'),
        ),
      ] else
        _action(
          'build',
          icon: Icons.build_rounded,
          title: 'Build ${platform.displayName}',
          description: 'Build application for ${platform.displayName} platform',
          details: '''
Builds the Flutter application for the selected platform.

• Compiles Dart code to native platform binaries
• Bundles Flutter engine and platform-specific files
• Creates platform-specific application bundle
• Optimizes for target platform requirements
        ''',
          color: colorScheme.primary,
          onRun: () => _buildFlutterApp('build', platform.name),
        ),
      _action(
        'run',
        icon: Icons.rocket_launch_rounded,
        title: 'Run Release',
        description: 'Run application in release mode',
        details: '''
Runs the Flutter application in release mode.

• Builds and launches the app
• Uses optimized production binaries
• Hot reload disabled for performance
• Designed for production deployment
      ''',
        color: colorScheme.primary,
        onRun: () => _runFlutterApp('run', isDebug: false),
      ),
      _action(
        'debug',
        icon: Icons.bug_report_rounded,
        title: 'Run Debug',
        description: 'Run application in debug mode with hot reload',
        details: '''
Runs the Flutter application in debug mode.

• Enables hot reload for fast development
• Includes debugging tools and assertions
• Allows real-time code modification
• Development and testing mode
      ''',
        color: colorScheme.primary,
        onRun: () => _runFlutterApp('debug', isDebug: true),
      ),
      if (platform.usesCocoaPods && Platform.isMacOS)
        _action(
          'cocoapods',
          icon: Icons.developer_mode,
          title: 'Update ${platform.displayName} Pods',
          description:
              'Update CocoaPods dependencies for ${platform.displayName}',
          details:
              '''
Updates ${platform.displayName} CocoaPods dependencies.

• Updates pod repository
• Installs/Updates ${platform.displayName} framework dependencies
• Ensures native ${platform.displayName} code compatibility
• Required before ${platform.displayName} builds
        ''',
          color: colorScheme.primary,
          onRun: () => _updateCocoaPods('cocoapods'),
        ),
    ];

    // Run Debug is what this tab is opened for nearly every time.
    return ActionTabsWithExecute(actions: actions, initialId: 'debug');
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
    final shouldDoDeepClean =
        Platform.isMacOS &&
        _selectedPlatform == FlutterPlatform.macos &&
        _supportedPlatforms.contains(FlutterPlatform.macos);
    const id = 'clean';

    return _runProjectAction(
      id,
      startMessages: shouldDoDeepClean
          ? [
              '🧹 Performing deep clean for macOS project...',
              '📦 This will update CocoaPods and rebuild dependencies',
            ]
          : ['🧹 Cleaning Flutter project...'],
      // Clean steps throw on failure, so reaching the end means success
      command: (projectPath) async {
        if (shouldDoDeepClean) {
          await _buildService.deepCleanMacOS(projectPath, _buildOutputFor(id));
        } else {
          await _buildService.clean(projectPath, _buildOutputFor(id));
        }
        return 0;
      },
      successMessage: '✓ Project cleaned successfully',
      failureMessage: (exitCode) => '✗ Clean failed with exit code $exitCode',
      errorPrefix: '✗ Clean error: ',
    );
  }

  /// Builds the app for [target] (a platform id, `apk` or `aab`) as
  /// action [id].
  Future<void> _buildFlutterApp(String id, String target) => _runProjectAction(
    id,
    startMessages: ['Building for $target...'],
    command: (projectPath) =>
        _buildService.build(projectPath, target, _buildOutputFor(id)),
    successMessage: '✓ Build completed successfully for $target',
    failureMessage: (exitCode) => '✗ Build failed with exit code $exitCode',
    errorPrefix: '✗ Build error: ',
  );

  /// Runs the app on the selected platform in debug or release mode as
  /// action [id].
  Future<void> _runFlutterApp(
    String id, {
    required bool isDebug,
  }) => _runProjectAction(
    id,
    startMessages: ['${isDebug ? 'Debugging' : 'Running'} Flutter app...'],
    // Process runs continuously until stopped
    command: (projectPath) => _buildService.run(
      projectPath,
      _selectedPlatform.deviceTarget,
      _buildOutputFor(id),
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
}
