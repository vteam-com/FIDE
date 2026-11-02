import 'package:fide/constants/constants.dart';
import 'package:fide/widgets/inline_spinner.dart';
import 'package:flutter/material.dart';

/// The filled button for the main action of a card, dialog or screen; pair
/// it with `SecondaryButton` for the other choices.
///
/// While [busy] it shows a spinner in place of its [icon] and ignores
/// presses; a [destructive] button is drawn in the error color.
class PrimaryButton extends StatelessWidget {
  /// Creates a button labelled [label].
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.busy = false,
    this.destructive = false,
  });

  /// Whether the button's work is in progress.
  final bool busy;

  /// Whether the action deletes or discards something.
  final bool destructive;

  /// Glyph before [label]; none when null.
  final IconData? icon;

  /// Button text.
  final String label;

  /// Called on press while idle; the button is disabled when null.
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final style = destructive
        ? FilledButton.styleFrom(
            backgroundColor: colorScheme.error,
            foregroundColor: colorScheme.onError,
          )
        : null;
    final onPressed = busy ? null : this.onPressed;
    final icon = this.icon;
    if (!busy && icon == null) {
      return FilledButton(
        onPressed: onPressed,
        style: style,
        child: Text(label),
      );
    }
    return FilledButton.icon(
      onPressed: onPressed,
      style: style,
      icon: busy
          ? const InlineSpinner(size: AppIconSize.medium)
          : Icon(icon, size: AppIconSize.medium),
      label: Text(label),
    );
  }
}
