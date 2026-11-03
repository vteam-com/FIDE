import 'package:fide/widgets/compact_icon_button.dart';
import 'package:fide/widgets/message_box.dart';
import 'package:flutter/material.dart';

/// The button copying [text] to the clipboard, then confirming it with
/// [confirmation]; every copy action looks and reads alike.
class CopyButton extends StatelessWidget {
  /// Creates the button copying [text].
  const CopyButton({
    super.key,
    required this.text,
    this.tooltip = defaultTooltip,
    this.confirmation = MessageBox.copiedConfirmation,
  });

  /// The confirmation shown once copied.
  final String confirmation;

  /// [tooltip] unless the copy needs naming, such as among several.
  static const String defaultTooltip = 'Copy to clipboard';

  /// The text copied.
  final String text;

  /// Hover text naming what is copied.
  final String tooltip;
  @override
  Widget build(BuildContext context) {
    return CompactIconButton(
      icon: Icons.copy,
      tooltip: tooltip,
      onPressed: () =>
          MessageBox.copyToClipboard(context, text, confirmation: confirmation),
    );
  }
}
