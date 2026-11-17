import 'package:fide/constants/constants.dart';
import 'package:fide/models/dry_review.dart';
import 'package:fide/models/locale_number.dart';
import 'package:fide/providers/ai_request.dart';
import 'package:fide/providers/app_providers.dart';
import 'package:fide/providers/dry_fix_controller.dart';
import 'package:fide/providers/dry_review_provider.dart';
import 'package:fide/providers/editor_navigation.dart';
import 'package:fide/widgets/action_card.dart';
import 'package:fide/widgets/empty_state.dart';
import 'package:fide/widgets/file_icon_utils.dart';
import 'package:fide/widgets/location_row.dart';
import 'package:fide/widgets/message_box.dart';
import 'package:fide/widgets/no_project_placeholder.dart';
import 'package:fide/widgets/panel_header.dart';
import 'package:fide/widgets/panel_scroll_view.dart';
import 'package:fide/widgets/primary_button.dart';
import 'package:fide/widgets/project_analysis_view.dart';
import 'package:fide/widgets/refresh_button.dart';
import 'package:fide/widgets/secondary_button.dart';
import 'package:fide/widgets/section_title.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;

/// The Analyzer tab: the DRY Review of the open project, the widget
/// settings it repeats ("Don't Repeat Yourself"); each kind of repetition
/// with what to do about it, each finding with the code it is written as
/// and where, a click away in the editor beside the review, and the
/// deterministic fixes code can make: Fix on a finding, Fix all on a
/// kind.
class AnalyzerPanel extends ConsumerWidget {
  /// Creates the review of the open project.
  const AnalyzerPanel({super.key});

  /// The review's name, atop the tab.
  static const String title = 'DRY Review';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectPath = ref.watch(currentProjectPathProvider);
    if (projectPath == null) return const NoProjectPlaceholder();
    final analysis = ref.watch(dryReviewProvider);
    final review = analysis.value;
    final running = ref.watch(dryFixControllerProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PanelHeader(
          title: title,
          subtitle: review == null
              ? null
              : '${review.findings.length.count('finding')} in '
                    '${review.fileCount.count('file')}',
          actions: [
            RefreshButton(
              busy: analysis.isLoading,
              onPressed: () => ref.invalidate(dryReviewProvider),
            ),
          ],
        ),
        Expanded(
          child: ProjectAnalysisView(
            analysis: analysis,
            loadingMessage: 'Comparing the widgets of lib…',
            builder: (review) => review == null || review.findings.isEmpty
                ? const EmptyState(
                    icon: Icons.check_circle_outline,
                    message: 'No repeated widget settings found',
                  )
                : PanelScrollView(
                    children: [
                      for (final kind in DryFindingKind.values)
                        if (review.of(kind) case final findings
                            when findings.isNotEmpty) ...[
                          _sectionTitle(
                            context,
                            ref,
                            projectPath,
                            kind,
                            findings,
                            running: running,
                          ),
                          Text(
                            kind.description,
                            style: AppTextStyle.secondary(context),
                          ),
                          for (final finding in findings)
                            _findingCard(
                              context,
                              ref,
                              projectPath,
                              finding,
                              running: running,
                            ),
                        ],
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  /// The title of the section of [findings] of [kind], with Fix all when
  /// several of them have a single fix, one taking no choice; disabled
  /// while a fix is [running], showing it running when it is its own.
  Widget _sectionTitle(
    BuildContext context,
    WidgetRef ref,
    String projectPath,
    DryFindingKind kind,
    List<DryFinding> findings, {
    required Object? running,
  }) {
    final title = '${kind.label} (${findings.length})';
    final fixes = [
      for (final finding in findings)
        if (finding.fixes case [final fix] when fix.nameHint == null) fix,
    ];
    if (fixes.length < minFixAll) return SectionTitle(title);
    return Row(
      children: [
        Expanded(child: SectionTitle(title)),
        PrimaryButton(
          icon: Icons.auto_fix_high,
          label: 'Fix all',
          busy: running == kind,
          onPressed: running != null
              ? null
              : () => _fix(
                  context,
                  ref,
                  projectPath,
                  DryFix.all('Fix all', fixes),
                  key: kind,
                ),
        ),
      ],
    );
  }

  /// Fewest findings with a single fix for their section to offer Fix all.
  static const int minFixAll = 2;

  /// A Dart class name: `CenterRightFittedBox`.
  static final RegExp _className = RegExp(r'^[A-Z][A-Za-z0-9]*$');

  /// Makes [fix]'s edits, after asking the name of the widget it extracts
  /// when it does (a class name no file of the project sees yet), then
  /// tells how it went; [key] names the button that started it, [fix]
  /// when null.
  static Future<void> _fix(
    BuildContext context,
    WidgetRef ref,
    String projectPath,
    DryFix fix, {
    Object? key,
  }) async {
    var named = fix;
    if (fix.nameHint case final hint?) {
      final name = await MessageBox.promptForText(
        context,
        title: 'Extract Widget',
        labelText: 'Widget name',
        hintText: hint,
        initialText: hint,
        confirmLabel: 'Extract',
      );
      if (name == null || name.isEmpty || !context.mounted) return;
      if (!_className.hasMatch(name)) {
        MessageBox.showError(context, '$name is not a class name');
        return;
      }
      final taken = ref.read(dryReviewProvider).value?.takenNames ?? const {};
      if (taken.contains(name)) {
        MessageBox.showError(context, '$name is taken: pick another name');
        return;
      }
      named = fix.named(name);
    }
    final outcome = await ref
        .read(dryFixControllerProvider.notifier)
        .fix(projectPath, named, key: key ?? fix);
    if (context.mounted) MessageBox.showOutcome(context, outcome);
  }

  /// [finding]'s actions: a button per fix, or Ask AI when code can make
  /// none; the fixes disabled while one is [running], showing it running
  /// when it is their own.
  Widget _actionsOf(
    BuildContext context,
    WidgetRef ref,
    String projectPath,
    DryFinding finding, {
    required Object? running,
  }) {
    if (finding.fixes.isEmpty) {
      return SecondaryButton(
        icon: Icons.auto_awesome,
        label: 'Ask AI',
        onPressed: () => ref.read(aiRequestsProvider).ask(finding.aiRequest),
      );
    }
    return Wrap(
      spacing: AppSpacing.medium,
      runSpacing: AppSpacing.small,
      children: [
        for (final fix in finding.fixes)
          PrimaryButton(
            icon: Icons.auto_fix_high,
            label: fix.label,
            busy: identical(running, fix),
            onPressed: running != null
                ? null
                : () => _fix(context, ref, projectPath, fix),
          ),
      ],
    );
  }

  /// [finding]'s card: its title, the fix it calls for with its
  /// [_actionsOf], why code can't fix it when it can't, and each way its
  /// code is written with where.
  Widget _findingCard(
    BuildContext context,
    WidgetRef ref,
    String projectPath,
    DryFinding finding, {
    required Object? running,
  }) {
    return ActionCard(
      action: _actionsOf(context, ref, projectPath, finding, running: running),
      icon: _iconOf(finding.kind),
      title: finding.title,
      description:
          '${finding.locationCount.count('place')} in '
          '${finding.fileCount.count('file')}'
          '${finding.suggestion == null ? '' : ': ${finding.suggestion}'}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: AppSpacing.small,
        children: [
          if (finding.fixes.isEmpty)
            Text(finding.kind.noFix, style: AppTextStyle.secondary(context)),
          for (final variant in finding.variants) ...[
            SelectableText(variant.source, style: AppTextStyle.code),
            for (final location in variant.locations)
              _locationRow(ref, projectPath, location),
          ],
        ],
      ),
    );
  }

  /// The row of [location], opening its file at its line when tapped.
  Widget _locationRow(WidgetRef ref, String projectPath, DryLocation location) {
    final path = p.join(projectPath, location.path);
    return LocationRow(
      icon: FileIconUtils.ofPath(path),
      name: location.className ?? p.basename(path),
      path: path,
      line: location.line,
      rootPath: projectPath,
      onTap: () => openFileAtLine(ref, path, location.line),
    );
  }

  /// The glyph of findings of [kind].
  static IconData _iconOf(DryFindingKind kind) => switch (kind) {
    DryFindingKind.clone => Icons.copy_all_outlined,
    DryFindingKind.drift => Icons.call_split,
    DryFindingKind.sameEverywhere => Icons.palette_outlined,
    DryFindingKind.literal => Icons.pin_outlined,
  };
}
