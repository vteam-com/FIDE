import 'package:fide/constants/constants.dart';
import 'package:fide/models/action_outcome.dart';
import 'package:fide/models/dependency_version.dart';
import 'package:fide/models/project_info_state.dart';
import 'package:fide/models/project_metrics.dart';
import 'package:fide/models/status_tone.dart';
import 'package:fide/providers/app_providers.dart';
import 'package:fide/providers/project_info_controller.dart';
import 'package:fide/theme/app_theme.dart';
import 'package:fide/widget_services/output_panel.dart';
import 'package:fide/widgets/busy_bar.dart';
import 'package:fide/widgets/compact_icon_button.dart';
import 'package:fide/widgets/compact_text_button.dart';
import 'package:fide/widgets/empty_label.dart';
import 'package:fide/widgets/message_box.dart';
import 'package:fide/widgets/open_url.dart';
import 'package:fide/widgets/section_panel.dart';
import 'package:fide/widgets/status_tone_style.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// The Run tab's package management: the project's direct and developer
/// dependencies, each opening its pub.dev page, flagged when outdated or
/// conflicting; listing the outdated ones, upgrading them, editing
/// pubspec.yaml, and what pub reported.
class PackagesSection extends ConsumerWidget {
  /// Creates the section of the open project.
  const PackagesSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectMetrics = ref.watch(projectMetricsProvider);
    final info = ref.watch(projectInfoControllerProvider);
    final controller = ref.read(projectInfoControllerProvider.notifier);
    final depsDirect = projectMetrics.dependencies;
    final depsDev = projectMetrics.devDependencies;
    final pubBusy = info.isCheckingOutdated || info.isUpgrading;

    /// Shows how [outcome] ended, once it has, while the panel is there.
    Future<void> show(Future<ActionOutcome?> outcome) async {
      final result = await outcome;
      if (context.mounted && result != null) {
        MessageBox.showOutcome(context, result);
      }
    }

    /// The chips of [dependencies], wrapping.
    Widget chips(Map<String, DependencyVersion> dependencies) => Wrap(
      spacing: AppSpacing.medium,
      runSpacing: AppSpacing.tiny,
      children: [
        for (final MapEntry(key: name, value: version) in dependencies.entries)
          _buildDependencyChip(context, name, version, projectMetrics, info),
      ],
    );

    final dependenciesContent = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: AppSpacing.medium,
      children: [
        if (depsDirect.isNotEmpty)
          SectionPanel(
            title: 'Direct',
            count: depsDirect.length,
            child: chips(depsDirect),
          ),
        if (depsDev.isNotEmpty)
          SectionPanel(
            title: 'Developer',
            count: depsDev.length,
            child: chips(depsDev),
          ),
        if (depsDirect.isEmpty && depsDev.isEmpty)
          const EmptyLabel('No dependencies'),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AppSpacing.large,
      children: [
        // The pub chores are the section's actions; while one runs, both
        // are disabled and a bar runs atop the dependencies
        SectionPanel(
          title: 'Dependencies',
          count: depsDirect.length + depsDev.length,
          isExpanded: true,
          rightWidget: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CompactTextButton(
                icon: Icons.update,
                label: 'Outdated',
                tooltip: 'List packages with newer versions',
                onPressed: pubBusy
                    ? null
                    : () => show(controller.checkOutdated()),
              ),
              CompactTextButton(
                icon: Icons.arrow_upward,
                label: 'Upgrade',
                tooltip: 'Raise constraints to the latest resolvable versions',
                onPressed: pubBusy
                    ? null
                    : () => show(controller.upgradePackages()),
              ),
              CompactIconButton(
                icon: Icons.edit_note,
                tooltip: 'Edit pubspec.yaml',
                onPressed: () => _openPubspecYaml(context, ref),
              ),
            ],
          ),
          child: BusyBar.over(busy: pubBusy, child: dependenciesContent),
        ),

        // What pub printed, always shown when present
        if (info.outdatedOutput case final output?)
          OutputPanel(
            title: 'Package Analysis Output',
            text: output,
            isExpanded: true,
          ),
        if (info.conflictSummary case final conflict?)
          OutputPanel(
            title: 'Dependency Conflicts',
            text: conflict,
            isExpanded: true,
          ),
      ],
    );
  }

  /// Opens the project's pubspec.yaml in the editor.
  void _openPubspecYaml(BuildContext context, WidgetRef ref) {
    final pubspecPath = ref
        .read(projectInfoControllerProvider.notifier)
        .pubspecPath;
    if (pubspecPath == null) {
      MessageBox.showError(context, 'pubspec.yaml not found');
      return;
    }
    ref.read(openDocumentsProvider.notifier).open(pubspecPath);
  }

  /// The chip of dependency [packageName] at [version], flagged when
  /// outdated or conflicting, opening its pub.dev page.
  Widget _buildDependencyChip(
    BuildContext context,
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
          openUrl(context, 'https://pub.dev/packages/$packageName');
        }
      },
      backgroundColor: isProblematic || hasIncompatibleVersion
          ? AppTheme.errorBackground
          : null,
      labelPadding: AppPadding.chipLabel,
      visualDensity: VisualDensity.compact,
    );
  }
}
