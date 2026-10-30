import 'package:fide/constants/constants.dart';
import 'package:fide/models/quality_issue.dart';
import 'package:fide/models/quality_issue.quality_finding.dart';
import 'package:fide/providers/ai_request.dart';
import 'package:fide/providers/editor_navigation.dart';
import 'package:fide/widgets/clickable.dart';
import 'package:fide/widgets/compact_icon_button.dart';
import 'package:fide/widgets/markdown_text.dart';
import 'package:fide/widgets/message_box.dart';
import 'package:fide/widgets/section_title.dart';
import 'package:fide/widgets/status_indicator.dart';
import 'package:fide/widgets/tree_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

/// A [QualityIssue] as one line, the same in every panel: its tone and
/// label, a How to fix button opening the best practice and findings, and
/// a Fix with AI button.
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
    final fixRequest = issue.fixRequest;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Clickable(
            onTap: showDetails,
            child: StatusIndicator.tone(issue.tone, label: issue.label),
          ),
        ),
        if (showDetails != null)
          CompactIconButton(
            icon: Icons.lightbulb_outline,
            tooltip: 'How to fix',
            onPressed: showDetails,
          ),
        if (fixRequest != null)
          CompactIconButton(
            icon: Icons.auto_fix_high,
            tooltip: 'Fix with AI',
            onPressed: () => askAi(ref, fixRequest),
          ),
      ],
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

  /// The best practice fixing [issue] and its findings, with a Fix with AI
  /// action.
  Future<void> _showDetails(BuildContext context, WidgetRef ref) {
    final guidance = issue.guidance;
    final fixRequest = issue.fixRequest;
    return MessageBox.showDetails(
      context,
      title: StatusIndicator.tone(issue.tone, label: issue.label),
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
        if (fixRequest != null)
          FilledButton.icon(
            icon: const Icon(Icons.auto_fix_high),
            label: const Text('Fix with AI'),
            onPressed: () {
              Navigator.of(context).pop();
              askAi(ref, fixRequest);
            },
          ),
      ],
    );
  }
}
