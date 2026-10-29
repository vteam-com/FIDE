import 'package:fide/constants/constants.dart';
import 'package:fide/widgets/inline_spinner.dart';
import 'package:flutter/material.dart';

/// An icon button that shows a spinner instead of its icon, and ignores
/// presses, while [busy].
class BusyIconButton extends StatelessWidget {
  /// Creates a button labelled [label] with [icon].
  const BusyIconButton({
    super.key,
    required this.busy,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.style,
  });

  /// Whether the button's work is in progress.
  final bool busy;

  /// Icon shown while idle.
  final IconData icon;

  /// Button text.
  final String label;

  /// Called on press while idle.
  final VoidCallback onPressed;

  /// Button style.
  final ButtonStyle? style;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: busy ? null : onPressed,
      icon: busy
          ? const InlineSpinner(size: AppIconSize.medium)
          : Icon(icon, size: AppIconSize.medium),
      label: Text(label),
      style: style,
    );
  }
}
