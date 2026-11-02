// ignore_for_file: deprecated_member_use

import 'package:fide/constants/constants.dart';
import 'package:fide/models/localization_data.dart';
import 'package:fide/models/localization_outcome.dart';
import 'package:fide/models/localization_state.dart';
import 'package:fide/models/localization_status.dart';
import 'package:fide/models/status_tone.dart';
import 'package:fide/panels/right/localization/localization_entry_widget.dart';
import 'package:fide/panels/right/localization/localization_setup_widget.dart';
import 'package:fide/providers/app_providers.dart';
import 'package:fide/providers/editor_navigation.dart';
import 'package:fide/providers/localization_controller.dart';
import 'package:fide/services/localization_service.dart';
import 'package:fide/widgets/action_card.dart';
import 'package:fide/widgets/badge_status.dart';
import 'package:fide/widgets/compact_text_button.dart';
import 'package:fide/widgets/empty_state.dart';
import 'package:fide/widgets/filter_field.dart';
import 'package:fide/widgets/issue_section.dart';
import 'package:fide/widgets/loading_indicator.dart';
import 'package:fide/widgets/message_box.dart';
import 'package:fide/widgets/no_project_placeholder.dart';
import 'package:fide/widgets/outlined_surface.dart';
import 'package:fide/widgets/path_text.dart';
import 'package:fide/widgets/section_title.dart';
import 'package:fide/widgets/status_indicator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Shows the open project's localization setup and ARB keys, rendering
/// [localizationControllerProvider] and calling its actions.
class LocalizationPanel extends ConsumerStatefulWidget {
  /// Creates the panel.
  const LocalizationPanel({super.key});

  @override
  ConsumerState<LocalizationPanel> createState() => _LocalizationPanelState();
}

class _LocalizationPanelState extends ConsumerState<LocalizationPanel> {
  final TextEditingController _filterController = TextEditingController();
  String _filterQuery = '';

  /// The controller behind the panel's actions.
  LocalizationController get _controller =>
      ref.read(localizationControllerProvider.notifier);

  @override
  void initState() {
    super.initState();
    _filterController.addListener(_onFilterChanged);
  }

  @override
  void dispose() {
    _filterController.removeListener(_onFilterChanged);
    _filterController.dispose();
    super.dispose();
  }

  void _onFilterChanged() {
    setState(() => _filterQuery = _filterController.text);
  }

  /// Waits for [outcome] and tells the user how the action ended.
  Future<void> _show(Future<LocalizationOutcome?> outcome) async {
    final result = await outcome;
    if (result == null || !mounted) return;
    if (result.succeeded) {
      MessageBox.showSuccess(context, result.message);
    } else {
      MessageBox.showError(context, result.message);
    }
  }

  /// Sets localization up, showing each step as it starts.
  void _initializeLocalization() => _show(
    _controller.initialize(
      onStep: (step) {
        if (mounted) MessageBox.showInfo(context, step);
      },
    ),
  );

  /// Wires the generated localizations into `main.dart`.
  void _updateMainDart() => _show(_controller.updateMainDart());

  /// Runs `flutter gen-l10n`.
  void _generateLocalizationClasses() => _show(_controller.generateClasses());

  @override
  Widget build(BuildContext context) {
    final projectRoot = ref.watch(currentProjectRootProvider);
    final state = ref.watch(localizationControllerProvider);

    if (projectRoot == null) {
      return const NoProjectPlaceholder();
    }

    if (state.isBusy) {
      return const LoadingIndicator();
    }

    if (state.loadError case final loadError?) {
      return EmptyState(
        message: loadError,
        isError: true,
        child: ElevatedButton(
          onPressed: _controller.reload,
          child: const Text('Retry'),
        ),
      );
    }

    final statusView = _buildStatusContent(state);
    final issues = ref.watch(stringIssuesProvider);
    if (issues == null) return statusView;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: AppPadding.panelContent,
          child: IssueSection(
            title: 'Strings',
            issues: issues,
            emptyLabel: 'Every string is localized',
          ),
        ),
        Expanded(child: statusView),
      ],
    );
  }

  /// The view for [state]'s status.
  Widget _buildStatusContent(LocalizationState state) {
    switch (state.status) {
      case LocalizationStatus.checking:
        return const LoadingIndicator();
      case LocalizationStatus.noProject:
        return _buildStatusView(
          'No Project',
          'No Flutter project is currently loaded.',
          Icons.folder_off,
        );
      case LocalizationStatus.notFlutterProject:
        return _buildStatusView(
          'Not a Flutter Project',
          'The loaded project does not appear to be a Flutter project.',
          Icons.flutter_dash,
        );
      case LocalizationStatus.notStarted:
        return SingleChildScrollView(
          child: LocalizationSetupWidget(
            onInitializeLocalization: _initializeLocalization,
            showUpdateMainDart: false, // Not needed for initial setup
            onUpdateMainDart: _updateMainDart,
            isInitializing: state.isBusy,
          ),
        );
      case LocalizationStatus.partial:
        return _buildPartialView(state);
      case LocalizationStatus.complete:
        return _buildCompleteView(state);
      case LocalizationStatus.error:
        return _buildStatusView(
          'Error',
          'An error occurred while checking localization status.',
          Icons.error,
          action: ElevatedButton(
            onPressed: _controller.reload,
            child: const Text('Retry'),
          ),
        );
    }
  }

  /// Handles `_buildStatusView`.
  Widget _buildStatusView(
    String title,
    String message,
    IconData icon, {
    Widget? action,
  }) {
    return EmptyState(
      icon: icon,
      title: title,
      message: message,
      child: action,
    );
  }

  /// The checklist and next step for a partly set up project.
  Widget _buildPartialView(LocalizationState state) {
    final checks = state.checks;
    if (checks == null) return const LoadingIndicator();
    final hasArbFiles = checks.hasArbFiles;
    final hasValidArbFiles = state.arbFiles.isNotEmpty;
    final hasGeneratedClasses = checks.hasGeneratedClasses;
    final hasAppIntegration = checks.hasAppIntegration;

    return SingleChildScrollView(
      padding: AppPadding.panelContent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle('Localization Partially Set Up'),
          const SizedBox(height: AppSpacing.xLarge),
          Text(
            'Your Flutter project has some localization components set up, but others are missing. Localization requires three main components:',
            style: AppTextStyle.label,
          ),
          const SizedBox(height: AppSpacing.medium),
          Text(
            '• ARB files (translation files in lib/l10n/)\n• Generated AppLocalizations class\n• Integration in main.dart',
            style: AppTextStyle.secondary(context),
          ),
          const SizedBox(height: AppSpacing.xLarge),
          Text('Here\'s the current status:', style: AppTextStyle.label),
          const SizedBox(height: AppSpacing.xLarge),

          // Status checks
          _buildStatusCheck(
            'Localization dependencies configured',
            checks.hasDependencies,
          ),
          _buildStatusCheck(
            'Flutter generate flag configured',
            checks.hasGenerateFlag,
          ),
          _buildStatusCheck('ARB files exist', hasArbFiles),
          if (hasArbFiles) ...[
            hasValidArbFiles
                ? _buildStatusCheck('ARB files are valid JSON', true)
                : _buildStatusCheckWithMalformedFiles(
                    'ARB files are valid JSON',
                    state.malformedArbFiles,
                  ),
          ],
          _buildStatusCheck('Generated classes exist', hasGeneratedClasses),
          _buildStatusCheck('App integration complete', hasAppIntegration),

          const SizedBox(height: AppSpacing.xxLarge),

          // Next Steps section
          const SectionTitle('Next Steps'),
          const SizedBox(height: AppSpacing.large),

          // Show specific actions based on what's missing
          if (!hasArbFiles) ...[
            _buildActionItem(
              'Create ARB files',
              'Set up localization files with template content',
              Icons.file_copy,
              _initializeLocalization,
            ),
          ] else if (!hasValidArbFiles) ...[
            _buildActionItem(
              'Fix malformed ARB files',
              'ARB files exist but contain invalid JSON. Check and repair the files in lib/l10n/',
              Icons.warning,
              () {
                MessageBox.showError(
                  context,
                  'ARB files are malformed. Please check the files in lib/l10n/ and ensure they contain valid JSON. You may need to recreate them using the Initialize Localization action.',
                );
              },
            ),
          ] else if (!hasGeneratedClasses) ...[
            _buildActionItem(
              'Generate localization classes',
              'Run flutter gen-l10n to create AppLocalizations class',
              Icons.build,
              _generateLocalizationClasses,
            ),
          ] else if (!hasAppIntegration) ...[
            _buildActionItem(
              'Update main.dart',
              'Add localization delegates and supported locales to MaterialApp',
              Icons.code,
              _updateMainDart,
            ),
          ],

          const SizedBox(height: AppSpacing.xxLarge),

          // Show ARB file management if files are loaded
          if (state.arbFiles.isNotEmpty) ...[
            const SectionTitle('ARB File Management'),
            const SizedBox(height: AppSpacing.large),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: state.comparisons.length,
              itemBuilder: (_ /*context*/, index) =>
                  _buildComparisonTile(state.comparisons[index]),
            ),
          ],
        ],
      ),
    );
  }

  /// The filterable list of every ARB key, flagging duplicated English
  /// values.
  Widget _buildCompleteView(LocalizationState state) {
    final filteredComparisons = state.comparisons
        .where((comparison) => comparison.matches(_filterQuery))
        .toList();
    final duplicatedValues = ArbService.duplicatedEnglishValues(
      filteredComparisons,
    );

    return Column(
      children: [
        // Duplicate warning banner
        if (duplicatedValues.isNotEmpty)
          Container(
            margin: AppPadding.panelContent,
            child: BadgeStatus.warning(
              text:
                  '${duplicatedValues.length} English ${duplicatedValues.length == 1 ? 'string is' : 'strings are'} duplicated',
              showIcon: true,
            ),
          ),
        Expanded(
          child: state.arbFiles.isEmpty
              ? const EmptyState(message: 'No ARB files found')
              : ListView.separated(
                  itemCount: filteredComparisons.length,
                  itemBuilder: (_ /*context*/, index) {
                    final comparison = filteredComparisons[index];
                    return LocalizationEntryWidget(
                      comparison: comparison,
                      showWarning: duplicatedValues.contains(
                        comparison.englishValue,
                      ),
                    );
                  },
                  separatorBuilder: (_ /*context*/, _ /*index*/) =>
                      const Divider(
                        height: AppSpacing.medium,
                        thickness: AppSize.borderThin,
                      ),
                ),
        ),
        // Filter bar
        FilterField(
          controller: _filterController,
          hintText: 'Filter localization keys...',
        ),
      ],
    );
  }

  /// Handles `_buildStatusCheck`.
  Widget _buildStatusCheck(String label, bool isComplete) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.medium),
      child: StatusIndicator.tone(
        isComplete ? StatusTone.success : StatusTone.warning,
        label: label,
      ),
    );
  }

  /// Handles `_buildStatusCheckWithMalformedFiles`.
  Widget _buildStatusCheckWithMalformedFiles(
    String label,
    List<String> malformedFiles,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.medium),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StatusIndicator.tone(StatusTone.error, label: label),
          const SizedBox(height: AppSpacing.tiny),
          Padding(
            padding: const EdgeInsets.only(left: AppSpacing.huge),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'The following ARB files contain invalid JSON:',
                  style: AppTextStyle.caption.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
                const SizedBox(height: AppSpacing.tiny),
                ...malformedFiles.map((filePath) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.micro),
                    child: Row(
                      children: [
                        Expanded(
                          child: PathText(
                            filePath,
                            showFolder: false,
                            style: AppTextStyle.caption.copyWith(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                        CompactTextButton(
                          icon: Icons.edit,
                          label: 'Edit',
                          onPressed: () => openFile(ref, filePath),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Handles `_buildActionItem`.
  Widget _buildActionItem(
    String title,
    String description,
    IconData icon,
    VoidCallback onPressed,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.large),
      child: ActionCard(
        title: title,
        icon: icon,
        description: description,
        action: ElevatedButton.icon(
          icon: const Icon(Icons.arrow_forward),
          label: const Text('Execute'),
          onPressed: onPressed,
        ),
      ),
    );
  }

  /// One key with a Translate button per language it is missing in.
  Widget _buildComparisonTile(ArbComparison comparison) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.medium),
      child: OutlinedSurface(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(comparison.key, style: AppTextStyle.title),
            const SizedBox(height: AppSpacing.tiny),
            if (comparison.englishValue != null)
              Text(
                'EN: ${comparison.englishValue}',
                style: AppTextStyle.secondary(context),
              ),
            const SizedBox(height: AppSpacing.medium),
            Wrap(
              spacing: AppSpacing.medium,
              runSpacing: AppSpacing.tiny,
              children: comparison.missingInLanguages.map((lang) {
                return ElevatedButton.icon(
                  icon: const Icon(Icons.translate, size: AppIconSize.medium),
                  label: Text('Translate to $lang'),
                  onPressed: comparison.englishValue != null
                      ? () => _show(_controller.translate(comparison, lang))
                      : null,
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
