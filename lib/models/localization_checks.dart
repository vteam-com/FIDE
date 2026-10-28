/// Which parts of the localization setup a project already has, read from
/// its files in one pass by `LocalizationService.inspect`.
class LocalizationChecks {
  /// Result for a folder with no readable project files.
  static const LocalizationChecks none = LocalizationChecks(
    hasPubspec: false,
    isFlutterProject: false,
    hasArbFiles: false,
    hasGeneratedClasses: false,
    hasAppIntegration: false,
    hasDependencies: false,
    hasGenerateFlag: false,
  );

  /// Whether `main.dart` wires `AppLocalizations` delegates and locales.
  final bool hasAppIntegration;

  /// Whether `lib/l10n` holds at least one ARB file.
  final bool hasArbFiles;

  /// Whether pubspec depends on `flutter_localizations` and `intl`.
  final bool hasDependencies;

  /// Whether `flutter gen-l10n` output exists.
  final bool hasGeneratedClasses;

  /// Whether pubspec enables code generation (`generate: true`).
  final bool hasGenerateFlag;

  /// Whether the folder has a pubspec.yaml at all.
  final bool hasPubspec;

  /// Whether the pubspec declares a Flutter project.
  final bool isFlutterProject;

  /// Creates a check result.
  const LocalizationChecks({
    required this.hasPubspec,
    required this.isFlutterProject,
    required this.hasArbFiles,
    required this.hasGeneratedClasses,
    required this.hasAppIntegration,
    required this.hasDependencies,
    required this.hasGenerateFlag,
  });
}
