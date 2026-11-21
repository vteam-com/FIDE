import 'package:fcheck/fcheck.dart' as fcheck;
import 'package:fide/constants/core_constants.dart';
import 'package:fide/models/cocoa_pods_migration.dart';
import 'package:fide/models/code_coverage.dart';
import 'package:fide/models/flutter_platform.dart';
import 'package:fide/models/localization_data.dart';
import 'package:fide/models/quick_fix.dart';

/// What the center panel shows about the project when no file is open:
/// fCheck's analysis, platforms, translations and test coverage.
class ProjectOverview {
  /// fCheck's analysis: name, version, score, code size and tests.
  final fcheck.ProjectMetrics code;

  /// Language codes of the project's ARB files.
  final List<String> languages;

  /// The locale of the ARB file the others fall back to; null without
  /// ARB files.
  final String? templateLocale;

  /// Platforms the project has a folder for.
  final Set<FlutterPlatform> platforms;

  /// How far its iOS and macOS apps are from Swift Package Manager only.
  final CocoaPodsMigration cocoaPods;

  /// Every translation key compared across [languages].
  final List<ArbComparison> translations;

  /// Coverage from the last `flutter test --coverage`, or null when the
  /// project has no report.
  final CodeCoverage? coverage;

  /// Creates the overview of one project.
  const ProjectOverview({
    required this.code,
    required this.languages,
    this.templateLocale,
    required this.platforms,
    required this.cocoaPods,
    required this.translations,
    required this.coverage,
  });

  /// The translations fCheck finds missing or still to make, as Translate
  /// with AI counts them: a key it leaves out, such as one marked not to be
  /// translated, counts none.
  int get missingTranslations => QuickFix.translateKeys
      .localesByKey(code)
      .values
      .fold(0, (sum, locales) => sum + locales.length);

  /// Share of Dart lines reachable from tests, in percent; fCheck's static
  /// estimate, no tests run.
  int get testReachPercent => code.totalLinesOfCode == 0
      ? 0
      : (code.testConsumedLinesOfCode *
                AppMetric.percent /
                code.totalLinesOfCode)
            .round();
}
