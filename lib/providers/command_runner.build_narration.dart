part of 'command_runner.dart';

/// The lines the log shows for what a `FlutterBuildService` command
/// reports beyond its own output: each [BuildStepEvent], and the
/// [BuildException] of a failed step. Every such line is worded here.
abstract final class BuildNarration {
  /// Icon of each `flutter` step's start line.
  static const Map<BuildStep, String> _flutterStepIcons = {
    BuildStep.flutterClean: '🧹',
    BuildStep.pubGet: '📦',
    BuildStep.flutterBuild: '🔨',
  };

  /// How a retried step is named.
  static const Map<BuildStep, String> _retryLabels = {
    BuildStep.flutterBuild: 'Flutter build',
    BuildStep.flutterClean: 'Flutter clean',
  };

  /// Writes [event] to [log]: errors of a failed repair, output otherwise.
  static void log(OutputLog log, BuildStepEvent event) {
    switch ((event.step, event.status)) {
      case (BuildStep.podRepoRepair, BuildStepStatus.needed):
        log.addOutput(
          '🛠️ CocoaPods repository error detected in output line: "${event.detail}"',
        );
      case (BuildStep.podRepoRepair, BuildStepStatus.started):
        log.addOutput(
          '🔧 Detected CocoaPods repository issue. Running pod repo update...',
        );
      case (BuildStep.podRepoRepair, BuildStepStatus.failed):
        log.addError(
          event.detail.isEmpty
              ? '❌ Failed to update CocoaPods repository'
              : '❌ Error running pod repo update: ${event.detail}',
        );
      case (BuildStep.podRepoRepair, BuildStepStatus.succeeded):
        log.addOutput('✅ CocoaPods repository updated successfully');
      case (_, BuildStepStatus.retrying):
        log.addOutput(
          '🔄 Retrying ${_retryLabels[event.step] ?? event.step.name}...',
        );
      case (BuildStep.podRepoUpdate, BuildStepStatus.started):
        log.addOutput('📦 Updating CocoaPods repository...');
      case (BuildStep.podRepoUpdate, BuildStepStatus.failed):
        log.addOutput(
          '⚠️ Pod repo update failed, continuing with pod install...',
        );
      case (BuildStep.podInstall, BuildStepStatus.started):
        log.addOutput('🔧 Running pod install with repo update...');
      case (BuildStep.podInstall, BuildStepStatus.failed):
        log.addOutput(
          '⚠️ Pod install failed with exit code ${event.exitCode}, continuing with Flutter cleanup...',
        );
        log.addOutput('🔄 CocoaPods issues will require manual resolution');
      case (BuildStep.podInstall, BuildStepStatus.succeeded):
        log.addOutput('✅ CocoaPods dependencies updated successfully');
      case (
        BuildStep.flutterClean || BuildStep.pubGet || BuildStep.flutterBuild,
        BuildStepStatus.started,
      ):
        log.addOutput(
          '${_flutterStepIcons[event.step]} Running flutter ${event.detail}...',
        );
      case (BuildStep.deepClean, BuildStepStatus.succeeded):
        log.addOutput('✨ Deep clean and rebuild completed successfully!');
      case _:
        log.addOutput('${event.step.name}: ${event.status.name}');
    }
  }

  /// The failed `flutter` step of [failure], as the log reports it.
  static String failed(BuildException failure) =>
      'Flutter ${failure.arguments} failed with exit code ${failure.exitCode}';
}
