import 'package:fide/constants/constants.dart';
import 'package:flutter/material.dart';

/// The face of a menu button: the current value [child] then a drop-down
/// arrow, so every "pick one" menu reads alike.
class DropdownLabel extends StatelessWidget {
  /// Creates the face showing [child].
  const DropdownLabel({super.key, required this.child});

  /// The current value, such as a project or file name; shortened when
  /// space runs out.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: AppSpacing.tiny,
      children: [
        Flexible(child: child),
        Icon(
          Icons.arrow_drop_down,
          size: AppIconSize.medium,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ],
    );
  }
}
