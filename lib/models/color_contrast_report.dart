import 'package:fide/models/wcag_color.dart';

part 'color_contrast_report.color_contrast_finding.dart';
part 'color_contrast_report.color_contrast_kind.dart';

/// What the color contrast analyzer found in a project's `lib` folder: the
/// text and icons whose color falls below WCAG 2 level AA against what
/// they are drawn on, and the on-colors of its color schemes that do.
///
/// Evaluation: FIDE finds these itself for now; once they prove useful,
/// the analysis moves into fCheck.
class ColorContrastReport {
  /// Creates the report of [findings] in [fileCount] Dart files.
  const ColorContrastReport({required this.findings, required this.fileCount});

  /// How many Dart files were read.
  final int fileCount;

  /// What was found, by file then line.
  final List<ColorContrastFinding> findings;
}
