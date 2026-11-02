import 'package:fide/constants/constants.dart';
import 'package:flutter/material.dart';

/// The outlined button for the other choices next to a `PrimaryButton`,
/// such as Cancel or Close, or for an optional action of a card.
class SecondaryButton extends StatelessWidget {
  /// Creates a button labelled [label].
  const SecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });

  /// Glyph before [label]; none when null.
  final IconData? icon;

  /// Button text.
  final String label;

  /// Called on press; the button is disabled when null.
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final icon = this.icon;
    if (icon == null) {
      return OutlinedButton(onPressed: onPressed, child: Text(label));
    }
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: AppIconSize.medium),
      label: Text(label),
    );
  }
}
