import 'package:fide/constants/constants.dart';
import 'package:fide/models/color_contrast_issues.dart';
import 'package:fide/models/color_contrast_report.dart';
import 'package:fide/models/locale_number.dart';
import 'package:fide/models/wcag_color.dart';
import 'package:fide/providers/app_providers.dart';
import 'package:fide/providers/center_view.dart';
import 'package:fide/providers/editor_navigation.dart';
import 'package:fide/widget_services/center_view_close_button.dart';
import 'package:fide/widget_services/issue_row.dart';
import 'package:fide/widgets/action_card.dart';
import 'package:fide/widgets/card_grid.dart';
import 'package:fide/widgets/color_sample.dart';
import 'package:fide/widgets/detail_row.dart';
import 'package:fide/widgets/detail_section.dart';
import 'package:fide/widgets/empty_state.dart';
import 'package:fide/widgets/location_row.dart';
import 'package:fide/widgets/page_header.dart';
import 'package:fide/widgets/page_scroll_view.dart';
import 'package:fide/widgets/project_analysis_view.dart';
import 'package:fide/widgets/refresh_button.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// Shown in the center panel to review how accessible the open project's
/// colors are: how many of its texts, icons and color scheme pairs read
/// at WCAG 2 level AA, the color scheme of each theme its app renders,
/// and every color its code writes, the most used first.
class AccessibilityPanel extends ConsumerWidget {
  /// Creates the review of the open project's colors.
  const AccessibilityPanel({super.key});

  /// The view's glyph, on its overview card too.
  static const IconData icon = Icons.accessibility_new;

  /// The roles shown for each color scheme: the fills text is drawn on
  /// most, each followed by its on-color, then the outline.
  static const List<String> _shownRoles = [
    'primary',
    'onPrimary',
    'primaryContainer',
    'onPrimaryContainer',
    'secondary',
    'onSecondary',
    'tertiary',
    'onTertiary',
    'error',
    'onError',
    'surface',
    'onSurface',
    'onSurfaceVariant',
    'surfaceContainerHighest',
    'inverseSurface',
    'onInverseSurface',
    'outline',
  ];

  /// The contrast ranges the judged elements are counted in, the highest
  /// first: each one's least ratio and name.
  static const List<(double, String)> _ratioRanges = [
    (WcagColor.enhancedTextContrast, 'AAA 7:1+'),
    (WcagColor.minTextContrast, 'AA 4.5:1+'),
    (WcagColor.minLargeContrast, 'Large 3:1+'),
    (0, 'Under 3:1'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectPath = ref.watch(currentProjectPathProvider);
    final analysis = ref.watch(colorContrastProvider);
    return ProjectAnalysisView(
      analysis: analysis,
      loadingMessage: 'Reading the colors of lib…',
      builder: (report) => report == null || projectPath == null
          ? const EmptyState(message: 'Open a project to review its colors')
          : PageScrollView(
              children: [
                PageHeader(
                  title: CenterView.accessibility.label,
                  subTitle: summaryOf(report),
                  logo: const Icon(icon),
                  actions: [
                    RefreshButton(
                      busy: analysis.isLoading,
                      onPressed: () => ref.invalidate(colorContrastProvider),
                    ),
                    const CenterViewCloseButton(),
                  ],
                ),
                CardGrid(
                  children: [
                    _contrastCard(report, projectPath),
                    for (final scheme in report.schemes)
                      _schemeCard(ref, scheme, projectPath),
                  ],
                ),
                _colorsCard(report),
              ],
            ),
    );
  }

  /// How many elements of [report] read at WCAG 2 level AA, the elements
  /// by kind and by contrast range, and the issue listing those that fall
  /// short, its findings under [projectPath].
  Widget _contrastCard(ColorContrastReport report, String projectPath) {
    final checks = report.checks;
    // Each element counts in the highest range it reaches; the last
    // range takes any ratio
    final perRange = List.filled(_ratioRanges.length, 0);
    for (final check in checks) {
      perRange[_ratioRanges.indexWhere((range) => check.ratio >= range.$1)]++;
    }
    return ActionCard(
      icon: Icons.contrast,
      title: 'Contrast',
      description:
          'Text needs 4.5:1 against what it is drawn on, large text and '
          'icons 3:1, in every theme the app renders. A color or background '
          "the code doesn't spell out is not judged.",
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: AppSpacing.large,
        children: [
          DetailSection('Elements judged', [
            for (final element in ColorContrastElement.values)
              if (report.of(element) case final judged when judged.isNotEmpty)
                DetailRow(
                  element.label,
                  '${judged.where((check) => check.passes).length.localized} '
                  'of ${judged.length.localized} read',
                ),
            if (report.unjudged > 0)
              DetailRow('Not judged', report.unjudged.count('element')),
          ]),
          if (checks.isNotEmpty)
            DetailSection('Contrast ratios', [
              for (final (index, (_, name)) in _ratioRanges.indexed)
                DetailRow(name, perRange[index].count('element')),
            ]),
          ...IssueRow.all([?report.issue(projectPath)]),
        ],
      ),
    );
  }

  /// Every color the code of [report] writes, the most used first, with
  /// its color in each theme the app renders and the names it is written
  /// as.
  Widget _colorsCard(ColorContrastReport report) {
    final colors = report.colors;
    final themes = report.schemes;
    final uses = colors.fold(0, (sum, color) => sum + color.count);
    return ActionCard(
      icon: Icons.format_color_fill,
      title: 'Colors used',
      description: colors.isEmpty
          ? 'The code of lib writes no color.'
          : 'The code of lib writes ${colors.length.count('color')} '
                '${uses.count('time')}, the most used first, each in every '
                'theme the app renders.',
      child: DetailSection('Most used first', [
        for (final color in colors)
          DetailRow(
            color.colors.first.hex,
            color.names.entries
                .map((name) => '${name.key} ×${name.value.localized}')
                .join(', '),
            leading: _samples(color, themes),
          ),
      ]),
    );
  }

  /// The color scheme of one theme the app renders: how it is made, where
  /// the code under [projectPath] defines it, and its main roles.
  Widget _schemeCard(
    WidgetRef ref,
    ColorSchemeSummary scheme,
    String projectPath,
  ) {
    final given = scheme.givenRoles;
    final path = scheme.path;
    final line = scheme.line;
    return ActionCard(
      icon: scheme.isDark
          ? Icons.dark_mode_outlined
          : Icons.light_mode_outlined,
      title: themeLabel(scheme),
      description: given.isEmpty
          ? scheme.origin
          : '${scheme.origin}; the code sets ${given.length.count('role')}.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: AppSpacing.large,
        children: [
          if (path != null && line != null)
            LocationRow(
              icon: const Icon(Icons.palette_outlined, size: AppIconSize.small),
              name: 'Color scheme',
              path: path,
              line: line,
              rootPath: projectPath,
              onTap: () => openFileAtLine(ref, path, line),
            ),
          DetailSection('Roles', [
            for (final role in _shownRoles)
              if (scheme.roles[role] case final color?)
                DetailRow(color.hex, role, leading: ColorSample(color.argb)),
          ]),
        ],
      ),
    );
  }

  /// [color] in each of [themes], side by side: a color the same in every
  /// theme shows in each, so the samples line up from one color to the
  /// next.
  static Widget _samples(ColorUsage color, List<ColorSchemeSummary> themes) {
    final colors = color.colors;
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: AppSpacing.tiny,
      children: [
        for (final (index, theme) in themes.indexed)
          if (colors.length == themes.length ? colors[index] : colors.first
              case final shown)
            ColorSample(
              shown.argb,
              tooltip: '${themeLabel(theme)}: ${shown.hex}',
            ),
      ],
    );
  }

  /// [report] in one line: the share of its judged elements that read.
  static String summaryOf(ColorContrastReport report) {
    final judged = report.checks.length;
    return judged == 0
        ? 'No color could be judged'
        : '${report.score}% of ${judged.count('element')} read at WCAG AA';
  }

  /// The name of [scheme]'s theme, such as `Light theme`.
  static String themeLabel(ColorSchemeSummary scheme) =>
      scheme.isDark ? 'Dark theme' : 'Light theme';
}
