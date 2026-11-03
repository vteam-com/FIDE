/// What the Info panel shows of its own actions for the open project,
/// kept by `ProjectInfoController`; the metrics themselves are the
/// project's `ProjectMetrics`.
class ProjectInfoState {
  /// Nothing running yet.
  static const ProjectInfoState initial = ProjectInfoState();

  /// Pub's one-line explanation of why the last upgrade could not resolve
  /// the dependencies; null when it could.
  final String? conflictSummary;

  /// Whether the project is being analyzed or cleaned up.
  final bool isAnalyzing;

  /// Whether `flutter pub outdated` is running.
  final bool isCheckingOutdated;

  /// Whether the dependencies are being upgraded.
  final bool isUpgrading;

  /// What the last `flutter pub outdated` printed; null until it ran.
  final String? outdatedOutput;

  /// The packages pub blamed for a failed resolution.
  final Set<String> problematicPackages;

  /// Creates a state.
  const ProjectInfoState({
    this.isAnalyzing = false,
    this.isCheckingOutdated = false,
    this.isUpgrading = false,
    this.conflictSummary,
    this.outdatedOutput,
    this.problematicPackages = const {},
  });

  /// Returns a copy with the given fields replaced; [clearConflict] drops
  /// [conflictSummary].
  ProjectInfoState copyWith({
    bool? isAnalyzing,
    bool? isCheckingOutdated,
    bool? isUpgrading,
    String? conflictSummary,
    bool clearConflict = false,
    String? outdatedOutput,
    Set<String>? problematicPackages,
  }) {
    return ProjectInfoState(
      isAnalyzing: isAnalyzing ?? this.isAnalyzing,
      isCheckingOutdated: isCheckingOutdated ?? this.isCheckingOutdated,
      isUpgrading: isUpgrading ?? this.isUpgrading,
      conflictSummary: clearConflict
          ? null
          : conflictSummary ?? this.conflictSummary,
      outdatedOutput: outdatedOutput ?? this.outdatedOutput,
      problematicPackages: problematicPackages ?? this.problematicPackages,
    );
  }
}
