part of 'create_project_draft_notifier.dart';

/// The wording of the new-project wizard's progress list: what each
/// [CreationStep] says while pending and once it has a [CreationReport].
abstract final class CreationLabels {
  /// Start of the line of a step that threw.
  static const String _errorPrefix = 'Error: ';

  /// Start of the line of a failed AI service.
  static const String _aiFailedPrefix = 'AI code generation failed: ';

  /// What each pending step says.
  static const Map<CreationStep, String> _pending = {
    CreationStep.validate: 'Validating settings and checking dependencies...',
    CreationStep.flutterCreate: 'Creating Flutter project...',
    CreationStep.localization: 'Setting up localization...',
    CreationStep.codegen: 'Generating initial code structure...',
    CreationStep.gitInit: 'Initializing Git repository...',
    CreationStep.verification: 'Final verification and cleanup...',
  };

  /// What each outcome says, apart from the ones carrying a detail.
  static const Map<CreationOutcome, String> _outcomes = {
    CreationOutcome.validated: 'Dependencies validated successfully',
    CreationOutcome.flutterCreated: 'Flutter project created successfully',
    CreationOutcome.localizationSkipped: 'Localization skipped',
    CreationOutcome.localized: 'Localization setup completed',
    CreationOutcome.aiNotUsed: 'AI not available, using default structure',
    CreationOutcome.aiGenerated: 'AI-generated project files completed',
    CreationOutcome.aiTimedOut: 'AI generation timed out',
    CreationOutcome.aiFailedUsingDefaults:
        'AI code generation failed, using defaults',
    CreationOutcome.gitSkipped: 'Git not available, skipped',
    CreationOutcome.gitInitialized: 'Git repository initialized',
    CreationOutcome.gitFailed: 'Git initialization failed',
    CreationOutcome.verified: 'Project verification completed successfully',
  };

  /// The progress list before creation starts: every step pending.
  static List<LoadingAction> initialActions() => [
    for (final step in CreationStep.values)
      LoadingAction(step.number, pending(step), LoadingStatus.pending),
  ];

  /// What [step] says while it hasn't ended.
  static String pending(CreationStep step) => _pending[step]!;

  /// What [report] says.
  static String of(CreationReport report) => switch (report.outcome) {
    CreationOutcome.error => '$_errorPrefix${report.detail}',
    CreationOutcome.aiFailed => '$_aiFailedPrefix${report.detail}',
    final outcome => _outcomes[outcome]!,
  };
}
