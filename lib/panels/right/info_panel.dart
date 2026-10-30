// ignore_for_file: deprecated_member_use

import 'dart:io';

import 'package:fide/constants/constants.dart';
import 'package:fide/models/health_indicators.dart';
import 'package:fide/models/project_metrics.dart';
import 'package:fide/models/project_paths.dart';
import 'package:fide/providers/app_providers.dart';
import 'package:fide/providers/project_maintenance_service.dart';
import 'package:fide/providers/service_providers.dart';
import 'package:fide/widgets/badge_status.dart';
import 'package:fide/widgets/busy_icon_button.dart';
import 'package:fide/widgets/message_box.dart';
import 'package:fide/widgets/no_project_placeholder.dart';
import 'package:fide/widgets/output_panel.dart';
import 'package:fide/widgets/section_panel.dart';
import 'package:fide/widgets/status_indicator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

/// Represents `InfoPanel`.
class InfoPanel extends ConsumerStatefulWidget {
  const InfoPanel({super.key});

  @override
  ConsumerState<InfoPanel> createState() => _InfoPanelState();
}

class _InfoPanelState extends ConsumerState<InfoPanel> {
  bool _isRefreshing = false;
  bool _checkingOutdated = false;
  bool _upgrading = false;
  String? _dependencyConflictError;
  String? _outdatedCommandOutput;
  Map<String, String> _problematicPackages = {};

  @override
  void initState() {
    super.initState();

    /// Handles `_analyzeProject`.
    _analyzeProject();
  }

  /// Handles `_analyzeProject`.
  Future<void> _analyzeProject() async {
    final currentProjectPath = ref.read(currentProjectPathProvider);
    if (currentProjectPath == null) return;

    setState(() => _isRefreshing = true);

    try {
      final metrics = await ref
          .read(projectAnalyzerProvider)
          .analyze(currentProjectPath);
      await ref
          .read(projectMetricsProvider.notifier)
          .updateMetrics(currentProjectPath, metrics);
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isRefreshing = false);
        MessageBox.showError(context, 'Failed to analyze project: $e');
      }
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
            'Starting Score: 100 points',
            style: TextStyle(
              fontSize: AppFontSize.caption,
              fontWeight: FontWeight.w500,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: AppSpacing.large),
          const Text(
            'Deductions:',
            style: TextStyle(
              fontSize: AppFontSize.caption,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.medium),

          /// Handles `_buildDeductionItem`.
          _buildDeductionItem(
            'Missing pubspec.lock',
            -AppMetric.missingLockDeduction,
            !health.hasPubspecLock,
            context,
          ),
          _buildDeductionItem(
            'Build errors (max 50 points)',
            -health.buildErrorDeduction,
            health.buildErrors > 0,
            context,
          ),
          _buildDeductionItem(
            'Build warnings (max 20 points)',
            -health.buildWarningDeduction,
            health.buildWarnings > 0,
            context,
          ),
          _buildDeductionItem(
            'Large files (>3 files over 10MB)',
            -AppMetric.largeFileThresholdMb,
            health.hasTooManyLargeFiles,
            context,
          ),
          const Divider(height: AppSpacing.xxLarge),
          Text(
            'Final Score: ${health.qualityScore}/${AppMetric.maxScore}',
            style: TextStyle(
              fontSize: AppFontSize.label,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: AppSpacing.medium),
          const Text(
            'Score ranges:',
            style: TextStyle(
              fontSize: AppFontSize.caption,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: AppSpacing.tiny),
          Text(
            '• Green (80-100): Good project health\n'
            '• Orange (50-79): Needs attention\n'
            '• Red (0-49): Critical issues',
            style: TextStyle(
              fontSize: AppFontSize.metadata,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  /// Handles `_buildDeductionItem`.
  Widget _buildDeductionItem(
    String label,
    int points,
    bool active,
    BuildContext context,
  ) {
    return Row(
      children: [
        Icon(
          active ? Icons.remove : Icons.check,
          size: AppFontSize.label,
          color: active ? Colors.red.shade600 : Colors.green.shade600,
        ),
        const SizedBox(width: AppSpacing.medium),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: AppFontSize.metadata,
              color: active
                  ? Theme.of(context).colorScheme.onSurface
                  : Theme.of(context).colorScheme.onSurfaceVariant,
              decoration: active
                  ? TextDecoration.none
                  : TextDecoration.lineThrough,
            ),
          ),
        ),
        Text(
          active ? '$points pts' : 'No deduction',
          style: TextStyle(
            fontSize: AppFontSize.metadata,
            fontWeight: FontWeight.w500,
            color: active ? Colors.red.shade600 : Colors.green.shade600,
          ),
        ),
      ],
    );
  }

  /// Handles `_performFullCleanup`.
  Future<void> _performFullCleanup() async {
    final currentProjectPath = ref.read(currentProjectPathProvider);
    if (currentProjectPath == null) return;

    final confirmed = await MessageBox.confirm(
      context,
      title: 'Full Project Cleanup',
      message: 'This will:\n• Flutter clean\n• Remove build artifacts\n• Clear pub cache\n• Reset CocoaPods (if macOS)\n\nContinue?',
      confirmLabel: 'Continue',
    );

    if (!confirmed) return;

    setState(() => _isRefreshing = true);

    try {
      await ref
          .read(projectMaintenanceServiceProvider)
          .fullCleanup(currentProjectPath);

      // Re-analyze project
      await _analyzeProject();

      if (mounted) {
        MessageBox.showSuccess(context, 'Full project cleanup completed!');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isRefreshing = false);
        MessageBox.showError(context, 'Cleanup failed: $e');
      }
    }
  }

  /// Opens the project's pubspec.yaml in the editor.
  void _openPubspecYaml() {
    try {
      final currentProjectPath = ref.read(currentProjectPathProvider);
      if (currentProjectPath == null) return;

      final pubspecPath = ProjectPaths(currentProjectPath).pubspec;
      if (!File(pubspecPath).existsSync()) {
        MessageBox.showError(context, 'pubspec.yaml not found');
        return;
      }

      ref.read(openDocumentsProvider.notifier).open(pubspecPath);
    } catch (e) {
      MessageBox.showError(context, 'Failed to open pubspec.yaml: $e');
    }
  }

  /// Handles `_checkOutdated`.
  Future<void> _checkOutdated() async {
    final currentProjectPath = ref.read(currentProjectPathProvider);
    if (currentProjectPath == null) return;

    setState(() => _checkingOutdated = true);

    try {
      final output = await ref
          .read(projectMaintenanceServiceProvider)
          .outdatedReport(currentProjectPath);

      // Store the full command output
      setState(() {
        _outdatedCommandOutput = output;
        _dependencyConflictError = null;
      });

      final updatedMetrics = ref
          .read(projectMetricsProvider)
          .copyWith(outdated: ProjectMaintenanceService.parseOutdated(output));

      ref
          .read(projectMetricsProvider.notifier)
          .updateMetrics(currentProjectPath, updatedMetrics);

      if (mounted) {
        MessageBox.showSuccess(context, 'Outdated check completed');
      }
    } catch (e) {
      if (mounted) {
        MessageBox.showError(context, 'Failed to check outdated: $e');
      }
    } finally {
      if (mounted) setState(() => _checkingOutdated = false);
    }
  }

  /// Handles `_openPubDev`.
  Future<void> _openPubDev(String packageName) async {
    final uri = Uri.parse('https://pub.dev/packages/$packageName');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (mounted) {
        MessageBox.showError(context, 'Could not open pub.dev page');
      }
    }
  }

  /// Shows pub's version-solving [error] and flags the package it blames.
  void _showDependencyConflict(String error) {
    final conflict = ProjectMaintenanceService.parseVersionConflict(error);
    setState(() {
      _dependencyConflictError = conflict.summary;
      final package = conflict.package;
      if (package != null) {
        _problematicPackages[package] = 'Incompatible version constraint';
      }
    });
  }

  /// Handles `_buildDependencyChip`.
  Widget _buildDependencyChip(
    String packageName,
    String version,
    ProjectMetrics projectMetrics,
  ) {
    final outdatedInfo = projectMetrics.outdated[packageName];
    final isOutdated = outdatedInfo != null;
    final isProblematic = _problematicPackages.containsKey(packageName);
    final hasIncompatibleVersion =
        outdatedInfo?.hasNoResolvableVersion ?? false;

    final label = isOutdated
        ? '$packageName $version → ${outdatedInfo.latest}'
        : '$packageName $version';

    final isClickable =
        version != 'Flutter SDK' && version != 'Complex dependency';

    void onChipPressed() {
      if (isClickable) {
        if (hasIncompatibleVersion) {
          // Focus on the dependency conflict panel when clicked on incompatible version
          // This will scroll to and expand the panel automatically
        } else {
          _openPubDev(packageName);
        }
      }
    }

    return InputChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: AppFontSize.badge,
              color: isProblematic || hasIncompatibleVersion
                  ? Colors.red
                  : (isOutdated ? Colors.orange.shade700 : null),
            ),
          ),
          if (isProblematic || hasIncompatibleVersion) ...[
            const SizedBox(width: AppSpacing.tiny),
            Icon(Icons.warning, size: AppIconSize.tiny, color: Colors.red),
          ],
        ],
      ),
      onPressed: onChipPressed,
      backgroundColor: isProblematic || hasIncompatibleVersion
          ? Colors.red.shade50
          : null,
      labelPadding: AppPadding.chipLabel,
      visualDensity: VisualDensity.compact,
    );
  }

  /// Handles `_upgradePackages`.
  Future<void> _upgradePackages() async {
    final currentProjectPath = ref.read(currentProjectPathProvider);
    if (currentProjectPath == null) return;

    // Clear previous error state
    setState(() {
      _upgrading = true;
      _dependencyConflictError = null;
      _problematicPackages = {};
    });

    try {
      final updatedPackages = await ref
          .read(projectMaintenanceServiceProvider)
          .upgradeToResolvable(currentProjectPath);

      await _analyzeProject();

      if (mounted) {
        if (updatedPackages.isNotEmpty) {
          MessageBox.showSuccess(
            context,
            'Packages upgraded to compatible versions!',
          );
        } else {
          MessageBox.showInfo(
            context,
            'All packages already up to date with compatible versions.',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        final errorStr = e.toString();
        if (errorStr.contains(ProjectMaintenanceService.versionSolvingFailed)) {
          _showDependencyConflict(errorStr);
          MessageBox.showError(
            context,
            'Package upgrade failed due to dependency conflicts',
          );
        } else {
          MessageBox.showError(context, 'Error upgrading packages: $e');
        }
      }
    } finally {
      if (mounted) setState(() => _upgrading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentProjectPath = ref.watch(currentProjectPathProvider);
    final projectMetrics = ref.watch(projectMetricsProvider);

    if (currentProjectPath == null) {
      return const NoProjectPlaceholder();
    }

    return Padding(
      padding: AppPadding.panelContent,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: AppSpacing.medium,
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
                        style: TextStyle(
                          fontSize: AppFontSize.title,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      onPressed: _openPubspecYaml,
                      icon: const Icon(
                        Icons.edit_note,
                        size: AppIconSize.medium,
                      ),
                    ),
                  ],
                ),
                if (projectMetrics.version != null)
                  Text(
                    'v${projectMetrics.version}',
                    style: TextStyle(
                      fontSize: AppFontSize.metadata,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),

            Text(
              projectMetrics.description ?? '< no description >',
              style: TextStyle(
                fontSize: AppFontSize.metadata,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              overflow: TextOverflow.visible,
            ),

            // Health Indicators, once the project has been analyzed
            if (projectMetrics.health case final health?)
              _buildHealthCard(health),

            // Dependencies
            /// Handles `_buildDependenciesCard`.
            _buildDependenciesCard(projectMetrics),

            // Actions
            _buildActionsCard(),
          ],
        ),
      ),
    );
  }

  /// Handles `_buildHealthCard`.
  Widget _buildHealthCard(HealthIndicators health) {
    final issues = <Map<String, dynamic>>[];

    if (!health.hasPubspecLock) {
      issues.add({
        'type': 'warning',
        'message': 'Missing pubspec.lock',
        'icon': Icons.warning,
      });
    }

    final buildErrors = health.buildErrors;
    if (buildErrors > 0) {
      issues.add({
        'type': 'error',
        'message': '$buildErrors build errors',
        'icon': Icons.error,
      });
    }

    final buildWarnings = health.buildWarnings;
    if (buildWarnings > 0) {
      issues.add({
        'type': 'warning',
        'message': '$buildWarnings build warnings',
        'icon': Icons.warning,
      });
    }

    final largeFiles = health.largeFiles;
    if (largeFiles.isNotEmpty) {
      issues.add({
        'type': 'info',
        'message': '${largeFiles.length} large files',
        'icon': Icons.file_present,
      });
    }

    return SectionPanel(
      title: 'Score',
      rightWidget: GestureDetector(
        onTap: () => _showScoreDetails(context, health),
        child: BadgeStatus.score(health.qualityScore),
      ),

      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.large),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (issues.isEmpty)
              Text(
                '✅ No issues detected',
                style: TextStyle(
                  fontSize: AppFontSize.caption,
                  color: Colors.green.shade700,
                ),
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: issues
                    .map(
                      (issue) => Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.tiny),
                        child: StatusIndicator(
                          icon: issue['icon'] as IconData,
                          label: issue['message'] as String,

                          /// Handles `_getIssueColor`.
                          color: _getIssueColor(issue['type'] as String),
                          iconSize: AppFontSize.label,
                          textSize: AppFontSize.caption,
                          spacing: AppSpacing.medium,
                        ),
                      ),
                    )
                    .toList(),
              ),
          ],
        ),
      ),
    );
  }

  /// Handles `_getIssueColor`.
  Color _getIssueColor(String type) {
    switch (type) {
      case 'error':
        return Colors.red.shade700;
      case 'warning':
        return Colors.orange.shade700;
      case 'info':
        return Colors.blue.shade700;
      default:
        return Theme.of(context).colorScheme.onSurfaceVariant;
    }
  }

  /// Handles `_buildDependenciesCard`.
  Widget _buildDependenciesCard(ProjectMetrics projectMetrics) {
    final depsDirect = projectMetrics.dependencies;
    final depsDev = projectMetrics.devDependencies;
    final totalDeps = depsDirect.length + depsDev.length;

    // Build dependency content widget
    final dependenciesContent = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          children: [
            BusyIconButton(
              busy: _checkingOutdated,
              icon: Icons.update,
              label: 'Outdated',
              onPressed: _checkOutdated,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.medium,
                ),
              ),
            ),
            BusyIconButton(
              busy: _upgrading,
              icon: Icons.arrow_upward,
              label: 'Upgrade',
              onPressed: _upgradePackages,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.medium,
                ),
              ),
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
                );
              }).toList(),
            ),
          ),

        if (depsDirect.isEmpty && depsDev.isEmpty) ...[
          const SizedBox(height: AppSpacing.medium),
          Text(
            'No dependencies',
            style: TextStyle(
              fontSize: AppFontSize.caption,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Use SectionPanel for main dependencies section
        SectionPanel(
          title: 'Dependencies ($totalDeps)',
          isExpanded:
              true, // Dependencies section should be expanded by default
          child: dependenciesContent,
        ),

        // Outdated command output (always visible when present)
        if (_outdatedCommandOutput != null) ...[
          const SizedBox(height: AppSpacing.large),
          OutputPanel(
            title: '📄 Package Analysis Output',
            text: _outdatedCommandOutput!,
            isExpanded: true,
          ),
        ],

        // Dependency conflict output (always visible when present)
        if (_dependencyConflictError != null) ...[
          const SizedBox(height: AppSpacing.large),
          OutputPanel(
            title: '⚠️ Dependency Conflicts',
            text: _dependencyConflictError!,
            isExpanded: true,
          ),
        ],
      ],
    );
  }

  /// Handles `_buildActionsCard`.
  Widget _buildActionsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.large),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Actions',
              style: TextStyle(
                fontSize: AppFontSize.label,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: AppSpacing.large),
            BusyIconButton(
              busy: _isRefreshing,
              icon: Icons.cleaning_services,
              label: 'Full Project Cleanup',
              onPressed: _performFullCleanup,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(
                  double.infinity,
                  AppSize.actionButtonHeight,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.medium),
            BusyIconButton(
              busy: _isRefreshing,
              icon: Icons.refresh,
              label: 'Refresh Analysis',
              onPressed: _analyzeProject,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(
                  double.infinity,
                  AppSize.actionButtonHeight,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
