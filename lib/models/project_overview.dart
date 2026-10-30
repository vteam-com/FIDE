import 'package:fcheck/fcheck.dart' as fcheck;
import 'package:fide/constants/constants.dart';
import 'package:fide/models/code_coverage.dart';
import 'package:fide/models/flutter_platform.dart';
import 'package:fide/models/localization_data.dart';

/// What the center panel shows about the project when no file is open:
/// its icon, fCheck's analysis, platforms, translations and test coverage.
class ProjectOverview {
  /// The project's own app icon, or null when it has none.
  final String? appIconPath;

  /// fCheck's analysis: name, version, score, code size and tests.
  final fcheck.ProjectMetrics code;

  /// Language codes of the project's ARB files.
  final List<String> languages;

  /// Platforms the project has a folder for.
  final Set<FlutterPlatform> platforms;

  /// Every translation key compared across [languages].
  final List<ArbComparison> translations;

  /// Coverage from the last `flutter test --coverage`, or null when the
  /// project has no report.
  final CodeCoverage? coverage;

  /// Creates the overview of one project.
  const ProjectOverview({
    required this.appIconPath,
    required this.code,
    required this.languages,
    required this.platforms,
    required this.translations,
    required this.coverage,
  });

  /// Translations missing across every language, the base one included.
  int get missingTranslations => translations.fold(
    0,
    (sum, key) =>
        sum + key.missingInLanguages.length + (key.isMissingInEnglish ? 1 : 0),
  );

  /// Share of Dart lines reachable from tests, from 0 to
  /// [AppMetric.maxScore]; fCheck's static estimate, no tests run.
  int get testReachPercent => code.totalLinesOfCode == 0
      ? 0
      : (code.testConsumedLinesOfCode *
                AppMetric.maxScore /
                code.totalLinesOfCode)
            .round();
}
