import 'package:fide/constants/constants.dart';
import 'package:fide/models/quality_issue.dart';
import 'package:fide/models/status_tone.dart';
import 'package:fide/widgets/issue_row.dart';
import 'package:fide/widgets/section_panel.dart';
import 'package:fide/widgets/status_indicator.dart';
import 'package:flutter/material.dart';

/// An expanded [SectionPanel] titled [title] listing [issues] as
/// [IssueRow]s, or [emptyLabel] as a success when there are none.
class IssueSection extends StatelessWidget {
  /// Creates the section listing [issues].
  const IssueSection({
    super.key,
    required this.title,
    required this.issues,
    required this.emptyLabel,
    this.rightWidget,
  });

  /// Shown as a success when [issues] is empty.
  final String emptyLabel;

  /// The issues listed.
  final List<QualityIssue> issues;

  /// Shown at the end of the header, such as a score.
  final Widget? rightWidget;

  /// The section heading.
  final String title;

  @override
  Widget build(BuildContext context) {
    return SectionPanel(
      title: title,
      isExpanded: true,
      rightWidget: rightWidget,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: AppSpacing.tiny,
        children: [
          if (issues.isEmpty)
            StatusIndicator.tone(StatusTone.success, label: emptyLabel),
          for (final issue in issues) IssueRow(issue),
        ],
      ),
    );
  }
}
