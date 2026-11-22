import 'package:fide/constants/constants.dart';
import 'package:fide/models/dry_review.dart';
import 'package:fide/models/locale_number.dart';
import 'package:fide/providers/ai_request.dart';
import 'package:fide/providers/analyzer_fix_controller.dart';
import 'package:fide/providers/dry_review_provider.dart';
import 'package:fide/panels/right/analyzer_findings_list.dart';
import 'package:fide/widget_services/file_location_row.dart';
import 'package:fide/widgets/action_card.dart';
import 'package:fide/widgets/message_box.dart';
import 'package:fide/widgets/primary_button.dart';
import 'package:fide/widgets/secondary_button.dart';
import 'package:fide/widgets/section_title.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;

/// The Repeated Widget Settings review of the project at [projectPath]:
/// the widget settings it writes more than once; each kind of repetition
/// with what to do about it, each finding with the code it is written as
/// and where, a click away in the editor beside the review, and the
/// deterministic fixes code can make: Fix on a finding, Fix all on a
/// kind.
class RepeatedSettingsList
    extends AnalyzerFindingsList<DryFindingKind, DryFinding> {
  /// Creates the list of [review]'s findings.
  const RepeatedSettingsList({
    super.key,
    required super.projectPath,
    required this.review,
  });

  /// Fewest findings with a single fix for their section to offer Fix all.
  static const int minFixAll = 2;

  /// The review shown.
  final DryReview review;

  /// [finding]'s card: its title, the fix it calls for with its
  /// [_actionsOf], why code can't fix it when it can't, and each way its
  /// code is written with where.
  @override
  Widget card(
    BuildContext context,
    WidgetRef ref,
    DryFinding finding, {
    required Object? running,
  }) {
    return ActionCard(
      action: _actionsOf(context, ref, finding, running: running),
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
              FileLocationRow(
                name: location.className ?? p.basename(location.path),
                path: p.join(projectPath, location.path),
                line: location.line,
                rootPath: projectPath,
              ),
          ],
        ],
      ),
    );
  }

  @override
  String describe(DryFindingKind kind) => kind.description;

  @override
  String get emptyMessage => 'No repeated widget settings found';

  @override
  List<DryFinding> findingsOf(DryFindingKind kind) => review.of(kind);

  @override
  List<DryFindingKind> get kinds => DryFindingKind.values;

  /// The title of the section of [findings] of [kind], with Fix all when
  /// several of them have a single fix, one taking no choice; disabled
  /// while a fix is [running], showing it running when it is its own.
  @override
  Widget sectionTitle(
    BuildContext context,
    WidgetRef ref,
    DryFindingKind kind,
    List<DryFinding> findings, {
    required Object? running,
  }) {
    final fixes = [
      for (final finding in findings)
        if (finding.fixes case [final fix] when fix.nameHint == null) fix,
    ];
    return SectionTitle(
      '${kind.label} (${findings.length})',
      action: fixes.length < minFixAll
          ? null
          : PrimaryButton(
              icon: AppIcon.fix,
              label: 'Fix all',
              busy: running == kind,
              onPressed: running != null
                  ? null
                  : () => _fix(
                      context,
                      ref,
                      DryFix.all('Fix all', fixes),
                      key: kind,
                    ),
            ),
    );
  }

  /// [finding]'s actions: a button per fix, or Ask AI when code can make
  /// none; the fixes disabled while one is [running], showing it running
  /// when it is their own.
  Widget _actionsOf(
    BuildContext context,
    WidgetRef ref,
    DryFinding finding, {
    required Object? running,
  }) {
    if (finding.fixes.isEmpty) {
      return SecondaryButton(
        icon: AppIcon.ai,
        label: 'Fix with AI',
        onPressed: () => ref.read(aiRequestsProvider).ask(finding.aiRequest),
      );
    }
    return Wrap(
      spacing: AppSpacing.medium,
      runSpacing: AppSpacing.small,
      children: [
        for (final fix in finding.fixes)
          PrimaryButton(
            icon: AppIcon.fix,
            label: fix.label,
            busy: identical(running, fix),
            onPressed: running != null ? null : () => _fix(context, ref, fix),
          ),
      ],
    );
  }

  /// Makes [fix]'s edits, after asking the name of the widget it extracts
  /// when it does (a class name no file of the project sees yet), then
  /// tells how it went; [key] names the button that started it, [fix]
  /// when null.
  Future<void> _fix(
    BuildContext context,
    WidgetRef ref,
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
      final taken = ref.read(dryReviewProvider).value?.takenNames ?? const {};
      if (DryFix.nameError(name, taken) case final error?) {
        MessageBox.showError(context, error);
        return;
      }
      named = fix.named(name);
    }
    final outcome = await ref
        .read(analyzerFixControllerProvider.notifier)
        .fix(projectPath, named, key: key ?? fix);
    if (context.mounted) MessageBox.showOutcome(context, outcome);
  }

  /// The glyph of findings of [kind].
  static IconData _iconOf(DryFindingKind kind) => switch (kind) {
    DryFindingKind.clone => Icons.copy_all_outlined,
    DryFindingKind.drift => Icons.call_split,
    DryFindingKind.sameEverywhere => Icons.palette_outlined,
    DryFindingKind.literal => Icons.pin_outlined,
  };
}
