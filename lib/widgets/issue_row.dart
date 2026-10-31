import 'package:fide/constants/constants.dart';
import 'package:fide/models/quality_issue.dart';
import 'package:fide/models/quality_issue.quality_finding.dart';
import 'package:fide/models/quick_fix.dart';
import 'package:fide/models/string_review.dart';
import 'package:fide/providers/ai_chat_notifier.dart';
import 'package:fide/providers/ai_request.dart';
import 'package:fide/providers/app_providers.dart';
import 'package:fide/providers/editor_navigation.dart';
import 'package:fide/providers/quick_fix_runner.dart';
import 'package:fide/widgets/clickable.dart';
import 'package:fide/widgets/compact_icon_button.dart';
import 'package:fide/widgets/markdown_text.dart';
import 'package:fide/widgets/message_box.dart';
import 'package:fide/widgets/section_title.dart';
import 'package:fide/widgets/status_indicator.dart';
import 'package:fide/widgets/string_review_dialog.dart';
import 'package:fide/widgets/tree_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

/// A [QualityIssue] as one line, the same in every panel: its label in
/// its tone's color and a How to fix button opening the best practice, the
/// findings, the issue's quick fixes and its AI action, such as Localize
/// with AI.
class IssueRow extends ConsumerWidget {
  /// Creates the row for [issue].
  const IssueRow(this.issue, {super.key});

  /// The issue shown.
  final QualityIssue issue;

  /// Label of the button reviewing hardcoded strings.
  static const String _reviewStringsLabel = 'Review strings';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showDetails = issue.hasDetails
        ? () => _showDetails(context, ref)
        : null;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Clickable(onTap: showDetails, child: _label()),
        ),
        if (showDetails != null)
          CompactIconButton(
            icon: Icons.lightbulb_outline,
            tooltip: 'How to fix',
            onPressed: showDetails,
          ),
      ],
    );
  }

  /// The issue's label in its tone's color.
  Widget _label() =>
      Text(issue.label, style: StatusIndicator.labelStyle(issue.tone.color));

  /// Applies [fix] to the open project after the user reviews it, or
  /// [apply] when given, reports the outcome and refreshes the project
  /// overview; a fix asking the model runs as a task in the AI panel, with
  /// its progress. Does nothing without a project.
  Future<void> _applyQuickFix(
    BuildContext context,
    WidgetRef ref,
    QuickFix fix, {
    Future<QuickFixOutcome> Function(QuickFixRunner)? apply,
  }) async {
    final projectPath = ref.read(currentProjectPathProvider);
    if (projectPath == null) return;
    // Read before the pauses: the calling widget may be gone after them
    final runner = ref.read(quickFixRunnerProvider);
    final openDocuments = ref.read(openDocumentsProvider.notifier);
    final chat = ref.read(aiChatProvider.notifier);
    final container = ProviderScope.containerOf(context);
    if (fix.usesAi && ref.read(aiChatProvider).isBusy) {
      MessageBox.showError(context, 'The AI is busy: wait for it or stop it');
      return;
    }

    // A fix asking the model runs as a task in the AI panel once confirmed
    var inChat = false;
    void showInChat() {
      if (!fix.usesAi || inChat) return;
      inChat = true;
      showAiPanel(ref);
      chat.beginTask(fix.label);
    }

    if (!fix.usesAi) MessageBox.showInfo(context, '${fix.label}…');
    try {
      final outcome =
          await (apply?.call(runner) ??
              runner.run(
                projectPath,
                fix,
                confirm: (fix, message) async {
                  final confirmed =
                      context.mounted &&
                      await MessageBox.confirm(
                        context,
                        title: fix.label,
                        message: message,
                        confirmLabel: fix.label,
                      );
                  if (confirmed) showInChat();
                  return confirmed;
                },
                onProgress: (step) => chat.addReply(step, isProgress: true),
              ));
      if (outcome == null) return;
      await openDocuments.reloadWritten(outcome.changedFiles);
      container.invalidate(projectOverviewProvider);
      if (inChat) {
        chat.endTask(outcome.summary);
      } else if (context.mounted) {
        MessageBox.showSuccess(context, outcome.summary);
      }
    } catch (e) {
      if (inChat) {
        chat.endTask('Error: $e');
      } else if (context.mounted) {
        MessageBox.showError(context, '${fix.label}: $e');
      }
    }
  }

  /// Shows the open project's hardcoded strings grouped by role and applies
  /// the fix the user picks, or has the AI rewrite fragments. Does nothing
  /// without a project.
  Future<void> _reviewStrings(BuildContext context, WidgetRef ref) async {
    final projectPath = ref.read(currentProjectPathProvider);
    if (projectPath == null) return;
    final runner = ref.read(quickFixRunnerProvider);
    MessageBox.showInfo(context, '$_reviewStringsLabel…');
    final StringReview review;
    try {
      review = await runner.reviewStrings(projectPath);
    } catch (e) {
      if (context.mounted) {
        MessageBox.showError(context, '$_reviewStringsLabel: $e');
      }
      return;
    }
    if (!context.mounted) return;
    final choice = await StringReviewDialog.show(
      context,
      review,
      onOpen: (string) => openFileAtLine(ref, string.path, string.line),
    );
    if (choice == null || !context.mounted) return;
    final fix = choice.fix;
    if (fix == null) {
      askAi(ref, review.aiRequest(choice.strings));
      return;
    }
    await _applyQuickFix(
      context,
      ref,
      fix,
      apply: (runner) => runner.applyStrings(review, fix, choice.strings),
    );
  }

  /// One finding, opening its file at its line when tapped.
  Widget _findingRow(
    BuildContext context,
    WidgetRef ref,
    QualityFinding finding,
  ) {
    return TreeRow(
      icon: Icon(
        issue.tone.icon,
        size: AppIconSize.small,
        color: issue.tone.color,
      ),
      name: finding.text,
      path: finding.path,
      rootPath: issue.rootPath,
      trailing: [
        Text(
          '${p.basename(finding.path)}:${finding.line}',
          style: AppTextStyle.secondary(context),
        ),
      ],
      onTap: () {
        Navigator.of(context).pop();
        openFileAtLine(ref, finding.path, finding.line);
      },
    );
  }

  /// The best practice fixing [issue] and its findings, with its AI
  /// action.
  Future<void> _showDetails(BuildContext context, WidgetRef ref) {
    final guidance = issue.guidance;
    final fixRequest = issue.fixRequest;
    final quickFixes = issue.quickFixes;
    return MessageBox.showDetails(
      context,
      title: _label(),
      content: SizedBox(
        width: AppSize.issueDetailsWidth,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: AppSpacing.large,
          children: [
            if (guidance != null) ...[
              const SectionTitle('Best practice'),
              MarkdownText(
                data: guidance,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ],
            if (issue.findings.isNotEmpty) ...[
              SectionTitle('Findings (${issue.findings.length})'),
              Text(
                'Tap a finding to open it in the editor.',
                style: AppTextStyle.secondary(context),
              ),
              Column(
                children: [
                  for (final finding in issue.findings)
                    _findingRow(context, ref, finding),
                ],
              ),
            ],
          ],
        ),
      ),
      actions: [
        // The string fixes are picked per string, grouped by role
        if (quickFixes.any((fix) => fix.stringRole != null))
          FilledButton.icon(
            icon: const Icon(Icons.checklist),
            label: const Text(_reviewStringsLabel),
            onPressed: () {
              Navigator.of(context).pop();
              _reviewStrings(context, ref);
            },
          ),
        for (final quickFix in quickFixes)
          if (quickFix.stringRole == null)
            FilledButton.icon(
              icon: Icon(quickFix.icon),
              label: Text(quickFix.label),
              onPressed: () {
                Navigator.of(context).pop();
                _applyQuickFix(context, ref, quickFix);
              },
            ),
        if (fixRequest != null)
          // Secondary to the instant quick fixes
          (quickFixes.isEmpty ? FilledButton.icon : OutlinedButton.icon)(
            icon: const Icon(Icons.auto_fix_high),
            label: Text(issue.aiActionLabel!),
            onPressed: () {
              Navigator.of(context).pop();
              askAi(ref, fixRequest);
            },
          ),
      ],
    );
  }
}
