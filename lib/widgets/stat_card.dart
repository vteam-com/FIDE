import 'package:fide/constants/constants.dart';
import 'package:fide/models/quality_issue.dart';
import 'package:fide/widgets/action_card.dart';
import 'package:fide/widgets/issue_row.dart';
import 'package:flutter/material.dart';

/// A fixed-width [ActionCard] headed by [icon] and [title], showing one
/// headline [value] over [issues], then [details].
class StatCard extends StatelessWidget {
  /// Creates the card.
  const StatCard({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    this.issues = const [],
    this.details = const [],
    this.action,
  });

  /// Button at the end of the card, such as one opening a review; none
  /// when null.
  final Widget? action;

  /// Smaller lines explaining [value].
  final List<String> details;

  /// Shown before [title].
  final IconData icon;

  /// Problems behind [value], each with how to fix it.
  final List<QualityIssue> issues;

  /// What the card measures.
  final String title;

  /// The headline figure; see [StatCard.text] for plain text.
  final Widget value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: AppSize.statCardWidth,
      child: ActionCard(
        title: title,
        icon: icon,
        action: action,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: AppSpacing.medium,
          children: [
            value,
            for (final issue in issues) IssueRow(issue),
            for (final detail in details)
              Text(detail, style: AppTextStyle.secondary(context)),
          ],
        ),
      ),
    );
  }

  /// [value] as headline text.
  static Widget text(String value) => Text(value, style: AppTextStyle.headline);
}
