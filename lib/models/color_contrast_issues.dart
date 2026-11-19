import 'package:fide/constants/core_constants.dart';
import 'package:fide/models/color_contrast_report.dart';
import 'package:fide/models/locale_number.dart';
import 'package:fide/models/quality_issue.dart';
import 'package:fide/models/quality_issue.quality_finding.dart';

/// The color contrast analyzer's report as the project's quality shows it:
/// one issue listing every color below WCAG 2 level AA, and the
/// quality-score points they cost.
extension ColorContrastIssues on ColorContrastReport {
  /// The kind of problem the issue names.
  static const String title = 'Color contrast';

  /// How to make colors read, as Markdown, for the user and the AI.
  static const String _guidance =
      'Text needs a contrast of 4.5:1 with what it is drawn on, large text '
      'and icons 3:1 (WCAG 2 level AA), in every theme the app renders:\n\n'
      '- Draw on a fill with that fill\'s on-color: `onPrimary` on '
      '`primary`, `onSurface` on `surface`, rather than a fixed color.\n'
      '- Dim text with `onSurfaceVariant`, not with an opacity: faded text '
      'lets its background through.\n'
      '- Take colors from `Theme.of(context).colorScheme`, which follow the '
      'dark theme, rather than `Colors.black` or `Colors.grey`.\n'
      '- In a `ColorScheme` you write, pick each on-color so it reads on its '
      'fill.\n\n'
      'End a line the check misjudges with '
      '`// ignore: fcheck_color_contrast`.';

  /// Quality-score points the findings cost, capped.
  int get deduction => (findings.length * AppMetric.colorContrastPoints).clamp(
    0,
    AppMetric.colorContrastPointsMax,
  );

  /// The issue listing every finding, located under the project folder
  /// [rootPath]; null when there is none.
  QualityIssue? issue(String rootPath) => findings.isEmpty
      ? null
      : QualityIssue(
          label:
              '$title: -${deduction.localized}% '
              '(${findings.length.count('color')} below WCAG AA)',
          title: title,
          guidance: _guidance,
          rootPath: rootPath,
          findings: [
            for (final finding in findings)
              QualityFinding(
                path: finding.path,
                line: finding.line,
                text: finding.message,
              ),
          ],
        );
}
