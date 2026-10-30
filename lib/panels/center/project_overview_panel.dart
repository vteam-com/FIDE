import 'package:fide/constants/constants.dart';
import 'package:fide/models/flutter_platform.dart';
import 'package:fide/models/locale_number.dart';
import 'package:fide/models/project_overview.dart';
import 'package:fide/providers/app_providers.dart';
import 'package:fide/widgets/app_icon_image.dart';
import 'package:fide/widgets/badge_status.dart';
import 'package:fide/widgets/empty_state.dart';
import 'package:fide/widgets/hero_title_widget.dart';
import 'package:fide/widgets/loading_indicator.dart';
import 'package:fide/widgets/platform_icon.dart';
import 'package:fide/widgets/stat_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Shown in the center panel when no file is open: the current project's
/// icon, version, fCheck quality score, code size, supported platforms,
/// tests, coverage and translations.
class ProjectOverviewPanel extends ConsumerWidget {
  /// Creates the overview of the current project.
  const ProjectOverviewPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(projectOverviewProvider)
        .when(
          data: (overview) => overview == null
              ? const EmptyState(message: 'Select a file to start editing')
              : _overview(context, ref, overview),
          loading: () =>
              const LoadingIndicator(message: 'Analyzing project with fCheck…'),
          error: (error, _) =>
              EmptyState(message: 'Could not analyze the project: $error'),
        );
  }

  /// The project's translations, or how to start them.
  Widget _localizationCard(BuildContext context, ProjectOverview overview) {
    final languages = overview.languages;
    final missing = overview.missingTranslations;
    final hardcoded = overview.code.hardcodedStringIssues.length;
    return StatCard(
      icon: Icons.translate,
      title: 'Localization',
      value: languages.isEmpty
          ? StatCard.text(context, 'Off')
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
        '${hardcoded.localized} hardcoded strings',
      ],
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

  /// The header and one card per measure.
  Widget _overview(
    BuildContext context,
    WidgetRef ref,
    ProjectOverview overview,
  ) {
    final code = overview.code;
    final coverage = overview.coverage;
    final deductions = code.analyzerDeductionPercents;
    final failing =
        code.analyzerScores
            .where(
              (analyzer) =>
                  analyzer.issueCount > 0 && deductions[analyzer.key]! > 0,
            )
            .toList()
          ..sort((a, b) => deductions[b.key]!.compareTo(deductions[a.key]!));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.huge),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: AppSpacing.xxLarge,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: AppSpacing.medium,
                  children: [
                    HeroTitleWidget(
                      title: code.projectName,
                      logo: AppIconImage(
                        path: overview.appIconPath,
                        size: AppSize.heroLogoHeight,
                        fallback: const Icon(
                          Icons.flutter_dash,
                          size: AppSize.heroLogoHeight,
                        ),
                      ),
                    ),
                    Text(
                      'Version ${code.version}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Analyze again',
                icon: const Icon(Icons.refresh),
                onPressed: () => ref.invalidate(projectOverviewProvider),
              ),
            ],
          ),
          Wrap(
            spacing: AppSpacing.xLarge,
            runSpacing: AppSpacing.xLarge,
            children: [
              StatCard(
                icon: Icons.verified_outlined,
                title: 'Quality',
                value: BadgeStatus.score(code.complianceScore, large: true),
                warnings: [
                  for (final analyzer in failing)
                    '${analyzer.label}: '
                        '-${deductions[analyzer.key]!.localized}% '
                        '(${analyzer.issueCount.localized} issues)',
                  if (code.suppressionPenaltyPoints > 0)
                    'Checks bypassed: '
                        '-${code.suppressionPenaltyPoints.localized}%',
                ],
                details: [if (failing.isEmpty) 'Every fCheck analyzer at 100%'],
              ),
              StatCard(
                icon: Icons.code,
                title: 'Sources',
                value: StatCard.text(
                  context,
                  '${code.totalLinesOfCode.localized} lines',
                ),
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
                  context,
                  (code.dependencyCount + code.devDependencyCount).localized,
                ),
                details: [
                  '${code.dependencyCount.localized} dependencies',
                  '${code.devDependencyCount.localized} dev dependencies',
                ],
              ),
              _platformsCard(overview),
              StatCard(
                icon: Icons.science_outlined,
                title: 'Tests',
                value: StatCard.text(context, code.testCaseCount.localized),
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
                    ? StatCard.text(context, 'No report')
                    : BadgeStatus.score(coverage.percent, large: true),
                details: [
                  if (coverage == null)
                    'Run tests with coverage in the Test panel'
                  else
                    '${coverage.linesHit.localized} of ${coverage.linesFound.localized} lines hit',
                  'Reachable from tests: ${overview.testReachPercent}%',
                ],
              ),
              _localizationCard(context, overview),
            ],
          ),
        ],
      ),
    );
  }
}
