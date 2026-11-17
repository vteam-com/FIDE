import 'package:fide/constants/constants.dart';
import 'package:material_ui/material_ui.dart';

/// The heading of a section of a panel, card or form step.
class SectionTitle extends StatelessWidget {
  /// Creates the heading [text].
  const SectionTitle(this.text, {super.key});

  /// Every section heading's style, also the title of a `SectionPanel`:
  /// as large as the panels' rows, set apart by its weight.
  static const TextStyle style = AppTextStyle.bodyStrong;

  /// The heading.
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: style);
  }
}
