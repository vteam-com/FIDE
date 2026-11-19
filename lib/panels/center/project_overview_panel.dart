import 'package:fide/constants/constants.dart';
import 'package:fide/models/color_contrast_issues.dart';
import 'package:fide/models/flutter_platform.dart';
import 'package:fide/models/locale_number.dart';
import 'package:fide/models/project_overview.dart';
import 'package:fide/models/quality_issues.dart';
import 'package:fide/models/status_tone.dart';
import 'package:fide/panels/center/accessibility_panel.dart';
import 'package:fide/providers/app_icon_review_provider.dart';
import 'package:fide/providers/app_providers.dart';
import 'package:fide/providers/center_view.dart';
import 'package:fide/providers/panel_actions.dart';
import 'package:fide/widget_services/center_view_close_button.dart';
import 'package:fide/widget_services/issue_row.dart';
import 'package:fide/widgets/app_icon_image.dart';
import 'package:fide/widgets/badge_status.dart';
import 'package:fide/widgets/card_grid.dart';
import 'package:fide/widgets/empty_state.dart';
import 'package:fide/widgets/page_header.dart';
import 'package:fide/widgets/page_scroll_view.dart';
import 'package:fide/widgets/platform_icon.dart';
import 'package:fide/widgets/project_analysis_view.dart';
import 'package:fide/widgets/refresh_button.dart';
import 'package:fide/widgets/secondary_button.dart';
import 'package:fide/widgets/stat_card.dart';
import 'package:fide/widgets/status_indicator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// Shown in the center panel when no file is open, or over open files as
/// [CenterView.overview]: the current project's icon, version, quality
/// (fCheck's score less what `dart analyze` and the color contrast
/// analyzer find, over the issues of those and the health checks), code
/// size, packages still on CocoaPods, supported platforms, tests,
/// coverage, translations, app icons, architecture and accessibility.
class ProjectOverviewPanel extends ConsumerWidget {
  /// Creates the overview of the current project.
  const ProjectOverviewPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ProjectAnalysisView(
      analysis: ref.watch(projectOverviewProvider),
      builder: (overview) => overview == null
          ? const EmptyState(message: 'Select a file to start editing')
          : _overview(ref, overview),
    );
  }

  /// How many of the project's texts, icons and color scheme pairs read at
  /// WCAG 2 level AA, its colors and themes, opening the Accessibility
  /// view to review them.
  Widget _accessibilityCard(WidgetRef ref) {
    final projectPath = ref.watch(currentProjectPathProvider);
    final report = ref.watch(colorContrastProvider).value;
    final judged = report?.checks.length ?? 0;
    final failing = report?.findings.length ?? 0;
    final schemes = report?.schemes ?? const [];
    return StatCard(
      icon: AccessibilityPanel.icon,
      title: CenterView.accessibility.label,
      value: switch (report) {
        null => StatCard.text('…'),
        _ when judged == 0 => StatCard.text('Not judged'),
        final report => BadgeStatus.score(report.score, large: true),
      },
      rows: IssueRow.all([
        if (projectPath != null) ?report?.issue(projectPath),
      ]),
      details: [
        if (report != null) ...[
          failing == 0
              ? '${judged.count('element')} judged, all at WCAG AA'
              : '${judged.count('element')} judged, '
                    '${failing.localized} below WCAG AA',
          '${report.colors.length.count('color')} used',
          switch (schemes) {
            [final only] => '${AccessibilityPanel.themeLabel(only)} only',
            _ => 'Light and dark themes',
          },
        ],
      ],
      action: SecondaryButton(
        icon: AccessibilityPanel.icon,
        label: 'Review',
        onPressed: () => showCenterView(ref, CenterView.accessibility),
      ),
    );
  }

  /// How many app icon problems the platforms have, opening the App Icons
  /// view to review and fix them.
  Widget _appIconsCard(WidgetRef ref) {
    final review = ref.watch(appIconReviewProvider).value;
    final issues = review?.issues;
    final platforms = review?.brokenPlatformLabels ?? const <String>{};
    return StatCard(
      icon: Icons.apps,
      title: 'App icons',
      value: issues == null
          ? StatCard.text('…')
          : issues.isEmpty
          ? StatusIndicator.tone(StatusTone.success, label: 'All good')
          : StatusIndicator.tone(
              StatusTone.warning,
              label: issues.length.count('problem'),
            ),
      details: [if (platforms.isNotEmpty) 'On ${platforms.join(', ')}'],
      action: SecondaryButton(
        // The App Icons view's own glyph, which it opens
        icon: Icons.apps,
        label: 'Review',
        onPressed: () => showCenterView(ref, CenterView.appIcons),
      ),
    );
  }

  /// How fCheck layers the project's files, opening the Architecture view
  /// to explore their imports.
  Widget _architectureCard(WidgetRef ref, ProjectOverview overview) {
    final code = overview.code;
    final violations = code.layersIssues.length;
    return StatCard(
      icon: Icons.account_tree_outlined,
      title: 'Architecture',
      value: StatCard.text(code.layersCount.count('layer')),
      details: [
        '${code.dependencyGraph.length.count('file')}, '
            '${code.layersEdgeCount.count('import')}',
        violations == 0
            ? 'No layering problems'
            : violations.count('layering problem'),
      ],
      action: SecondaryButton(
        icon: Icons.travel_explore,
        label: 'Explore',
        onPressed: () => showCenterView(ref, CenterView.architecture),
      ),
    );
  }

  /// The project's translations, or how to start them.
  Widget _localizationCard(ProjectOverview overview) {
    final languages = overview.languages;
    final missing = overview.missingTranslations;
    return StatCard(
      icon: Icons.translate,
      title: 'Localization',
      value: languages.isEmpty
          ? StatCard.text('Off')
          : Wrap(
              spacing: AppSpacing.medium,
              runSpacing: AppSpacing.medium,
              children: [
                for (final language in languages)
                  BadgeStatus.info(text: language.toUpperCase(), large: true),
              ],
            ),
      details: [
        if (languages.isEmpty)
          'No ARB files in lib/l10n'
        else ...[
          '${languages.length.localized} languages',
          '${overview.translations.length.localized} strings',
          missing == 0
              ? 'All translated'
              : '${missing.localized} missing translations',
        ],
      ],
      rows: IssueRow.all(overview.code.stringIssues),
    );
  }

  /// Every platform's icon, the project's own ones highlighted.
  Widget _platformsCard(ProjectOverview overview) {
    final platforms = overview.platforms;
    final missing = FlutterPlatform.values.where(
      (platform) => !platforms.contains(platform),
    );
    return StatCard(
      icon: Icons.devices_outlined,
      title: 'Supported platforms',
      value: Wrap(
        spacing: AppSpacing.large,
        runSpacing: AppSpacing.medium,
        children: [
          for (final platform in FlutterPlatform.values)
            Tooltip(
              message: platforms.contains(platform)
                  ? platform.displayName
                  : '${platform.displayName} (not configured)',
              child: PlatformIcon(
                platform: platform,
                size: AppIconSize.xLarge,
                isSupported: platforms.contains(platform),
                isSelected: platforms.contains(platform),
              ),
            ),
        ],
      ),
      details: [
        '${platforms.length.localized} of '
            '${FlutterPlatform.values.length.localized} platforms',
        if (missing.isNotEmpty)
          'Not configured: ${missing.map((p) => p.displayName).join(', ')}',
      ],
    );
  }

  /// How far the iOS and macOS apps are from Swift Package Manager only:
  /// the packages and pods still needing CocoaPods, or removing it once
  /// nothing does.
  Widget _swiftPackagesCard(ProjectOverview overview) {
    final migration = overview.cocoaPods;
    final podPlatforms = migration.podPlatforms;
    return StatCard(
      icon: Icons.apple,
      title: 'Swift packages',
      value: migration.isDone
          ? StatusIndicator.tone(StatusTone.success, label: 'No CocoaPods')
          : StatusIndicator.tone(
              StatusTone.warning,
              label: migration.canRemove
                  ? 'CocoaPods can go'
                  : 'Still on CocoaPods',
            ),
      rows: IssueRow.all(migration.issues),
      details: [
        if (podPlatforms.isNotEmpty)
          'Podfile in ${podPlatforms.map((platform) => platform.displayName).join(', ')}'
        else if (migration.isDone)
          'Every plugin uses Swift Package Manager',
      ],
    );
  }

  /// The header and one card per measure.
  Widget _overview(WidgetRef ref, ProjectOverview overview) {
    final code = overview.code;
    final coverage = overview.coverage;
    final quality = ref.watch(projectQualityProvider);
    final issues = quality?.issues ?? const [];

    return PageScrollView(
      children: [
        PageHeader(
          title: code.projectName,
          subTitle: 'Version ${code.version}',
          logo: AppIconImage(
            path: overview.appIconPath,
            size: AppSize.heroLogoHeight,
            fallback: const Icon(Icons.flutter_dash),
          ),
          actions: [
            RefreshButton(
              busy: ref.watch(projectQualityBusyProvider),
              onPressed: () => refreshProjectQuality(ref.invalidate),
            ),
            // Shown over open files: closing returns to them
            if (ref.watch(centerViewProvider) == CenterView.overview)
              const CenterViewCloseButton(),
          ],
        ),
        CardGrid(
          children: [
            StatCard(
              icon: Icons.verified_outlined,
              title: 'Quality',
              value: BadgeStatus.score(
                quality?.score ?? code.complianceScore,
                large: true,
              ),
              rows: IssueRow.all(issues),
              details: [
                if (issues.isEmpty)
                  'Every fCheck analyzer at 100%, nothing from dart analyze '
                      'nor the color contrast check',
              ],
            ),
            StatCard(
              icon: Icons.code,
              title: 'Sources',
              value: StatCard.text('${code.totalLinesOfCode.localized} lines'),
              details: [
                '${code.totalFolders.localized} folders, ${code.totalFiles.localized} files',
                '${code.totalDartFiles.localized} Dart files',
                '${code.codeSizeClassArtifacts.length.localized} classes, '
                    '${code.totalFunctionCount.localized} functions',
                '${code.totalCommentLines.localized} comment lines '
                    '(${(code.commentRatio * AppMetric.maxScore).round()}%)',
              ],
            ),
            StatCard(
              icon: Icons.inventory_2_outlined,
              title: 'Packages',
              value: StatCard.text(
                (code.dependencyCount + code.devDependencyCount).localized,
              ),
              details: [
                '${code.dependencyCount.localized} dependencies',
                '${code.devDependencyCount.localized} dev dependencies',
              ],
            ),
            if (overview.platforms.any((platform) => platform.isApple))
              _swiftPackagesCard(overview),
            _platformsCard(overview),
            StatCard(
              icon: Icons.science_outlined,
              title: 'Tests',
              value: StatCard.text(code.testCaseCount.localized),
              details: code.hasTests
                  ? [
                      '${code.testDartFilesCount.localized} test files',
                      '${code.testConsumedFilesCount.localized} of '
                          '${code.totalDartFiles.localized} files reached',
                    ]
                  : ['No tests yet'],
            ),
            StatCard(
              icon: Icons.track_changes,
              title: 'Code coverage',
              value: coverage == null
                  ? StatCard.text('No report')
                  : BadgeStatus.score(coverage.percent, large: true),
              details: [
                if (coverage == null)
                  'Run tests with coverage in the Test panel'
                else
                  '${coverage.linesHit.localized} of ${coverage.linesFound.localized} lines hit',
                'Reachable from tests: ${overview.testReachPercent}%',
              ],
            ),
            _localizationCard(overview),
            _appIconsCard(ref),
            _architectureCard(ref, overview),
            _accessibilityCard(ref),
          ],
        ),
      ],
    );
  }
}
