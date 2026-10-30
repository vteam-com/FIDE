import 'package:fide/constants/constants.dart';
import 'package:fide/models/app_theme.dart';
import 'package:fide/models/status_tone.dart';
import 'package:fide/widgets/action_card.dart';
import 'package:fide/widgets/status_indicator.dart';
import 'package:flutter/material.dart';

/// A fixed-width [ActionCard] headed by [icon] and [title], showing one
/// headline [value] over [warnings], then [details].
class StatCard extends StatelessWidget {
  /// Creates the card.
  const StatCard({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    this.warnings = const [],
    this.details = const [],
  });

  /// Smaller lines explaining [value].
  final List<String> details;

  /// Shown before [title].
  final IconData icon;

  /// What the card measures.
  final String title;

  /// The headline figure; see [StatCard.text] for plain text.
  final Widget value;

  /// Problems behind [value], shown as warnings.
  final List<String> warnings;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: AppSize.statCardWidth,
      child: ActionCard(
        title: title,
        icon: icon,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: AppSpacing.medium,
          children: [
            value,
            for (final warning in warnings)
              StatusIndicator.tone(StatusTone.warning, label: warning),
            for (final detail in details)
              Text(detail, style: AppTheme.secondaryText(context)),
          ],
        ),
      ),
    );
  }

  /// [value] as headline text.
  static Widget text(BuildContext context, String value) =>
      Text(value, style: Theme.of(context).textTheme.headlineMedium);
}
