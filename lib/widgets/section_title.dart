import 'package:fide/constants/constants.dart';
import 'package:material_ui/material_ui.dart';

/// The heading of a section of a panel, card or form step, with the
/// [action] that applies to the whole section at its end, if any.
class SectionTitle extends StatelessWidget {
  /// Creates the heading [text].
  const SectionTitle(this.text, {super.key, this.action});

  /// The button acting on the whole section, such as Fix All; none when
  /// null.
  final Widget? action;

  /// Every section heading's style, also the title of a `SectionPanel`:
  /// as large as the panels' rows, set apart by its weight.
  static const TextStyle style = AppTextStyle.bodyStrong;

  /// The heading.
  final String text;

  @override
  Widget build(BuildContext context) {
    final heading = Text(text, style: style);
    final action = this.action;
    if (action == null) return heading;
    return Row(
      children: [
        Expanded(child: heading),
        action,
      ],
    );
  }
}
