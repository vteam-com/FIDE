import 'package:fide/models/localization_checks.dart';
import 'package:fide/models/localization_data.dart';
import 'package:fide/models/localization_status.dart';

/// What the Localization panel shows for the open project, kept by
/// `LocalizationController`.
class LocalizationState {
  /// Nothing inspected yet.
  static const LocalizationState initial = LocalizationState();

  /// Latest file checks; null until the project has been inspected.
  final LocalizationChecks? checks;

  /// Whether the last inspection failed.
  final bool checkFailed;

  /// The ARB files that parsed.
  final List<ArbFile> arbFiles;

  /// Per-key comparison across [arbFiles].
  final List<ArbComparison> comparisons;

  /// Paths of the ARB files that are not valid JSON objects.
  final List<String> malformedArbFiles;

  /// Why loading the ARB files failed, if it did.
  final String? loadError;

  /// Whether an action (setup, generation, translation...) is running.
  final bool isBusy;

  /// Creates a state.
  const LocalizationState({
    this.checks,
    this.checkFailed = false,
    this.arbFiles = const [],
    this.comparisons = const [],
    this.malformedArbFiles = const [],
    this.loadError,
    this.isBusy = false,
  });

  /// The status that picks which view to show.
  LocalizationStatus get status {
    if (checkFailed) return LocalizationStatus.error;
    return checks?.status ?? LocalizationStatus.checking;
  }

  /// Returns a copy with the given fields replaced; [clearLoadError] drops
  /// [loadError].
  LocalizationState copyWith({
    LocalizationChecks? checks,
    bool? checkFailed,
    List<ArbFile>? arbFiles,
    List<ArbComparison>? comparisons,
    List<String>? malformedArbFiles,
    String? loadError,
    bool clearLoadError = false,
    bool? isBusy,
  }) {
    return LocalizationState(
      checks: checks ?? this.checks,
      checkFailed: checkFailed ?? this.checkFailed,
      arbFiles: arbFiles ?? this.arbFiles,
      comparisons: comparisons ?? this.comparisons,
      malformedArbFiles: malformedArbFiles ?? this.malformedArbFiles,
      loadError: clearLoadError ? null : loadError ?? this.loadError,
      isBusy: isBusy ?? this.isBusy,
    );
  }
}
