import 'package:fide/constants/constants.dart';
import 'package:fide/models/project_overview.dart';
import 'package:fide/providers/app_providers.dart';
import 'package:fide/widgets/app_icon_image.dart';
import 'package:fide/widgets/badge_status.dart';
import 'package:fide/widgets/hero_title_widget.dart';
import 'package:fide/widgets/stat_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Shown in the center panel when no file is open: the current project's
/// icon, version, fCheck quality score, code size, tests, coverage and
/// translations.
class ProjectOverviewPanel extends ConsumerWidget {
  /// Creates the overview of the current project.
  const ProjectOverviewPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(projectOverviewProvider)
        .when(
          data: (overview) => overview == null
              ? _message('Select a file to start editing')
              : _overview(context, ref, overview),
          loading: () => const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              spacing: AppSpacing.large,
              children: [
                CircularProgressIndicator(),
                Text('Analyzing project with fCheck…'),
              ],
            ),
          ),
          error: (error, _) =>
              _message('Could not analyze the project: $error'),
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
      value: StatCard.text(
        context,
        languages.isEmpty ? 'Off' : '${languages.length} languages',
      ),
      details: [
        if (languages.isEmpty)
          'No ARB files in lib/l10n'
        else ...[
          languages.join(', '),
          '${overview.translations.length} strings',
          missing == 0 ? 'All translated' : '$missing missing translations',
        ],
        '$hardcoded hardcoded strings',
      ],
    );
  }

  /// Centered grey [text].
  Widget _message(String text) {
    return Center(
      child: Text(
        text,
        style: const TextStyle(fontSize: AppFontSize.title, color: Colors.grey),
      ),
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
    final weakest =
        code.analyzerScores
            .where(
              (analyzer) =>
                  analyzer.enabled &&
                  analyzer.scorePercent < AppMetric.maxScore,
            )
            .toList()
          ..sort((a, b) => a.score.compareTo(b.score));

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
                value: BadgeStatus.score(
                  code.complianceScore,
                  fontSize: AppFontSize.title,
                ),
                details: [
                  if (weakest.isEmpty)
                    'Every fCheck analyzer at 100%'
                  else
                    for (final analyzer in weakest.take(
                      AppMetric.overviewWeakestAnalyzers,
                    ))
                      '${analyzer.label}: ${analyzer.scorePercent}% '
                          '(${analyzer.issueCount} issues)',
                ],
              ),
              StatCard(
                icon: Icons.code,
                title: 'Lines of code',
                value: StatCard.text(context, '${code.totalLinesOfCode}'),
                details: [
                  '${code.totalDartFiles} Dart files',
                  '${code.totalCommentLines} comment lines '
                      '(${(code.commentRatio * AppMetric.maxScore).round()}%)',
                  '${code.codeSizeClassArtifacts.length} classes, '
                      '${code.totalFunctionCount} functions',
                  '${code.totalFiles} files in ${code.totalFolders} folders',
                ],
              ),
              StatCard(
                icon: Icons.science_outlined,
                title: 'Tests',
                value: StatCard.text(context, '${code.testCaseCount}'),
                details: code.hasTests
                    ? [
                        '${code.testDartFilesCount} test files',
                        '${code.testConsumedFilesCount} of '
                            '${code.totalDartFiles} files reached',
                      ]
                    : ['No tests yet'],
              ),
              StatCard(
                icon: Icons.track_changes,
                title: 'Code coverage',
                value: coverage == null
                    ? StatCard.text(context, 'No report')
                    : BadgeStatus.score(
                        coverage.percent,
                        fontSize: AppFontSize.title,
                      ),
                details: [
                  if (coverage == null)
                    'Run tests with coverage in the Test panel'
                  else
                    '${coverage.linesHit} of ${coverage.linesFound} lines hit',
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
