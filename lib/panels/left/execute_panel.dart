import 'package:fide/models/flutter_platform.dart';
import 'package:fide/models/status_tone.dart';
import 'package:fide/providers/app_providers.dart';
import 'package:fide/providers/command_runner.dart';
import 'package:fide/providers/service_providers.dart';
import 'package:fide/services/flutter_build_service.dart';
import 'package:fide/widgets/command_action_list.dart';
import 'package:fide/widgets/command_output.dart';
import 'package:fide/widgets/no_project_placeholder.dart';
import 'package:fide/widgets/outlined_surface.dart';
import 'package:fide/widgets/panel_action.dart';
import 'package:fide/widgets/panel_scroll_view.dart';
import 'package:fide/widgets/platform_info_section.dart';
import 'package:fide/widgets/platform_selector.dart';
import 'package:fide/widgets/status_indicator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Panel providing one-click build, run, and clean actions for the loaded
/// Flutter project. The runs belong to [commandRunnerProvider], so they
/// keep going while the panel is hidden.
class ExecutePanel extends ConsumerStatefulWidget {
  /// Creates the panel.
  const ExecutePanel({super.key});

  @override
  ConsumerState<ExecutePanel> createState() => _ExecutePanelState();
}

class _ExecutePanelState extends ConsumerState<ExecutePanel> {
  /// Prefix of each platform's log key: every platform keeps its own
  /// output.
  static const String _logKeyPrefix = 'execute_';

  @override
  void initState() {
    super.initState();
    ref.read(selectedPlatformProvider.notifier).load();
  }

  FlutterBuildService get _buildService =>
      ref.read(flutterBuildServiceProvider);

  @override
  Widget build(BuildContext context) {
    final currentProjectPath = ref.watch(currentProjectPathProvider);
    final platform = ref.watch(selectedPlatformProvider);

    if (currentProjectPath == null) {
      return const NoProjectPlaceholder();
    }

    final supportedPlatforms = ref
        .watch(projectConfigReaderProvider)
        .platforms(currentProjectPath);
    final isSupported = supportedPlatforms.contains(platform);
    final host = ref.watch(hostPlatformProvider);
    final canBuild = platform.canBuildOn(host);

    return PanelScrollView(
      children: [
        PlatformSelector(
          supportedPlatforms: supportedPlatforms,
          selectedPlatform: platform,
          onPlatformSelected: ref
              .read(selectedPlatformProvider.notifier)
              .select,
        ),
        PlatformInfoSection(
          selectedPlatform: platform,
          isSupported: isSupported,
          canBuild: canBuild,
          projectPath: currentProjectPath,
        ),
        if (isSupported && canBuild)
          CommandActionList(actions: _actionsFor(platform))
        else
          OutlinedSurface(
            child: StatusIndicator.tone(
              StatusTone.info,
              label: isSupported
                  ? platform.cannotBuildOn(host)
                  : platform.enableInstructions,
            ),
          ),
        CommandOutput(logKey: _logKeyOf(platform)),
      ],
    );
  }

  /// The actions offered for [platform].
  List<PanelAction> _actionsFor(FlutterPlatform platform) => [
    PanelAction(
      id: 'clean',
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
      onRun: () => _clean(platform),
    ),
    for (final build in platform.buildActions)
      PanelAction(
        id: build.id,
        icon: build.icon,
        title: build.title,
        description: build.description,
        details: build.details,
        onRun: () => _build(build.id, platform, target: build.target),
      ),
    PanelAction(
      id: 'run',
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
      onRun: () => _runApp('run', platform, isDebug: false),
    ),
    PanelAction(
      id: 'debug',
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
      onRun: () => _runApp('debug', platform, isDebug: true),
    ),
    if (platform.usesCocoaPods)
      PanelAction(
        id: 'cocoapods',
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
        onRun: () => _updateCocoaPods('cocoapods', platform),
      ),
  ];

  /// Builds [platform] as [target] (its default when null) as action [id].
  Future<void> _build(String id, FlutterPlatform platform, {String? target}) {
    final label = target ?? platform.buildTargets.first;
    return _runProjectAction(
      id,
      platform,
      startMessages: ['Building for $label...'],
      command: (projectPath, output) =>
          _buildService.build(projectPath, platform, output, target: target),
      successMessage: '✓ Build completed successfully for $label',
      failureMessage: (exitCode) => '✗ Build failed with exit code $exitCode',
      errorPrefix: '✗ Build error: ',
    );
  }

  /// Cleans the project; CocoaPods platforms get a deep clean that also
  /// refreshes their pods and rebuilds. The panel only offers it for
  /// platforms the project has and the host can build.
  Future<void> _clean(FlutterPlatform platform) {
    final deep = platform.usesCocoaPods;
    return _runProjectAction(
      'clean',
      platform,
      startMessages: deep
          ? [
              '🧹 Performing deep clean for ${platform.displayName} project...',
              '📦 This will update CocoaPods and rebuild dependencies',
            ]
          : ['🧹 Cleaning Flutter project...'],
      // Clean steps throw on failure, so reaching the end means success
      command: (projectPath, output) async {
        if (deep) {
          await _buildService.deepClean(projectPath, platform, output);
        } else {
          await _buildService.clean(projectPath, output);
        }
        return 0;
      },
      successMessage: '✓ Project cleaned successfully',
      failureMessage: (exitCode) => '✗ Clean failed with exit code $exitCode',
      errorPrefix: '✗ Clean error: ',
    );
  }

  /// Key of the log of [platform]'s actions.
  String _logKeyOf(FlutterPlatform platform) =>
      '$_logKeyPrefix${platform.name}';

  /// Runs the app on [platform] in debug or release mode as action [id].
  Future<void> _runApp(
    String id,
    FlutterPlatform platform, {
    required bool isDebug,
  }) => _runProjectAction(
    id,
    platform,
    startMessages: ['${isDebug ? 'Debugging' : 'Running'} Flutter app...'],
    // Process runs continuously until stopped
    command: (projectPath, output) => _buildService.run(
      projectPath,
      platform.deviceTarget,
      output,
      isDebug: isDebug,
    ),
    successMessage: '✓ App ${isDebug ? 'debugged' : 'ran'} successfully',
    failureMessage: (exitCode) =>
        '✗ App ${isDebug ? 'debug' : 'run'} failed with exit code $exitCode',
    errorPrefix: '✗ Run error: ',
    resetWhenDone: false,
    isLive: FlutterBuildService.isAppLaunched,
  );

  /// Runs action [id] of [platform] against the loaded project, into the
  /// platform's log; does nothing when no project is loaded. Its errors
  /// feed the AI's Fix Build. See [CommandRunner.run].
  Future<void> _runProjectAction(
    String id,
    FlutterPlatform platform, {
    required List<String> startMessages,
    required Future<int> Function(String projectPath, BuildOutput output)
    command,
    required String successMessage,
    required String Function(int) failureMessage,
    required String errorPrefix,
    bool resetWhenDone = true,
    bool Function(String output)? isLive,
  }) async {
    final projectPath = ref.read(currentProjectPathProvider);
    if (projectPath == null) return;
    await ref
        .read(commandRunnerProvider.notifier)
        .run(
          id,
          logKey: _logKeyOf(platform),
          startMessages: startMessages,
          command: (output) => command(projectPath, output),
          successMessage: successMessage,
          failureMessage: failureMessage,
          errorPrefix: errorPrefix,
          resetWhenDone: resetWhenDone,
          reportsBuildErrors: true,
          isLive: isLive,
        );
  }

  /// Runs `pod install --repo-update` for [platform], one that uses
  /// CocoaPods, as action [id].
  Future<void> _updateCocoaPods(String id, FlutterPlatform platform) =>
      _runProjectAction(
        id,
        platform,
        startMessages: [
          '📦 Updating CocoaPods dependencies...',
          'Running pod install --repo-update',
        ],
        // The platform folder holds the Podfile
        command: (projectPath, output) =>
            _buildService.podInstall('$projectPath/${platform.name}', output),
        successMessage: '✅ CocoaPods update completed successfully',
        failureMessage: (exitCode) =>
            '❌ CocoaPods update failed with exit code $exitCode',
        errorPrefix: '❌ CocoaPods error: ',
      );
}
