import 'package:fide/constants/constants.dart';
import 'package:fide/models/action_outcome.dart';
import 'package:fide/models/dependency_version.dart';
import 'package:fide/models/health_indicators.dart';
import 'package:fide/models/project_info_state.dart';
import 'package:fide/models/project_metrics.dart';
import 'package:fide/models/status_tone.dart';
import 'package:fide/providers/app_providers.dart';
import 'package:fide/providers/project_info_controller.dart';
import 'package:fide/theme/app_theme.dart';
import 'package:fide/widgets/badge_status.dart';
import 'package:fide/widgets/clickable.dart';
import 'package:fide/widgets/compact_icon_button.dart';
import 'package:fide/widgets/empty_label.dart';
import 'package:fide/widgets/issue_section.dart';
import 'package:fide/widgets/message_box.dart';
import 'package:fide/widgets/no_project_placeholder.dart';
import 'package:fide/widgets/open_url.dart';
import 'package:fide/widgets/output_panel.dart';
import 'package:fide/widgets/panel_scroll_view.dart';
import 'package:fide/widgets/primary_button.dart';
import 'package:fide/widgets/section_panel.dart';
import 'package:fide/widgets/section_title.dart';
import 'package:fide/widgets/status_indicator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The Info tab: the open project's name, version, health score,
/// dependencies and maintenance actions, run by [ProjectInfoController].
class InfoPanel extends ConsumerStatefulWidget {
  /// Creates the panel.
  const InfoPanel({super.key});

  @override
  ConsumerState<InfoPanel> createState() => _InfoPanelState();
}

class _InfoPanelState extends ConsumerState<InfoPanel> {
  /// The controller running the panel's actions.
  ProjectInfoController get _controller =>
      ref.read(projectInfoControllerProvider.notifier);

  @override
  void initState() {
    super.initState();
    _show(_controller.analyze());
  }

  /// Shows how an action ended, once it has, while the panel is there.
  Future<void> _show(Future<ActionOutcome?> outcome) async {
    final result = await outcome;
    if (mounted && result != null) {
      MessageBox.showOutcome(context, result);
    }
  }

  /// Handles `_showScoreDetails`.
  void _showScoreDetails(BuildContext context, HealthIndicators health) {
    MessageBox.showDetails(
      context,
      title: const Text('Quality Score Breakdown'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Starting Score: ${AppMetric.maxScore} points',
            style: AppTextStyle.captionStrong,
          ),
          const SizedBox(height: AppSpacing.large),
          const SectionTitle('Deductions'),
          const SizedBox(height: AppSpacing.medium),
          for (final deduction in health.deductions)
            StatusIndicator.tone(
              deduction.isActive ? StatusTone.error : StatusTone.success,
              label: deduction.isActive
                  ? '${deduction.label}: -${deduction.points} pts'
                  : '${deduction.label}: no deduction',
            ),
          const Divider(),
          SectionTitle(
            'Final Score: ${health.qualityScore}/${AppMetric.maxScore}',
          ),
          const SizedBox(height: AppSpacing.medium),
          const Text('Score ranges:', style: AppTextStyle.captionStrong),
          const SizedBox(height: AppSpacing.tiny),
          Text(
            '• Green (${AppMetric.warningScoreThreshold}-${AppMetric.maxScore}): '
            'Good project health\n'
            '• Orange (${AppMetric.criticalScoreThreshold}-'
            '${AppMetric.warningScoreThreshold - 1}): Needs attention\n'
            '• Red (0-${AppMetric.criticalScoreThreshold - 1}): Critical issues',
            style: AppTextStyle.secondary(context),
          ),
        ],
      ),
    );
  }

  /// Cleans the project up once the user confirms what it involves.
  Future<void> _performFullCleanup() async {
    final confirmed = await MessageBox.confirm(
      context,
      title: 'Full Project Cleanup',
      message: 'This will:\n• Flutter clean\n• Remove build artifacts\n• Clear pub cache\n• Reset CocoaPods (if macOS)\n\nContinue?',
      confirmLabel: 'Continue',
    );
    if (confirmed && mounted) _show(_controller.fullCleanup());
  }

  /// Opens the project's pubspec.yaml in the editor.
  void _openPubspecYaml() {
    final pubspecPath = _controller.pubspecPath;
    if (pubspecPath == null) {
      MessageBox.showError(context, 'pubspec.yaml not found');
      return;
    }
    ref.read(openDocumentsProvider.notifier).open(pubspecPath);
  }

  /// Opens [packageName]'s page on pub.dev.
  Future<void> _openPubDev(String packageName) =>
      openUrl(context, 'https://pub.dev/packages/$packageName');

  /// Handles `_buildDependencyChip`.
  Widget _buildDependencyChip(
    String packageName,
    DependencyVersion version,
    ProjectMetrics projectMetrics,
    ProjectInfoState info,
  ) {
    final outdatedInfo = projectMetrics.outdated[packageName];
    final isOutdated = outdatedInfo != null;
    final isProblematic = info.problematicPackages.contains(packageName);
    final hasIncompatibleVersion =
        outdatedInfo?.hasNoResolvableVersion ?? false;

    final colorScheme = Theme.of(context).colorScheme;
    final label = isOutdated
        ? '$packageName ${version.label} → ${outdatedInfo.latest}'
        : '$packageName ${version.label}';

    return InputChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: AppTextStyle.badge.copyWith(
              color: isProblematic || hasIncompatibleVersion
                  ? AppTheme.readable(AppTheme.errorColor, colorScheme)
                  : (isOutdated
                        ? AppTheme.readable(AppTheme.warningColor, colorScheme)
                        : null),
            ),
          ),
          if (isProblematic || hasIncompatibleVersion) ...[
            const SizedBox(width: AppSpacing.tiny),
            Icon(
              Icons.warning,
              size: AppIconSize.tiny,
              color: AppTheme.readable(AppTheme.errorColor, colorScheme),
            ),
          ],
        ],
      ),
      // Kept enabled for every chip so they all render alike
      onPressed: () {
        if (version.isHosted && !hasIncompatibleVersion) {
          _openPubDev(packageName);
        }
      },
      backgroundColor: isProblematic || hasIncompatibleVersion
          ? AppTheme.errorBackground
          : null,
      labelPadding: AppPadding.chipLabel,
      visualDensity: VisualDensity.compact,
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentProjectPath = ref.watch(currentProjectPathProvider);
    final projectMetrics = ref.watch(projectMetricsProvider);
    final info = ref.watch(projectInfoControllerProvider);

    if (currentProjectPath == null) {
      return const NoProjectPlaceholder();
    }

    return PanelScrollView(
      children: [
        // Header with project info
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    projectMetrics.name ?? 'Unknown Project',
                    style: AppTextStyle.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                CompactIconButton(
                  icon: Icons.edit_note,
                  tooltip: 'Edit pubspec.yaml',
                  onPressed: _openPubspecYaml,
                ),
              ],
            ),
            if (projectMetrics.version != null)
              Text(
                'v${projectMetrics.version}',
                style: AppTextStyle.secondary(context),
              ),
          ],
        ),

        Text(
          projectMetrics.description ?? '< no description >',
          style: AppTextStyle.secondary(context),
          overflow: TextOverflow.visible,
        ),

        // Health Indicators, once the project has been analyzed
        if (projectMetrics.health case final health?)
          _buildHealthCard(health, currentProjectPath),

        // Dependencies
        _buildDependenciesCard(projectMetrics, info),

        // Actions
        _buildActionsCard(info),
      ],
    );
  }

  /// The project's score with each health issue and how to fix it, the
  /// files it names under [projectPath].
  Widget _buildHealthCard(HealthIndicators health, String projectPath) {
    return IssueSection(
      title: 'Score',
      issues: [
        for (final deduction in health.deductions)
          if (deduction.count > 0) deduction.toIssue(projectPath),
      ],
      emptyLabel: 'No issues detected',
      rightWidget: Clickable(
        onTap: () => _showScoreDetails(context, health),
        child: BadgeStatus.score(health.qualityScore),
      ),
    );
  }

  /// Handles `_buildDependenciesCard`.
  Widget _buildDependenciesCard(
    ProjectMetrics projectMetrics,
    ProjectInfoState info,
  ) {
    final depsDirect = projectMetrics.dependencies;
    final depsDev = projectMetrics.devDependencies;
    final totalDeps = depsDirect.length + depsDev.length;

    // Build dependency content widget
    final dependenciesContent = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: AppSpacing.medium,
      children: [
        Wrap(
          spacing: AppSpacing.medium,
          runSpacing: AppSpacing.medium,
          children: [
            PrimaryButton(
              busy: info.isCheckingOutdated,
              icon: Icons.update,
              label: 'Outdated',
              onPressed: () => _show(_controller.checkOutdated()),
            ),
            PrimaryButton(
              busy: info.isUpgrading,
              icon: Icons.arrow_upward,
              label: 'Upgrade',
              onPressed: () => _show(_controller.upgradePackages()),
            ),
          ],
        ),

        if (depsDirect.isNotEmpty)
          SectionPanel(
            title: 'Direct',
            count: depsDirect.length,
            child: Wrap(
              spacing: AppSpacing.medium,
              runSpacing: AppSpacing.tiny,
              children: depsDirect.entries.map((entry) {
                return _buildDependencyChip(
                  entry.key,
                  entry.value,
                  projectMetrics,
                  info,
                );
              }).toList(),
            ),
          ),

        if (depsDev.isNotEmpty)
          SectionPanel(
            title: 'Developer',
            count: depsDev.length,
            child: Wrap(
              spacing: AppSpacing.medium,
              runSpacing: AppSpacing.tiny,
              children: depsDev.entries.map((entry) {
                return _buildDependencyChip(
                  entry.key,
                  entry.value,
                  projectMetrics,
                  info,
                );
              }).toList(),
            ),
          ),

        if (depsDirect.isEmpty && depsDev.isEmpty)
          const EmptyLabel('No dependencies'),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Use SectionPanel for main dependencies section
        SectionPanel(
          title: 'Dependencies',
          count: totalDeps,
          isExpanded:
              true, // Dependencies section should be expanded by default
          child: dependenciesContent,
        ),

        // Outdated command output (always visible when present)
        if (info.outdatedOutput case final output?) ...[
          const SizedBox(height: AppSpacing.large),
          OutputPanel(
            title: '📄 Package Analysis Output',
            text: output,
            isExpanded: true,
          ),
        ],

        // Dependency conflict output (always visible when present)
        if (info.conflictSummary case final conflict?) ...[
          const SizedBox(height: AppSpacing.large),
          OutputPanel(
            title: '⚠️ Dependency Conflicts',
            text: conflict,
            isExpanded: true,
          ),
        ],
      ],
    );
  }

  /// Handles `_buildActionsCard`.
  Widget _buildActionsCard(ProjectInfoState info) {
    return SectionPanel(
      title: 'Actions',
      isExpanded: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: AppSpacing.medium,
        children: [
          PrimaryButton(
            busy: info.isAnalyzing,
            icon: Icons.cleaning_services,
            label: 'Full Project Cleanup',
            onPressed: _performFullCleanup,
          ),
          PrimaryButton(
            busy: info.isAnalyzing,
            icon: Icons.refresh,
            label: 'Refresh Analysis',
            onPressed: () => _show(_controller.analyze()),
          ),
        ],
      ),
    );
  }
}
