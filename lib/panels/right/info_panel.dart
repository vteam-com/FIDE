// ignore_for_file: deprecated_member_use

import 'dart:io';

import 'package:fide/constants/constants.dart';
import 'package:fide/models/document_state.dart';
import 'package:fide/providers/app_providers.dart';
import 'package:fide/providers/project_maintenance_service.dart';
import 'package:fide/providers/service_providers.dart';
import 'package:fide/widgets/badge_status.dart';
import 'package:fide/widgets/message_box.dart';
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

  /// Builds a BadgeStatus widget based on the quality score
  BadgeStatus _buildScoreBadge(int score) {
    final text = '$score%';
    if (score < AppMetric.criticalScoreThreshold) {
      return BadgeStatus.error(text: text);
    }
    if (score < AppMetric.warningScoreThreshold) {
      return BadgeStatus.warning(text: text);
    }
    return BadgeStatus.success(text: text);
  }

  /// Handles `_showScoreDetails`.
  void _showScoreDetails(
    BuildContext context,
    Map<String, dynamic> projectMetrics,
  ) {
    final healthIndicators =
        projectMetrics['healthIndicators'] as Map<String, dynamic>?;
    final isMissingPubspecLock =
        !(healthIndicators?['hasPubspecLock'] ?? false);
    final buildErrors = (healthIndicators?['buildErrors'] ?? 0) as int;
    final buildWarnings = (healthIndicators?['buildWarnings'] ?? 0) as int;
    final largeFiles = healthIndicators?['largeFiles'] as List?;
    final hasLargeFiles =
        largeFiles != null &&
        largeFiles.length > AppMetric.maxAllowedLargeFiles;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Quality Score Breakdown'),
        content: SingleChildScrollView(
          child: Column(
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
                isMissingPubspecLock,
                context,
              ),
              _buildDeductionItem(
                'Build errors (max 50 points)',
                -(buildErrors * AppMetric.buildErrorDeductionPer).clamp(
                  0,
                  AppMetric.buildErrorDeductionMax,
                ),
                buildErrors > 0,
                context,
              ),
              _buildDeductionItem(
                'Build warnings (max 20 points)',
                -(buildWarnings * AppMetric.buildWarningDeductionPer).clamp(
                  0,
                  AppMetric.buildWarningDeductionMax,
                ),
                buildWarnings > 0,
                context,
              ),
              _buildDeductionItem(
                'Large files (>3 files over 10MB)',
                -AppMetric.largeFileThresholdMb,
                hasLargeFiles,
                context,
              ),
              const Divider(height: AppSpacing.xxLarge),
              Text(
                'Final Score: ${projectMetrics['qualityScore']}/100',
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
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
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

  /// Handles `_openPubspecYaml`.
  void _openPubspecYaml() {
    try {
      final currentProjectPath = ref.read(currentProjectPathProvider);
      if (currentProjectPath == null) return;

      final pubspecPath = '$currentProjectPath/pubspec.yaml';
      if (!File(pubspecPath).existsSync()) {
        MessageBox.showError(context, 'pubspec.yaml not found');
        return;
      }

      final documents = ref.read(openDocumentsProvider);
      final existingIndex = documents.indexWhere(
        (doc) => doc.filePath == pubspecPath,
      );

      if (existingIndex == -1) {
        // Not open, add it
        final newDocument = DocumentState(filePath: pubspecPath);
        final updatedDocuments = [...documents, newDocument];
        ref.read(openDocumentsProvider.notifier).state = updatedDocuments;
        ref.read(activeDocumentIndexProvider.notifier).state =
            updatedDocuments.length - 1;
      } else {
        // Already open, switch to it
        ref.read(activeDocumentIndexProvider.notifier).state = existingIndex;
      }
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

      final currentMetrics = ref.read(projectMetricsProvider);
      final updatedMetrics = Map<String, dynamic>.from(currentMetrics)
        ..['outdated'] = ProjectMaintenanceService.parseOutdated(output);

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

  /// Handles `_parseDependencyConflictError`.
  void _parseDependencyConflictError(String error) {
    final lines = error.split('\n');
    String? cleanErrorMessage;

    // Look for the first line after "version solving failed."
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.contains('version solving failed.')) {
        // Get the next non-empty line
        for (int j = i + 1; j < lines.length; j++) {
          final nextLine = lines[j].trim();
          if (nextLine.isNotEmpty && !nextLine.startsWith('* Consider')) {
            cleanErrorMessage = nextLine;
            break;
          }
        }
        break;
      }
    }

    setState(() {
      _dependencyConflictError =
          cleanErrorMessage ?? 'Dependency conflict detected';
    });

    // Look for the specific package causing the conflict
    final regExp = RegExp(r'fide depends on both (\w+) ([^ ]+)');
    final match = regExp.firstMatch(error);
    if (match != null) {
      final packageName = match.group(1);
      if (packageName != null) {
        setState(() {
          _problematicPackages[packageName] = 'Incompatible version constraint';
        });
      }
    }
  }

  /// Handles `_buildDependencyChip`.
  Widget _buildDependencyChip(
    String packageName,
    String version,
    Map<String, dynamic> projectMetrics,
  ) {
    final outdated = projectMetrics['outdated'] as Map<String, dynamic>?;
    final isOutdated = outdated?.containsKey(packageName) ?? false;
    final isProblematic = _problematicPackages.containsKey(packageName);
    final outdatedInfo = isOutdated ? outdated![packageName] : null;
    final resolvableVersion = outdatedInfo?['resolvable'] as String?;
    final hasIncompatibleVersion =
        isOutdated && resolvableVersion != null && resolvableVersion == 'none';

    final label = isOutdated
        ? '$packageName $version → ${outdatedInfo!['latest']}'
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
        if (errorStr.contains('version solving failed')) {
          _parseDependencyConflictError(errorStr);
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
      return const Center(
        child: Text('No project loaded', style: TextStyle(color: Colors.grey)),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.medium),
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
                        projectMetrics['name'] as String? ?? 'Unknown Project',
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
                if (projectMetrics['version'] != null)
                  Text(
                    'v${projectMetrics['version']}',
                    style: TextStyle(
                      fontSize: AppFontSize.metadata,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),

            Text(
              projectMetrics['description'] as String? ?? '< no description >',
              style: TextStyle(
                fontSize: AppFontSize.metadata,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              overflow: TextOverflow.visible,
            ),

            // Health Indicators
            /// Handles `_buildHealthCard`.
            _buildHealthCard(projectMetrics),

            // Dependencies
            /// Handles `_buildDependenciesCard`.
            _buildDependenciesCard(projectMetrics),

            // Actions
            /// Handles `_buildActionsCard`.
            _buildActionsCard(projectMetrics),
          ],
        ),
      ),
    );
  }

  /// Handles `_buildHealthCard`.
  Widget _buildHealthCard(Map<String, dynamic> projectMetrics) {
    final indicators = (projectMetrics['healthIndicators'] as Map)
        .cast<String, dynamic>();

    final issues = <Map<String, dynamic>>[];

    if (!(indicators['hasPubspecLock'] ?? false)) {
      issues.add({
        'type': 'warning',
        'message': 'Missing pubspec.lock',
        'icon': Icons.warning,
      });
    }

    final buildErrors = indicators['buildErrors'] ?? 0;
    if (buildErrors > 0) {
      issues.add({
        'type': 'error',
        'message': '$buildErrors build errors',
        'icon': Icons.error,
      });
    }

    final buildWarnings = indicators['buildWarnings'] ?? 0;
    if (buildWarnings > 0) {
      issues.add({
        'type': 'warning',
        'message': '$buildWarnings build warnings',
        'icon': Icons.warning,
      });
    }

    final largeFiles = indicators['largeFiles'] as List?;
    if (largeFiles != null && largeFiles.isNotEmpty) {
      issues.add({
        'type': 'info',
        'message': '${largeFiles.length} large files',
        'icon': Icons.file_present,
      });
    }

    return SectionPanel(
      title: 'Score',
      rightWidget: GestureDetector(
        onTap: () => _showScoreDetails(context, projectMetrics),
        child: _buildScoreBadge(projectMetrics['qualityScore'] as int),
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
  Widget _buildDependenciesCard(Map<String, dynamic> projectMetrics) {
    final depsDirect =
        (projectMetrics['dependencies'] as Map<String, dynamic>?) ?? {};
    final depsDev =
        (projectMetrics['devDependencies'] as Map<String, dynamic>?) ?? {};
    final totalDeps = depsDirect.length + depsDev.length;

    // Build dependency content widget
    final dependenciesContent = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          children: [
            ElevatedButton.icon(
              onPressed: _checkingOutdated ? null : _checkOutdated,
              icon: _checkingOutdated
                  ? const SizedBox(
                      width: AppIconSize.medium,
                      height: AppIconSize.medium,
                      child: CircularProgressIndicator(
                        strokeWidth: AppBorderWidth.medium,
                      ),
                    )
                  : const Icon(Icons.update, size: AppIconSize.medium),
              label: const Text('Outdated'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.medium,
                ),
              ),
            ),
            ElevatedButton.icon(
              onPressed: _upgrading ? null : _upgradePackages,
              icon: _upgrading
                  ? const SizedBox(
                      width: AppIconSize.medium,
                      height: AppIconSize.medium,
                      child: CircularProgressIndicator(
                        strokeWidth: AppBorderWidth.medium,
                      ),
                    )
                  : const Icon(Icons.arrow_upward, size: AppIconSize.medium),
              label: const Text('Upgrade'),
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
  Widget _buildActionsCard(Map<String, dynamic> _ /*projectMetrics*/) {
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
            ElevatedButton.icon(
              onPressed: _isRefreshing ? null : _performFullCleanup,
              icon: _isRefreshing
                  ? const SizedBox(
                      width: AppIconSize.medium,
                      height: AppIconSize.medium,
                      child: CircularProgressIndicator(
                        strokeWidth: AppBorderWidth.medium,
                      ),
                    )
                  : const Icon(
                      Icons.cleaning_services,
                      size: AppIconSize.medium,
                    ),
              label: const Text('Full Project Cleanup'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(
                  double.infinity,
                  AppSize.actionButtonHeight,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.medium),
            ElevatedButton.icon(
              onPressed: _isRefreshing ? null : _analyzeProject,
              icon: _isRefreshing
                  ? const SizedBox(
                      width: AppIconSize.medium,
                      height: AppIconSize.medium,
                      child: CircularProgressIndicator(
                        strokeWidth: AppBorderWidth.medium,
                      ),
                    )
                  : const Icon(Icons.refresh, size: AppIconSize.medium),
              label: const Text('Refresh Analysis'),
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
