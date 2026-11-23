import 'package:fide/constants/constants.dart';
import 'package:fide/models/code_category.dart';
import 'package:fide/models/locale_number.dart';
import 'package:fide/models/repeated_settings_review.dart';
import 'package:fide/panels/right/analyzer_findings_list.dart';
import 'package:fide/providers/ai_request.dart';
import 'package:fide/providers/analyzer_fix_controller.dart';
import 'package:fide/providers/repeated_settings_review_provider.dart';
import 'package:fide/widget_services/file_location_row.dart';
import 'package:fide/widgets/action_card.dart';
import 'package:fide/widgets/blocking_task_dialog.dart';
import 'package:fide/widgets/code_category_icon.dart';
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
/// and where, in a view or a widget, a click away in the editor beside
/// the review, and the deterministic fixes code can make: Fix on a
/// finding, Fix All on a kind.
class RepeatedSettingsList
    extends
        AnalyzerFindingsList<
          RepeatedSettingsFindingKind,
          RepeatedSettingsFinding
        > {
  /// Creates the list of [review]'s findings.
  const RepeatedSettingsList({
    super.key,
    required super.projectPath,
    required this.review,
  });

  /// Fewest findings with a single fix for their section to offer Fix All.
  static const int minFixAll = 2;

  /// The review shown.
  final RepeatedSettingsReview review;

  /// [finding]'s card: its title, the fix it calls for with its
  /// [_actionsOf], why code can't fix it when it can't, and each way its
  /// code is written with where.
  @override
  Widget card(
    BuildContext context,
    WidgetRef ref,
    RepeatedSettingsFinding finding, {
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
            for (final location in variant.locations) _rowOf(location),
          ],
        ],
      ),
    );
  }

  /// The row of [location]: its class, else its file, with the glyph of
  /// the code it is in, a view's or a widget's, as File Layout's, said in
  /// its tooltip.
  Widget _rowOf(RepeatedSettingsLocation location) {
    final (kind, note) = location.isInView
        ? (CodeCategory.views, 'In a view')
        : (CodeCategory.widgets, 'In a widget');
    return FileLocationRow(
      name: location.className ?? p.basename(location.path),
      path: p.join(projectPath, location.path),
      line: location.line,
      rootPath: projectPath,
      icon: kind.icon,
      note: note,
    );
  }

  @override
  String describe(RepeatedSettingsFindingKind kind) => kind.description;

  @override
  String get emptyMessage => 'No repeated widget settings found';

  @override
  List<RepeatedSettingsFinding> findingsOf(RepeatedSettingsFindingKind kind) =>
      review.of(kind);

  @override
  List<RepeatedSettingsFindingKind> get kinds =>
      RepeatedSettingsFindingKind.values;

  /// The title of the section of [findings] of [kind], with Fix All when
  /// several of them have a single fix, one taking no choice; disabled
  /// while a fix is [running].
  @override
  Widget sectionTitle(
    BuildContext context,
    WidgetRef ref,
    RepeatedSettingsFindingKind kind,
    List<RepeatedSettingsFinding> findings, {
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
              label: 'Fix All',
              onPressed: running != null
                  ? null
                  : () => _fix(
                      context,
                      ref,
                      RepeatedSettingsFix.all('Fix All', fixes),
                      key: kind,
                    ),
            ),
    );
  }

  /// [finding]'s actions: a button per fix, or Ask AI when code can make
  /// none; the fixes disabled while one is [running].
  Widget _actionsOf(
    BuildContext context,
    WidgetRef ref,
    RepeatedSettingsFinding finding, {
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
            onPressed: running != null ? null : () => _fix(context, ref, fix),
          ),
      ],
    );
  }

  /// Makes [fix]'s edits, after asking the name of the widget it extracts
  /// when it does (a class name no file of the project sees yet), the app
  /// blocked meanwhile, then tells how it went; [key] names the button
  /// that started it, [fix] when null.
  Future<void> _fix(
    BuildContext context,
    WidgetRef ref,
    RepeatedSettingsFix fix, {
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
      final taken =
          ref.read(repeatedSettingsReviewProvider).value?.takenNames ??
          const {};
      if (RepeatedSettingsFix.nameError(name, taken) case final error?) {
        MessageBox.showError(context, error);
        return;
      }
      named = fix.named(name);
    }
    final outcome = await BlockingTaskDialog.run(
      context,
      title: fix.label,
      step: 'Rewriting ${fix.paths.length.count('file')}…',
      run: (task) => ref
          .read(analyzerFixControllerProvider.notifier)
          .fix(
            projectPath,
            named,
            key: key ?? fix,
            layers: review.graph,
            packageName: review.packageName,
            task: task,
          ),
    );
    if (context.mounted) MessageBox.showOutcome(context, outcome);
  }

  /// The glyph of findings of [kind].
  static IconData _iconOf(RepeatedSettingsFindingKind kind) => switch (kind) {
    RepeatedSettingsFindingKind.clone => Icons.copy_all_outlined,
    RepeatedSettingsFindingKind.drift => Icons.call_split,
    RepeatedSettingsFindingKind.sameEverywhere => Icons.palette_outlined,
    RepeatedSettingsFindingKind.literal => Icons.pin_outlined,
  };
}
