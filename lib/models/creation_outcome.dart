import 'package:fide/models/loading_action.dart';

/// How a [CreationStep] ended; the new-project wizard words each one.
enum CreationOutcome {
  /// The settings and tools are in place.
  validated,

  /// `flutter create` succeeded.
  flutterCreated,

  /// No localization was asked for.
  localizationSkipped,

  /// Localization and the chosen languages are set up.
  localized,

  /// AI generation wasn't asked for: the template's files stay.
  aiNotUsed,

  /// The AI wrote the starter files.
  aiGenerated,

  /// The AI service failed; [CreationReport.detail] says how.
  aiFailed,

  /// The AI took too long.
  aiTimedOut,

  /// AI generation failed for another reason: the template's files stay.
  aiFailedUsingDefaults,

  /// No repository was asked for.
  gitSkipped,

  /// The repository holds its first commit.
  gitInitialized,

  /// Git failed; creation goes on without it.
  gitFailed(isFailure: true),

  /// The project has every required file and folder.
  verified,

  /// The step threw; [CreationReport.detail] holds the error and creation
  /// stops.
  error(isFailure: true);

  const CreationOutcome({this.isFailure = false});

  /// Whether the step is shown as failed.
  final bool isFailure;

  /// The step's status in the progress list.
  LoadingStatus get status =>
      isFailure ? LoadingStatus.failed : LoadingStatus.success;
}
