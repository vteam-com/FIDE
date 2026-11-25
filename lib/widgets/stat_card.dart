import 'package:fide/constants/constants.dart';
import 'package:fide/widgets/section_panel.dart';
import 'package:material_ui/material_ui.dart';

/// A measure of the project, laid out by a `CardGrid` or stacked in a side
/// panel: the same collapsible [SectionPanel] box as every section,
/// headed by [icon] and [title], showing one headline [value] over
/// [rows], then [details] and [action]; expanded at first.
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
    final action = this.action;
    return SectionPanel(
      title: title,
      icon: icon,
      isExpanded: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: AppSpacing.medium,
        children: [
          value,
          ...rows,
          for (final detail in details)
            Text(detail, style: AppTextStyle.secondary(context)),
          if (action != null)
            Align(alignment: Alignment.centerRight, child: action),
        ],
      ),
    );
  }

  /// [value] as headline text.
  static Widget text(String value) => Text(value, style: AppTextStyle.headline);
}
