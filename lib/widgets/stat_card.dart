import 'package:fide/constants/constants.dart';
import 'package:fide/widgets/action_card.dart';
import 'package:material_ui/material_ui.dart';

/// An [ActionCard], laid out by a `CardGrid`, headed by [icon] and [title], showing one
/// headline [value] over [rows], then [details].
class StatCard extends StatelessWidget {
  /// Creates the card.
  const StatCard({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    this.rows = const [],
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

  /// Lines explaining [value], such as the `IssueRow`s of the problems
  /// behind it.
  final List<Widget> rows;

  /// What the card measures.
  final String title;

  /// The headline figure; see [StatCard.text] for plain text.
  final Widget value;

  @override
  Widget build(BuildContext context) {
    return ActionCard(
      title: title,
      icon: icon,
      action: action,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: AppSpacing.medium,
        children: [
          value,
          ...rows,
          for (final detail in details)
            Text(detail, style: AppTextStyle.secondary(context)),
        ],
      ),
    );
  }

  /// [value] as headline text.
  static Widget text(String value) => Text(value, style: AppTextStyle.headline);
}
