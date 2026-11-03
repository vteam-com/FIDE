/// A step a `FlutterBuildService` command runs, beyond the command's own
/// output: the panels word each one for the log.
enum BuildStep {
  /// `pod repo update` run by a deep clean.
  podRepoUpdate,

  /// `pod repo update` run to repair a build that failed on a stale
  /// CocoaPods repo, before retrying it.
  podRepoRepair,

  /// `pod install --repo-update`.
  podInstall,

  /// `flutter clean`.
  flutterClean,

  /// `flutter pub get`.
  pubGet,

  /// `flutter build <target>`.
  flutterBuild,

  /// The whole deep clean: pods, clean, pub get and build.
  deepClean,
}

/// Where a [BuildStep] stands.
enum BuildStepStatus {
  /// The step is called for, e.g. a repair after an error was detected.
  needed,

  /// The step started.
  started,

  /// The step is run again after a repair.
  retrying,

  /// The step finished successfully.
  succeeded,

  /// The step failed; [BuildStepEvent.exitCode] tells how when it ran.
  failed,
}

/// A change in a [BuildStep]'s [BuildStepStatus], as a `FlutterBuildService`
/// reports it.
class BuildStepEvent {
  /// The step reported.
  final BuildStep step;

  /// Where the step stands.
  final BuildStepStatus status;

  /// The exit code of a failed step; null when it didn't run.
  final int? exitCode;

  /// What goes with the event: the `flutter` arguments of a started step,
  /// the output line that called for a repair, or the error of a failed
  /// one; empty when there is nothing.
  final String detail;

  /// Creates an event of [step] at [status].
  const BuildStepEvent(
    this.step,
    this.status, {
    this.exitCode,
    this.detail = '',
  });

  @override
  String toString() =>
      'BuildStepEvent(${step.name}, ${status.name}, $exitCode, "$detail")';
}
