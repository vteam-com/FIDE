// ignore_for_file: deprecated_member_use

import 'package:fide/constants/constants.dart';
import 'package:fide/models/file_system_item.dart';
import 'package:fide/models/localization_checks.dart';
import 'package:fide/models/localization_data.dart';
import 'package:fide/models/project_paths.dart';
import 'package:fide/models/status_tone.dart';
import 'package:fide/panels/right/localization/localization_entry_widget.dart';
import 'package:fide/panels/right/localization/localization_setup_widget.dart';
import 'package:fide/providers/ai_service.dart';
import 'package:fide/providers/app_providers.dart';
import 'package:fide/providers/editor_navigation.dart';
import 'package:fide/providers/localization_service.dart';
import 'package:fide/providers/service_providers.dart';
import 'package:fide/widgets/action_card.dart';
import 'package:fide/widgets/badge_status.dart';
import 'package:fide/widgets/compact_text_button.dart';
import 'package:fide/widgets/empty_state.dart';
import 'package:fide/widgets/filter_field.dart';
import 'package:fide/widgets/loading_indicator.dart';
import 'package:fide/widgets/message_box.dart';
import 'package:fide/widgets/no_project_placeholder.dart';
import 'package:fide/widgets/outlined_surface.dart';
import 'package:fide/widgets/section_title.dart';
import 'package:fide/widgets/status_indicator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;

enum LocalizationStatus {
  checking,
  noProject,
  notFlutterProject,
  notStarted,
  partial,
  complete,
  error,
}

/// Represents `LocalizationPanel`.
class LocalizationPanel extends ConsumerStatefulWidget {
  const LocalizationPanel({super.key, this.selectedFile});

  final FileSystemItem? selectedFile;

  @override
  ConsumerState<LocalizationPanel> createState() => _LocalizationPanelState();
}

class _LocalizationPanelState extends ConsumerState<LocalizationPanel> {
  final Logger _logger = Logger('_LocalizationPanelState');
  late final ArbService _arbService = ref.read(arbServiceProvider);
  late final LocalizationService _localizationService = ref.read(
    localizationServiceProvider,
  );
  late final AIService _aiService = ref.read(aiServiceProvider);
  final TextEditingController _filterController = TextEditingController();
  String _filterQuery = '';

  List<ArbFile> _arbFiles = [];
  List<ArbComparison> _comparisons = [];
  List<String> _malformedArbFiles = [];
  bool _isLoading = false;
  String? _errorMessage;

  // Localization status
  LocalizationStatus _localizationStatus = LocalizationStatus.checking;

  // Latest file checks behind [_localizationStatus]
  LocalizationChecks _checks = LocalizationChecks.none;

  @override
  void initState() {
    super.initState();
    _filterController.addListener(_onFilterChanged);

    /// Handles `_checkLocalizationStatus`.
    _checkLocalizationStatus();

    /// Handles `_loadArbFiles`.
    _loadArbFiles();
  }

  @override
  void dispose() {
    _filterController.removeListener(_onFilterChanged);
    _filterController.dispose();
    super.dispose();
  }

  void _onFilterChanged() {
    setState(() {
      _filterQuery = _filterController.text.toLowerCase();
    });
  }

  /// Handles `_matchesFilter`.
  bool _matchesFilter(ArbComparison comparison, String query) {
    final lowerQuery = query.toLowerCase();

    // Check the key
    if (comparison.key.toLowerCase().contains(lowerQuery)) {
      return true;
    }

    // Check English value
    if (comparison.englishValue != null &&
        comparison.englishValue!.toLowerCase().contains(lowerQuery)) {
      return true;
    }

    // Check other translation values
    for (final value in comparison.otherValues.values) {
      if (value != null && value.toLowerCase().contains(lowerQuery)) {
        return true;
      }
    }

    return false;
  }

  /// Handles `_checkLocalizationStatus`.
  Future<void> _checkLocalizationStatus() async {
    final projectRoot = ref.read(currentProjectRootProvider);
    if (projectRoot == null) {
      setState(() => _localizationStatus = LocalizationStatus.noProject);
      return;
    }

    setState(() => _localizationStatus = LocalizationStatus.checking);

    try {
      final checks = await _localizationService.inspect(projectRoot.path);
      setState(() {
        _checks = checks;
        _localizationStatus = _statusFor(checks);
      });
    } catch (e) {
      setState(() => _localizationStatus = LocalizationStatus.error);
      _logger.severe('Error checking localization status: $e');
    }
  }

  /// Summarises [checks] as the status that picks which view to show.
  LocalizationStatus _statusFor(LocalizationChecks checks) {
    if (!checks.hasPubspec) return LocalizationStatus.noProject;
    if (!checks.isFlutterProject) return LocalizationStatus.notFlutterProject;
    if (checks.hasArbFiles &&
        checks.hasGeneratedClasses &&
        checks.hasAppIntegration) {
      return LocalizationStatus.complete;
    }
    if (checks.hasArbFiles || checks.hasGeneratedClasses) {
      return LocalizationStatus.partial;
    }
    return LocalizationStatus.notStarted;
  }

  /// Handles `_loadArbFiles`.
  Future<void> _loadArbFiles() async {
    final projectRoot = ref.read(currentProjectRootProvider);
    if (projectRoot == null) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _malformedArbFiles = [];
    });

    try {
      final arbFiles = await _arbService.loadArbFiles(
        ProjectPaths(projectRoot.path).l10nDir,
      );
      final validArbFiles = arbFiles.valid;
      final malformedFiles = arbFiles.malformed;

      final comparisons = _arbService.compareArbFiles(validArbFiles);

      setState(() {
        _arbFiles = validArbFiles;
        _comparisons = comparisons;
        _malformedArbFiles = malformedFiles;
        _isLoading = false;
      });

      // Update localization status after loading ARB files to ensure consistency
      await _checkLocalizationStatus();
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading ARB files: $e';
        _isLoading = false;
      });
    }
  }

  /// Handles `_initializeLocalization`.
  Future<void> _initializeLocalization() async {
    final projectRoot = ref.read(currentProjectRootProvider);
    if (projectRoot == null) return;

    setState(() => _isLoading = true);

    try {
      await _localizationService.initializeLocalization(
        projectRoot.path,
        onStep: (step) {
          if (mounted) MessageBox.showInfo(context, step);
        },
      );

      if (mounted) {
        MessageBox.showInfo(context, 'Updating main.dart...');
      }
      await _localizationService.updateMainDartForLocalization(
        projectRoot.path,
      );

      await _loadArbFiles();
      await _checkLocalizationStatus();

      if (mounted) {
        MessageBox.showSuccess(
          context,
          'Localization system initialized and main.dart updated successfully!',
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        MessageBox.showError(context, 'Error initializing localization: $e');
      }
    }
  }

  /// Handles `_updateMainDart`.
  Future<void> _updateMainDart() async {
    final projectRoot = ref.read(currentProjectRootProvider);
    if (projectRoot == null) return;

    setState(() => _isLoading = true);

    try {
      await _localizationService.updateMainDartForLocalization(
        projectRoot.path,
      );
      await _checkLocalizationStatus();

      if (mounted) {
        MessageBox.showSuccess(context, 'main.dart updated successfully!');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        MessageBox.showError(context, 'Error updating main.dart: $e');
      }
    }
  }

  /// Handles `_generateLocalizationClasses`.
  Future<void> _generateLocalizationClasses() async {
    final projectRoot = ref.read(currentProjectRootProvider);
    if (projectRoot == null) return;

    setState(() => _isLoading = true);

    try {
      final hasGenerateFlag = (await _localizationService.inspect(
        projectRoot.path,
      )).hasGenerateFlag;

      if (!hasGenerateFlag) {
        setState(() => _isLoading = false);
        if (mounted) {
          MessageBox.showError(
            context,
            'Cannot generate localization classes. Please ensure your pubspec.yaml has "generate: true" properly indented under the flutter section, run "flutter pub get", and restart your IDE. Example:\n\nflutter:\n  generate: true\n  uses-material-design: true',
          );
        }
        return;
      }

      await _localizationService.generateClasses(projectRoot.path);
      await _checkLocalizationStatus();
      if (mounted) {
        MessageBox.showSuccess(
          context,
          'Localization classes generated successfully!',
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        MessageBox.showError(context, 'Error generating classes: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final projectRoot = ref.watch(currentProjectRootProvider);

    if (projectRoot == null) {
      return const NoProjectPlaceholder();
    }

    if (_isLoading) {
      return const LoadingIndicator();
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_errorMessage!),
            const SizedBox(height: AppSpacing.xLarge),
            ElevatedButton(
              onPressed: _loadArbFiles,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    // Show status-based UI
    switch (_localizationStatus) {
      case LocalizationStatus.checking:
        return const LoadingIndicator();
      case LocalizationStatus.noProject:

        /// Handles `_buildStatusView`.
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
        return LocalizationSetupWidget(
          onInitializeLocalization: _initializeLocalization,
          showUpdateMainDart: false, // Not needed for initial setup
          onUpdateMainDart: _updateMainDart,
          isInitializing: _isLoading,
        );
      case LocalizationStatus.partial:

        /// Handles `_buildPartialView`.
        return _buildPartialView();
      case LocalizationStatus.complete:

        /// Handles `_buildCompleteView`.
        return _buildCompleteView();
      case LocalizationStatus.error:
        return _buildStatusView(
          'Error',
          'An error occurred while checking localization status.',
          Icons.error,
          action: ElevatedButton(
            onPressed: _checkLocalizationStatus,
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

  /// Handles `_buildPartialView`.
  Widget _buildPartialView() {
    final hasArbFiles = _checks.hasArbFiles;
    final hasValidArbFiles = _arbFiles.isNotEmpty;
    final hasGeneratedClasses = _checks.hasGeneratedClasses;
    final hasAppIntegration = _checks.hasAppIntegration;
    final hasLocalizationDependencies = _checks.hasDependencies;
    final hasFlutterGenerateFlag = _checks.hasGenerateFlag;

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
          /// Handles `_buildStatusCheck`.
          _buildStatusCheck(
            'Localization dependencies configured',
            hasLocalizationDependencies,
          ),
          _buildStatusCheck(
            'Flutter generate flag configured',
            hasFlutterGenerateFlag,
          ),
          _buildStatusCheck('ARB files exist', hasArbFiles),
          if (hasArbFiles) ...[
            hasValidArbFiles
                ? _buildStatusCheck('ARB files are valid JSON', true)
                /// Handles `_buildStatusCheckWithMalformedFiles`.
                : _buildStatusCheckWithMalformedFiles(
                    'ARB files are valid JSON',
                    _malformedArbFiles,
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
            /// Handles `_buildActionItem`.
            _buildActionItem(
              'Create ARB files',
              'Set up localization files with template content',
              Icons.file_copy,
              _initializeLocalization,
            ),
          ] else if (hasArbFiles && !hasValidArbFiles) ...[
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
          if (_arbFiles.isNotEmpty) ...[
            const SectionTitle('ARB File Management'),
            const SizedBox(height: AppSpacing.large),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _comparisons.length,
              itemBuilder: (_ /*context*/, index) {
                final comparison = _comparisons[index];

                /// Handles `_buildComparisonTile`.
                return _buildComparisonTile(comparison);
              },
            ),
          ],
        ],
      ),
    );
  }

  /// Handles `_buildCompleteView`.
  Widget _buildCompleteView() {
    // Filter comparisons based on filter query
    final filteredComparisons = _filterQuery.isEmpty
        ? _comparisons
        : _comparisons.where((comparison) {
            return _matchesFilter(comparison, _filterQuery);
          }).toList();

    // Find duplicate English values (2 or more occurrences)
    final englishValueCounts = <String, int>{};
    for (final comparison in filteredComparisons) {
      if (comparison.englishValue != null) {
        englishValueCounts[comparison.englishValue!] =
            (englishValueCounts[comparison.englishValue!] ?? 0) + 1;
      }
    }
    final duplicatedValues = englishValueCounts.entries
        .where((entry) => entry.value >= AppMetric.duplicateThreshold)
        .map((entry) => entry.key)
        .toSet();

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
          child: _arbFiles.isEmpty
              ? const EmptyState(message: 'No ARB files found')
              : ListView.separated(
                  itemCount: filteredComparisons.length,
                  itemBuilder: (_ /*context*/, index) {
                    final comparison = filteredComparisons[index];
                    final isDuplicated =
                        comparison.englishValue != null &&
                        duplicatedValues.contains(comparison.englishValue);
                    return LocalizationEntryWidget(
                      comparison: comparison,
                      showWarning: isDuplicated,
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
                  final fileName = p.basename(filePath);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.micro),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            fileName,
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

  /// Handles `_buildComparisonTile`.
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
                final targetFile = _arbFiles.firstWhere(
                  (file) => file.languageCode == lang,
                );
                return ElevatedButton.icon(
                  icon: const Icon(Icons.translate, size: AppIconSize.medium),
                  label: Text('Translate to $lang'),
                  onPressed: comparison.englishValue != null
                      ? () => _translateMissingKey(
                          comparison.key,
                          comparison.englishValue!,
                          lang,
                          targetFile.path,
                        )
                      : null,
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  /// Handles `_translateMissingKey`.
  Future<void> _translateMissingKey(
    String key,
    String englishValue,
    String targetLanguage,
    String targetFilePath,
  ) async {
    try {
      final prompt =
          '''
Translate the following English text to $targetLanguage:

"$englishValue"

Provide only the translated text, no additional explanation or quotes.''';

      final translation = await _aiService.getCodeSuggestion(prompt, '');

      if (translation.trim().isNotEmpty) {
        await _arbService.updateArbFile(
          targetFilePath,
          key,
          translation.trim(),
          metadata: {'description': 'Translated using AI'},
        );

        await _loadArbFiles();

        if (mounted) {
          MessageBox.showSuccess(
            context,
            'Translated "$key" to $targetLanguage',
          );
        }
      } else {
        if (mounted) {
          MessageBox.showError(context, 'Translation failed');
        }
      }
    } catch (e) {
      if (mounted) {
        MessageBox.showError(context, 'Error translating: $e');
      }
    }
  }
}
