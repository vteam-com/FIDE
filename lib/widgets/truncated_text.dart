import 'package:material_ui/material_ui.dart';

/// [text] on one line, cut short with an ellipsis when too long, showing
/// in full on a lingering hover, such as a value in a details list or a
/// model name in a narrow header.
class TruncatedText extends StatelessWidget {
  /// Creates the line of [text] in [style].
  const TruncatedText(this.text, {super.key, required this.style});

  /// The style of the line.
  final TextStyle style;

  /// The text shown.
  final String text;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: text,
      child: Text(
        text,
        style: style,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
