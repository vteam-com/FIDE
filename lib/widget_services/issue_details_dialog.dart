import 'package:fide/constants/constants.dart';
import 'package:fide/models/locale_number.dart';
import 'package:fide/models/quality_issue.dart';
import 'package:fide/models/quality_issue.quality_finding.dart';
import 'package:fide/models/quick_fix.dart';
import 'package:fide/models/status_tone.dart';
import 'package:fide/models/string_review.dart';
import 'package:fide/providers/ai_request.dart';
import 'package:fide/providers/editor_navigation.dart';
import 'package:fide/providers/quick_fix_controller.dart';
import 'package:fide/services/blocking_task.dart';
import 'package:fide/services/quick_fix_runner.dart';
import 'package:fide/theme/app_theme.dart';
import 'package:fide/widget_services/quick_fix_prompts.dart';
import 'package:fide/widgets/blocking_task_dialog.dart';
import 'package:fide/widgets/blocking_task_progress.dart';
import 'package:fide/widgets/location_row.dart';
import 'package:fide/widgets/markdown_text.dart';
import 'package:fide/widgets/primary_button.dart';
import 'package:fide/widgets/quick_fix_icon.dart';
import 'package:fide/widgets/secondary_button.dart';
import 'package:fide/widgets/section_title.dart';
import 'package:fide/widgets/status_indicator.dart';
import 'package:fide/widgets/string_review_dialog.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// A [QualityIssue]'s details, one dialog from the problem to its fix:
/// the best practice and the findings with the issue's quick fixes and AI
/// action; a quick fix pressed there runs in the dialog itself, blocking
/// the app as [BlockingTaskDialog] does, each finding ticked off as its
/// file is fixed, then the outcome in place of the progress, with Close.
class IssueDetailsDialog extends ConsumerStatefulWidget {
  /// Creates the details of [issue], titled [title].
  const IssueDetailsDialog({
    super.key,
    required this.issue,
    required this.title,
  });

  /// The issue shown.
  final QualityIssue issue;

  /// The issue's label, in its tone's color.
  final Widget title;

  @override
  ConsumerState<IssueDetailsDialog> createState() => _IssueDetailsDialogState();
}

class _IssueDetailsDialogState extends ConsumerState<IssueDetailsDialog> {
  /// The fix running or run in the dialog; null before one is pressed.
  BlockingTask? _task;

  /// Whether [_task] still runs.
  bool _running = false;

  /// How the fix ended, once it did.
  (String, StatusTone)? _outcome;

  @override
  void dispose() {
    _task?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final issue = widget.issue;
    final guidance = issue.guidance;
    final task = _task;
    return PopScope(
      canPop: !_running,
      child: AlertDialog(
        title: widget.title,
        content: SingleChildScrollView(
          child: SizedBox(
            width: AppSize.issueDetailsWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: AppSpacing.large,
              children: [
                if (task != null)
                  _status(task)
                else if (guidance != null) ...[
                  const SectionTitle('Best practice'),
                  MarkdownText(
                    data: guidance,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ],
                if (issue.findings.isNotEmpty) ..._findings(task),
              ],
            ),
          ),
        ),
        actions: _actions(task),
      ),
    );
  }

  /// The fix's progress while it runs, then how it ended.
  Widget _status(BlockingTask task) {
    final outcome = _outcome;
    if (outcome == null) return BlockingTaskProgress(task);
    final (message, tone) = outcome;
    return StatusIndicator.tone(tone, label: message);
  }

  /// The findings, ticked off by [task] once a fix runs.
  List<Widget> _findings(BlockingTask? task) {
    final findings = widget.issue.findings;
    if (task == null) {
      return [
        SectionTitle('Findings (${findings.length})'),
        Text(
          'Tap a finding to open it in the editor.',
          style: AppTextStyle.secondary(context),
        ),
        Column(children: [for (final f in findings) _findingRow(f, null)]),
      ];
    }
    return [
      ListenableBuilder(
        listenable: Listenable.merge([task.working, task.finished]),
        builder: (_, _) {
          final fixed = findings
              .where((f) => task.finished.value[f.path] ?? false)
              .length;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: AppSpacing.large,
            children: [
              SectionTitle(
                'Findings (${fixed.localized} of '
                '${findings.length.localized} fixed)',
              ),
              Column(
                children: [for (final f in findings) _findingRow(f, task)],
              ),
            ],
          );
        },
      ),
    ];
  }

  /// One finding, marked by [task] as fixed, left or being fixed once a
  /// fix runs; opens its file at its line when tapped, but while it runs.
  Widget _findingRow(QualityFinding finding, BlockingTask? task) {
    final issue = widget.issue;
    final state = task?.finished.value[finding.path];
    final icon = switch (state) {
      true => StatusIndicator.tone(StatusTone.success),
      false => StatusIndicator.tone(StatusTone.error),
      null when task?.working.value == finding.path => const StatusIndicator(
        icon: Icons.arrow_forward,
        color: AppTheme.infoColor,
      ),
      null => StatusIndicator.tone(issue.tone),
    };
    return LocationRow(
      icon: icon,
      name: finding.text,
      path: finding.path,
      line: finding.line,
      rootPath: issue.rootPath,
      onTap: _running
          ? null
          : () {
              Navigator.of(context).pop();
              openFileAtLine(ref, finding.path, finding.line);
            },
    );
  }

  /// Cancel while a fix runs, Close once it ended, else Close, the quick
  /// fixes and the AI action.
  List<Widget> _actions(BlockingTask? task) {
    if (task != null && _running) {
      return [
        SecondaryButton(
          label: 'Cancel',
          onPressed: task.isCancelled ? null : () => _cancel(task),
        ),
      ];
    }
    final close = SecondaryButton(
      label: 'Close',
      onPressed: () => Navigator.of(context).pop(),
    );
    if (task != null) return [close];
    final issue = widget.issue;
    final fixRequest = issue.fixRequest;
    final quickFixes = issue.quickFixes;
    return [
      close,
      // The string fixes are picked per string, grouped by role
      if (StringFix.anyIn(quickFixes))
        PrimaryButton(
          icon: Icons.checklist,
          label: QuickFixController.reviewStringsLabel,
          onPressed: _reviewStrings,
        ),
      for (final quickFix in quickFixes)
        if (StringFix.of(quickFix) == null)
          PrimaryButton(
            icon: quickFix.icon,
            label: quickFix.label,
            onPressed: () => _fix(quickFix),
          ),
      if (fixRequest != null)
        // Secondary to the instant quick fixes
        quickFixes.isEmpty
            ? PrimaryButton(
                icon: AppIcon.ai,
                label: issue.aiActionLabel!,
                onPressed: () => _askAi(fixRequest),
              )
            : SecondaryButton(
                icon: AppIcon.ai,
                label: issue.aiActionLabel!,
                onPressed: () => _askAi(fixRequest),
              ),
    ];
  }

  /// Runs [fix] in the dialog, pressing it having confirmed it; a fix
  /// asking the model runs as a task in the AI panel instead.
  Future<void> _fix(QuickFix fix) async {
    if (fix.usesAi) {
      final outer = Navigator.of(context).context;
      Navigator.of(context).pop();
      applyQuickFix(outer, ref, fix);
      return;
    }
    final task = BlockingTask(QuickFixRunner.analyzingStep, confirmed: true);
    setState(() {
      _task = task;
      _running = true;
    });
    await ref
        .read(quickFixControllerProvider)
        .apply(
          fix,
          confirm: (_, _) async => true,
          notify: (message, tone) => _outcome = (message, tone),
          block: (_, run) => run(task),
        );
    if (!mounted) return;
    setState(() {
      _running = false;
      _outcome ??= ('${fix.label}: nothing to do', StatusTone.info);
    });
  }

  /// Asks the running fix to stop after its current file.
  void _cancel(BlockingTask task) {
    task
      ..cancel()
      ..report(BlockingTaskDialog.cancellingStep);
    setState(() {});
  }

  /// Closes the dialog and has the user pick strings of the open project
  /// to fix in a [StringReviewDialog], then applies the fix they picked.
  void _reviewStrings() {
    final outer = Navigator.of(context).context;
    Navigator.of(context).pop();
    ref
        .read(quickFixControllerProvider)
        .reviewStrings(
          choose: (review) async => outer.mounted
              ? StringReviewDialog.show(
                  outer,
                  review,
                  onOpen: (string) =>
                      openFileAtLine(ref, string.path, string.line),
                )
              : null,
          confirm: confirmQuickFixOver(outer),
          notify: quickFixNoticesOver(outer),
          block: quickFixBlockerOver(outer),
        );
  }

  /// Closes the dialog and sends [request] to the AI panel.
  void _askAi(String request) {
    Navigator.of(context).pop();
    ref.read(aiRequestsProvider).ask(request);
  }
}
