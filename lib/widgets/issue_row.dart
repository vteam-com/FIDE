import 'package:fide/constants/constants.dart';
import 'package:fide/models/quality_issue.dart';
import 'package:fide/models/quality_issue.quality_finding.dart';
import 'package:fide/models/status_tone.dart';
import 'package:fide/models/string_review.dart';
import 'package:fide/providers/ai_request.dart';
import 'package:fide/providers/editor_navigation.dart';
import 'package:fide/providers/quick_fix_controller.dart';
import 'package:fide/services/quick_fix_runner.dart';
import 'package:fide/widgets/clickable.dart';
import 'package:fide/widgets/compact_icon_button.dart';
import 'package:fide/widgets/markdown_text.dart';
import 'package:fide/widgets/message_box.dart';
import 'package:fide/widgets/path_text.dart';
import 'package:fide/widgets/quick_fix_icon.dart';
import 'package:fide/widgets/section_title.dart';
import 'package:fide/widgets/status_indicator.dart';
import 'package:fide/widgets/status_tone_style.dart';
import 'package:fide/widgets/string_review_dialog.dart';
import 'package:fide/widgets/tree_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A [QualityIssue] as one line, the same in every panel: its label in
/// its tone's color and a How to fix button opening the best practice, the
/// findings, the issue's quick fixes and its AI action, such as Localize
/// with AI.
class IssueRow extends ConsumerWidget {
  /// Creates the row for [issue].
  const IssueRow(this.issue, {super.key});

  /// The issue shown.
  final QualityIssue issue;

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

  /// Asks the user to confirm a quick fix in a dialog over [context];
  /// false once the row is gone.
  static QuickFixConfirmation _confirm(BuildContext context) =>
      (fix, message) async =>
          context.mounted &&
          await MessageBox.confirm(
            context,
            title: fix.label,
            message: message,
            confirmLabel: fix.label,
          );

  /// Shows a quick fix's messages over [context] while the row is there.
  static QuickFixNotice _notify(BuildContext context) => (message, tone) {
    if (!context.mounted) return;
    final show = switch (tone) {
      StatusTone.error => MessageBox.showError,
      StatusTone.success => MessageBox.showSuccess,
      StatusTone.warning => MessageBox.showWarning,
      StatusTone.info || StatusTone.neutral => MessageBox.showInfo,
    };
    show(context, message);
  };

  /// Has the user pick strings of the open project to fix in a
  /// [StringReviewDialog], then applies the fix they picked.
  void _reviewStrings(BuildContext context, WidgetRef ref) {
    ref
        .read(quickFixControllerProvider)
        .reviewStrings(
          choose: (review) async => context.mounted
              ? StringReviewDialog.show(
                  context,
                  review,
                  onOpen: (string) =>
                      openFileAtLine(ref, string.path, string.line),
                )
              : null,
          confirm: _confirm(context),
          notify: _notify(context),
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
        PathText(
          finding.path,
          line: finding.line,
          showFolder: false,
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
        if (quickFixes.any((fix) => StringFix.of(fix) != null))
          FilledButton.icon(
            icon: const Icon(Icons.checklist),
            label: const Text(QuickFixController.reviewStringsLabel),
            onPressed: () {
              Navigator.of(context).pop();
              _reviewStrings(context, ref);
            },
          ),
        for (final quickFix in quickFixes)
          if (StringFix.of(quickFix) == null)
            FilledButton.icon(
              icon: Icon(quickFix.icon),
              label: Text(quickFix.label),
              onPressed: () {
                Navigator.of(context).pop();
                ref
                    .read(quickFixControllerProvider)
                    .apply(
                      quickFix,
                      confirm: _confirm(context),
                      notify: _notify(context),
                    );
              },
            ),
        if (fixRequest != null)
          // Secondary to the instant quick fixes
          (quickFixes.isEmpty ? FilledButton.icon : OutlinedButton.icon)(
            icon: const Icon(Icons.auto_fix_high),
            label: Text(issue.aiActionLabel!),
            onPressed: () {
              Navigator.of(context).pop();
              ref.read(aiRequestsProvider).ask(fixRequest);
            },
          ),
      ],
    );
  }
}
