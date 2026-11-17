import 'package:fide/constants/constants.dart';
import 'package:fide/models/action_outcome.dart';
import 'package:fide/models/dependency_version.dart';
import 'package:fide/models/project_info_state.dart';
import 'package:fide/models/project_metrics.dart';
import 'package:fide/models/status_tone.dart';
import 'package:fide/providers/app_providers.dart';
import 'package:fide/providers/project_info_controller.dart';
import 'package:fide/theme/app_theme.dart';
import 'package:fide/widget_services/issue_section.dart';
import 'package:fide/widget_services/output_panel.dart';
import 'package:fide/widget_services/project_icon.dart';
import 'package:fide/widgets/badge_status.dart';
import 'package:fide/widgets/compact_icon_button.dart';
import 'package:fide/widgets/empty_label.dart';
import 'package:fide/widgets/message_box.dart';
import 'package:fide/widgets/no_project_placeholder.dart';
import 'package:fide/widgets/open_url.dart';
import 'package:fide/widgets/panel_header.dart';
import 'package:fide/widgets/panel_scroll_view.dart';
import 'package:fide/widgets/primary_button.dart';
import 'package:fide/widgets/refresh_button.dart';
import 'package:fide/widgets/section_panel.dart';
import 'package:fide/widgets/status_tone_style.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// The Info tab: the open project's name, version, quality (the same as
/// the overview's), dependencies and maintenance actions, run by
/// [ProjectInfoController].
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
    // Analyzing marks the controller busy at once, which Riverpod forbids
    // while the tree builds
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _show(_controller.analyze());
    });
  }

  /// Shows how an action ended, once it has, while the panel is there.
  Future<void> _show(Future<ActionOutcome?> outcome) async {
    final result = await outcome;
    if (mounted && result != null) {
      MessageBox.showOutcome(context, result);
    }
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
                  ? StatusTone.error.readableIn(colorScheme)
                  : (isOutdated
                        ? StatusTone.warning.readableIn(colorScheme)
                        : null),
            ),
          ),
          if (isProblematic || hasIncompatibleVersion) ...[
            const SizedBox(width: AppSpacing.tiny),
            Icon(
              StatusTone.error.icon,
              size: AppIconSize.tiny,
              color: StatusTone.error.readableIn(colorScheme),
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

    final version = projectMetrics.version;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PanelHeader(
          leading: ProjectIcon(
            projectPath: currentProjectPath,
            size: AppIconSize.panelHeaderLeading,
          ),
          title: projectMetrics.name ?? 'Unknown Project',
          badge: version == null ? null : BadgeStatus.info(text: 'v$version'),
          subtitle: projectMetrics.description,
          actions: [
            CompactIconButton(
              icon: Icons.edit_note,
              tooltip: 'Edit pubspec.yaml',
              onPressed: _openPubspecYaml,
            ),
            RefreshButton(
              busy:
                  info.isAnalyzing ||
                  ref.watch(projectQualityBusyProvider),
              onPressed: () {
                refreshProjectQuality(ref.invalidate);
                _show(_controller.analyze());
              },
            ),
          ],
        ),
        Expanded(child: _buildContent(projectMetrics, info)),
      ],
    );
  }

  /// The project's quality, dependencies and actions.
  Widget _buildContent(ProjectMetrics projectMetrics, ProjectInfoState info) {
    return PanelScrollView(
      children: [
        // The project's quality, once fCheck has analyzed it
        if (ref.watch(projectQualityProvider) case final quality?)
          IssueSection(
            title: 'Quality',
            issues: quality.issues,
            emptyLabel: 'No issues detected',
            rightWidget: BadgeStatus.score(quality.score),
          ),

        // What dart analyze printed, links opening each place it names
        if (ref.watch(dartAnalysisProvider).value case final analysis?)
          OutputPanel(title: 'dart analyze', text: analysis.output),

        // Dependencies
        _buildDependenciesCard(projectMetrics, info),
      ],
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
}
