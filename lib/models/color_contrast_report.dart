import 'package:fide/models/color_roles.dart';
import 'package:fide/models/wcag_color.dart';

part 'color_contrast_report.color_contrast_check.dart';
part 'color_contrast_report.color_contrast_element.dart';
part 'color_contrast_report.color_contrast_kind.dart';
part 'color_contrast_report.color_scheme_summary.dart';
part 'color_contrast_report.color_usage.dart';

/// What the color contrast analyzer found in a project's `lib` folder:
/// every text, icon and color scheme pair it judged against WCAG 2 level
/// AA, and how many it could not judge; every color the code writes, most
/// used first; and the color scheme of each theme the app renders.
///
/// Evaluation: FIDE finds these itself for now; once they prove useful,
/// the analysis moves into fCheck.
class ColorContrastReport {
  /// Creates the report of [checks] in [fileCount] Dart files.
  const ColorContrastReport({
    required this.checks,
    required this.fileCount,
    this.unjudged = 0,
    this.colors = const [],
    this.schemes = const [],
  });

  /// Percent in one whole, for [score].
  static const int _percent = 100;

  /// Every element judged, passing or not, by file then line.
  final List<ColorContrastCheck> checks;

  /// Every color the code writes, the most used first.
  final List<ColorUsage> colors;

  /// How many Dart files were read.
  final int fileCount;

  /// The color scheme of each theme the app renders, the light one first.
  final List<ColorSchemeSummary> schemes;

  /// Texts and icons not judged, as their color or what they are drawn on
  /// can't be read.
  final int unjudged;

  /// The checks that fall below WCAG 2 level AA, by file then line.
  List<ColorContrastCheck> get findings => [
    for (final check in checks)
      if (!check.passes) check,
  ];

  /// The share of [checks] that pass, in percent, rounded down so it
  /// shows 100 only when all of them do; 100 when nothing was judged.
  int get score => checks.isEmpty
      ? _percent
      : (checks.length - findings.length) * _percent ~/ checks.length;

  /// The checks of [element], in order.
  List<ColorContrastCheck> of(ColorContrastElement element) => [
    for (final check in checks)
      if (check.element == element) check,
  ];
}
