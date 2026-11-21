import 'package:fide/models/project_quality.dart';
import 'package:fide/widget_services/issue_row.dart';
import 'package:fide/widgets/badge_status.dart';
import 'package:fide/widgets/stat_card.dart';
import 'package:material_ui/material_ui.dart';

/// The open project's [quality], the same card on every surface showing
/// it, the project overview and the Info tab: its score over the issues
/// behind it, or what a clean score means.
class ProjectQualityCard extends StatelessWidget {
  /// Creates the card showing [quality].
  const ProjectQualityCard(this.quality, {super.key});

  /// The score and issues shown.
  final ProjectQuality quality;

  @override
  Widget build(BuildContext context) {
    final issues = quality.issues;
    return StatCard(
      icon: Icons.verified_outlined,
      title: 'Quality',
      value: BadgeStatus.score(quality.score, large: true),
      rows: IssueRow.all(issues),
      details: [
        if (issues.isEmpty)
          'Every fCheck analyzer at 100%, nothing from dart analyze nor the '
              'color contrast check',
      ],
    );
  }
}
