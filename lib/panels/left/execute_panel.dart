import 'package:fide/models/flutter_platform.dart';
import 'package:fide/models/hot_reload.dart';
import 'package:fide/models/status_tone.dart';
import 'package:fide/panels/left/packages_section.dart';
import 'package:fide/panels/left/platform_info_section.dart';
import 'package:fide/providers/app_providers.dart';
import 'package:fide/providers/command_runner.dart';
import 'package:fide/providers/service_providers.dart';
import 'package:fide/services/flutter_build_service.dart';
import 'package:fide/widget_services/command_action_list.dart';
import 'package:fide/widget_services/command_output.dart';
import 'package:fide/widgets/no_project_placeholder.dart';
import 'package:fide/widgets/outlined_surface.dart';
import 'package:fide/widgets/panel_action.dart';
import 'package:fide/widgets/panel_scroll_view.dart';
import 'package:fide/widgets/platform_selector.dart';
import 'package:fide/widgets/status_indicator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// Panel providing one-click build, run, and clean actions for the loaded
/// Flutter project, then its packages. The runs belong to
/// [commandRunnerProvider], so they keep going while the panel is hidden.
class ExecutePanel extends ConsumerStatefulWidget {
  /// Id of the action cleaning the project.
  static const String _cleanId = 'clean';

  /// Id of the action running the app in release mode.
  static const String _runId = 'run';

  /// Id of the action running the app in debug mode.
  static const String _debugId = 'debug';

  /// Every action of the panel, for any platform.
  static final Set<String> actionIds = {
    _cleanId,
    for (final platform in FlutterPlatform.values)
      for (final build in platform.buildActions) build.id,
    _runId,
    _debugId,
  };

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
        const PackagesSection(),
      ],
    );
  }

  /// The actions offered for [platform].
  List<PanelAction> _actionsFor(FlutterPlatform platform) => [
    PanelAction(
      id: ExecutePanel._cleanId,
      icon: Icons.cleaning_services_rounded,
      title: 'Clean',
      description: 'Remove build outputs and generated files',
      details: '''
Runs flutter clean.

• Deletes the build/ and .dart_tool/ folders
• Removes generated platform files, such as plugin registrants
• The next build starts from scratch
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
      id: ExecutePanel._runId,
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
      onRun: () => _runApp(ExecutePanel._runId, platform, isDebug: false),
    ),
    PanelAction(
      id: ExecutePanel._debugId,
      icon: Icons.bug_report_rounded,
      title: 'Run Debug',
      description: 'Run application in debug mode with hot reload',
      details: '''
Runs the Flutter application in debug mode.

• Each save hot reloads the running app, keeping its state; a change hot reload can't apply restarts it
• Hot Reload and Hot Restart beside Stop, or in the Run menu, apply the saved code at once
• Includes debugging tools and assertions
      ''',
      onRun: () => _runApp(ExecutePanel._debugId, platform, isDebug: true),
      liveControls: [
        for (final kind in HotReload.values)
          LiveControl(
            icon: kind.icon,
            tooltip: kind.tooltip,
            status: kind.status,
            onRun: () => ref
                .read(commandRunnerProvider.notifier)
                .reloadApp(ExecutePanel._debugId, kind),
          ),
      ],
    ),
  ];

  /// Builds [platform] as [target] (its default when null) as action [id].
  Future<void> _build(String id, FlutterPlatform platform, {String? target}) {
    final label = target ?? platform.buildTargets.first;
    return _runProjectAction(
      id,
      platform,
      startMessages: ['Building for $label…'],
      command: (projectPath, output) =>
          _buildService.build(projectPath, platform, output, target: target),
      successMessage: 'Build completed successfully for $label',
      failureMessage: (exitCode) => 'Build failed with exit code $exitCode',
      errorPrefix: 'Build error: ',
    );
  }

  /// Cleans the project. The panel only offers it for platforms the
  /// project has and the host can build.
  Future<void> _clean(FlutterPlatform platform) => _runProjectAction(
    ExecutePanel._cleanId,
    platform,
    startMessages: ['Cleaning Flutter project…'],
    // A failed clean throws, so reaching the end means success
    command: (projectPath, output) async {
      await _buildService.clean(projectPath, output);
      return 0;
    },
    successMessage: 'Project cleaned successfully',
    failureMessage: (exitCode) => 'Clean failed with exit code $exitCode',
    errorPrefix: 'Clean error: ',
  );

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
    startMessages: ['${isDebug ? 'Debugging' : 'Running'} Flutter app…'],
    // Process runs continuously until stopped
    command: (projectPath, output) => _buildService.run(
      projectPath,
      platform.deviceTarget,
      output,
      isDebug: isDebug,
    ),
    successMessage: 'App ${isDebug ? 'debugged' : 'ran'} successfully',
    failureMessage: (exitCode) =>
        'App ${isDebug ? 'debug' : 'run'} failed with exit code $exitCode',
    errorPrefix: 'Run error: ',
    resetWhenDone: false,
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
        );
  }
}
