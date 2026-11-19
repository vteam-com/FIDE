import 'package:fide/constants/constants.dart';
import 'package:fide/widgets/detail_row.dart';
import 'package:fide/widgets/section_title.dart';
import 'package:material_ui/material_ui.dart';

/// A titled group of facts: [title] as a [SectionTitle], then its [rows]
/// one under the other, so every list of details reads alike.
class DetailSection extends StatelessWidget {
  /// Creates the group [title] of [rows].
  const DetailSection(this.title, this.rows, {super.key});

  /// The facts, one per line.
  final List<DetailRow> rows;

  /// What the facts are about.
  final String title;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AppSpacing.small,
      children: [
        SectionTitle(title),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: AppSpacing.micro,
          children: rows,
        ),
      ],
    );
  }
}
