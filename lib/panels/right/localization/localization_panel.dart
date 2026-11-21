// ignore_for_file: deprecated_member_use

import 'package:fide/constants/constants.dart';
import 'package:fide/models/action_outcome.dart';
import 'package:fide/models/language_catalog.dart';
import 'package:fide/models/locale_number.dart';
import 'package:fide/models/localization_data.dart';
import 'package:fide/models/localization_state.dart';
import 'package:fide/models/localization_status.dart';
import 'package:fide/models/quick_fix.dart';
import 'package:fide/models/status_tone.dart';
import 'package:fide/panels/right/localization/localization_entry_widget.dart';
import 'package:fide/panels/right/localization/localization_setup_widget.dart';
import 'package:fide/providers/app_providers.dart';
import 'package:fide/providers/localization_controller.dart';
import 'package:fide/providers/quick_fix_controller.dart';
import 'package:fide/providers/service_providers.dart';
import 'package:fide/services/arb_service.dart';
import 'package:fide/widget_services/file_action.dart';
import 'package:fide/widget_services/issue_section.dart';
import 'package:fide/widget_services/quick_fix_prompts.dart';
import 'package:fide/widgets/action_card.dart';
import 'package:fide/widgets/badge_status.dart';
import 'package:fide/widgets/bullet_list.dart';
import 'package:fide/widgets/compact_text_button.dart';
import 'package:fide/widgets/empty_state.dart';
import 'package:fide/widgets/filter_field.dart';
import 'package:fide/widgets/loading_indicator.dart';
import 'package:fide/widgets/locale_badges.dart';
import 'package:fide/widgets/message_box.dart';
import 'package:fide/widgets/no_project_placeholder.dart';
import 'package:fide/widgets/panel_scroll_view.dart';
import 'package:fide/widgets/path_text.dart';
import 'package:fide/widgets/primary_button.dart';
import 'package:fide/widgets/refresh_button.dart';
import 'package:fide/widgets/section_panel.dart';
import 'package:fide/widgets/section_title.dart';
import 'package:fide/widgets/status_indicator.dart';
import 'package:fide/widgets/status_tone_style.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;

/// Shows the open project's localization setup, locales and ARB keys,
/// rendering [localizationControllerProvider] and calling its actions.
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
  Future<void> _show(Future<ActionOutcome?> outcome) async {
    final result = await outcome;
    if (result == null || !mounted) return;
    MessageBox.showOutcome(context, result);
  }

  /// Sets localization up, showing each step as it starts.
  void _initializeLocalization() => _show(
    _controller.initialize(
      onStep: (step) {
        if (mounted) MessageBox.showInfo(context, step);
      },
    ),
  );

  /// Wires the generated localizations into the app widget.
  void _wireApp() => _show(_controller.wireApp());

  /// Runs `flutter gen-l10n`.
  void _generateLocalizationClasses() => _show(_controller.generateClasses());

  /// Adds [locale], then offers to translate its strings with the local
  /// model, as Translate with AI does.
  Future<void> _addLocale(String locale) async {
    final outcome = await _controller.addLocale(locale);
    if (outcome == null || !mounted) return;
    MessageBox.showOutcome(context, outcome);
    // Translate with AI, which fCheck's fresh analysis tells the keys to
    // translate, leaving out those marked not to be
    if (outcome.succeeded) applyQuickFix(context, ref, QuickFix.translateKeys);
  }

  /// Removes [locale] once the user confirms deleting its ARB file.
  Future<void> _removeLocale(String locale) async {
    final file = ref.read(localizationControllerProvider).arbFileOf(locale);
    if (file == null) return;
    final name = LanguageCatalog.nameOf(locale);
    final confirmed = await MessageBox.confirm(
      context,
      title: 'Remove $name',
      message:
          'Deletes ${p.basename(file.path)} and its '
          '${file.entries.length.count('translation')}, then generates the '
          'localization classes again: the app no longer supports $name. '
          'This cannot be undone.',
      confirmLabel: 'Remove',
    );
    if (confirmed && mounted) await _show(_controller.removeLocale(locale));
  }

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
      return EmptyState.error(message: loadError, child: _buildRetryButton());
    }

    final statusView = _buildStatusContent(state);
    final issues = ref.watch(stringIssuesProvider);
    final sections = [
      if (state.arbFiles.isNotEmpty) _localesSection(state),
      if (issues != null)
        IssueSection(
          title: 'Strings',
          issues: issues,
          emptyLabel: 'Every string is localized',
        ),
    ];
    if (sections.isEmpty) return statusView;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: AppPadding.panelContent,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: AppSpacing.sectionGap,
            children: sections,
          ),
        ),
        Expanded(child: statusView),
      ],
    );
  }

  /// The project's locales, the template's kept, the others removable,
  /// with a menu adding more.
  Widget _localesSection(LocalizationState state) {
    final locales = state.locales;
    return SectionPanel(
      title: 'Locales',
      isExpanded: true,
      count: locales.length,
      child: LocaleBadges(
        locales: locales,
        defaultLocale: state.templateLocale,
        onAdd: _addLocale,
        onRemove: _removeLocale,
      ),
    );
  }

  /// The view for [state]'s status.
  Widget _buildStatusContent(LocalizationState state) {
    switch (state.status) {
      case LocalizationStatus.checking:
        return const LoadingIndicator();
      case LocalizationStatus.noProject:
        return const NoProjectPlaceholder();
      case LocalizationStatus.notFlutterProject:
        return const EmptyState(
          icon: Icons.flutter_dash,
          title: 'Not a Flutter Project',
          message:
              'The loaded project does not appear to be a Flutter project.',
        );
      case LocalizationStatus.notStarted:
        return LocalizationSetupWidget(
          onInitializeLocalization: _initializeLocalization,
        );
      case LocalizationStatus.partial:
        return _buildPartialView(state);
      case LocalizationStatus.complete:
        return _buildCompleteView(state);
      case LocalizationStatus.error:
        return EmptyState.error(
          message: 'An error occurred while checking localization status.',
          child: _buildRetryButton(),
        );
    }
  }

  /// Checks the localization status again after a failure.
  Widget _buildRetryButton() {
    return RefreshButton(onPressed: _controller.reload);
  }

  /// The checklist and next step for a partly set up project.
  Widget _buildPartialView(LocalizationState state) {
    final checks = state.checks;
    if (checks == null) return const LoadingIndicator();
    final hasArbFiles = checks.hasArbFiles;
    final hasValidArbFiles = state.arbFiles.isNotEmpty;
    final hasGeneratedClasses = checks.hasGeneratedClasses;
    final hasAppIntegration = checks.hasAppIntegration;

    final hasEntries = state.arbFiles.isNotEmpty;
    final entry = _entryBuilder(state);
    return _entryList(
      hasEntries ? state.comparisons : const [],
      entry: entry,
      header: [
        const SectionTitle('Localization Partially Set Up'),
        Text(
          'Your Flutter project has some localization components set up, but others are missing. Localization requires three main components:',
          style: AppTextStyle.label,
        ),
        const BulletList([
          'ARB files (translation files in lib/l10n/)',
          'Generated AppLocalizations class',
          'Integration in the app widget',
        ]),
        Text('Here\'s the current status:', style: AppTextStyle.label),

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

        // Next Steps section
        const SectionTitle('Next Steps'),

        // Show specific actions based on what's missing
        if (!hasArbFiles) ...[
          LocalizationSetupWidget.initializeCard(_initializeLocalization),
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
            'Wire the app',
            'Add localization delegates and supported locales to the app widget, such as MaterialApp',
            Icons.code,
            _wireApp,
          ),
        ],

        // ARB file management, its entries following, if files are loaded
        if (hasEntries) const SectionTitle('ARB File Management'),
      ],
    );
  }

  /// [comparisons] as entries built by [entry], one divider apart and
  /// built as they scroll into view, however many keys the project has.
  /// With a [header], its sections come first and the whole list is laid
  /// out as [PanelScrollView] lays out a panel's sections: inset, one
  /// section gap apart, entries included.
  Widget _entryList(
    List<ArbComparison> comparisons, {
    required Widget Function(ArbComparison comparison) entry,
    List<Widget>? header,
  }) {
    final sections = header ?? const <Widget>[];
    final gap = header == null ? 0.0 : AppSpacing.sectionGap;
    return ListView.separated(
      padding: header == null ? null : AppPadding.panelContent,
      itemCount: sections.length + comparisons.length,
      itemBuilder: (_ /*context*/, index) => index < sections.length
          ? sections[index]
          : entry(comparisons[index - sections.length]),
      // Gaps between the sections and before the first entry, dividers
      // between the entries
      separatorBuilder: (_ /*context*/, index) => index < sections.length
          ? SizedBox(height: gap)
          : Padding(
              padding: EdgeInsets.symmetric(vertical: gap),
              child: const Divider(),
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
    final entry = _entryBuilder(state, duplicatedValues: duplicatedValues);

    return Column(
      children: [
        // Duplicate warning banner
        if (duplicatedValues.isNotEmpty)
          Padding(
            padding: AppPadding.panelContent,
            child: BadgeStatus.warning(
              text: duplicatedValues.length.count('duplicated English string'),
              showIcon: true,
            ),
          ),
        Expanded(
          child: state.arbFiles.isEmpty
              ? const EmptyState(message: 'No ARB files found')
              : _entryList(filteredComparisons, entry: entry),
        ),
        // Filter bar
        FilterField(
          controller: _filterController,
          hintText: 'Filter localization keys…',
        ),
      ],
    );
  }

  /// Builds the entry of each key of [state], with fCheck's untranslated
  /// locales, read now as list items build after this panel, and a
  /// Translate button for each; one whose template value is among
  /// [duplicatedValues] is flagged.
  Widget Function(ArbComparison comparison) _entryBuilder(
    LocalizationState state, {
    Set<String> duplicatedValues = const {},
  }) {
    final untranslated = ref.watch(untranslatedLocalesProvider);
    return (comparison) => LocalizationEntryWidget(
      comparison: comparison,
      templateLocale: state.templateLocale,
      untranslated: untranslated == null
          ? null
          : untranslated[comparison.key] ?? const {},
      showWarning: duplicatedValues.contains(comparison.englishValue),
      onTranslate: (locale) {
        if (_controller.translationOf(comparison, locale)
            case final translation?) {
          ref.read(quickFixControllerProvider).translate([
            translation,
          ], notify: quickFixNoticesOver(context));
        }
      },
    );
  }

  /// Handles `_buildStatusCheck`.
  Widget _buildStatusCheck(String label, bool isComplete) {
    return StatusIndicator.tone(
      isComplete ? StatusTone.success : StatusTone.warning,
      label: label,
    );
  }

  /// Handles `_buildStatusCheckWithMalformedFiles`.
  Widget _buildStatusCheckWithMalformedFiles(
    String label,
    List<String> malformedFiles,
  ) {
    return Column(
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
                  color: StatusTone.error.readableIn(
                    Theme.of(context).colorScheme,
                  ),
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
                            color: StatusTone.error.readableIn(
                              Theme.of(context).colorScheme,
                            ),
                          ),
                        ),
                      ),
                      CompactTextButton(
                        icon: FileAction.open.icon,
                        label: FileAction.open.labelIn(
                          ref.read(desktopShellProvider),
                        ),
                        onPressed: () =>
                            FileAction.open.run(context, ref, filePath),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  /// Handles `_buildActionItem`.
  Widget _buildActionItem(
    String title,
    String description,
    IconData icon,
    VoidCallback onPressed,
  ) {
    return ActionCard(
      title: title,
      icon: icon,
      description: description,
      action: PrimaryButton(
        icon: Icons.arrow_forward,
        label: 'Execute',
        onPressed: onPressed,
      ),
    );
  }
}
