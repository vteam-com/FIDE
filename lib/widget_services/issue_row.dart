import 'package:fide/models/quality_issue.dart';
import 'package:fide/widget_services/issue_details_dialog.dart';
import 'package:fide/widgets/clickable.dart';
import 'package:fide/widgets/compact_icon_button.dart';
import 'package:fide/widgets/status_indicator.dart';
import 'package:fide/widgets/status_tone_style.dart';
import 'package:material_ui/material_ui.dart';

/// A [QualityIssue] as one line, the same in every panel: its label in
/// its tone's color and a How to fix button opening the best practice, the
/// findings, the issue's quick fixes and its AI action, such as Localize
/// with AI.
class IssueRow extends StatelessWidget {
  /// Creates the row for [issue].
  const IssueRow(this.issue, {super.key});

  /// The issue shown.
  final QualityIssue issue;
  @override
  Widget build(BuildContext context) {
    final showDetails = issue.hasDetails ? () => _showDetails(context) : null;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Clickable(onTap: showDetails, child: _label(context)),
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

  /// One row per issue of [issues], in their order.
  static List<IssueRow> all(List<QualityIssue> issues) => [
    for (final issue in issues) IssueRow(issue),
  ];

  /// The issue's label in its tone's color.
  Widget _label(BuildContext context) => Text(
    issue.label,
    style: StatusIndicator.labelStyle(
      issue.tone.color,
      Theme.of(context).colorScheme,
    ),
  );

  /// The best practice fixing [issue], its findings and its fixes, which
  /// run in the same dialog.
  Future<void> _showDetails(BuildContext context) => showDialog<void>(
    context: context,
    builder: (_) => IssueDetailsDialog(issue: issue, title: _label(context)),
  );
}
