import 'package:fide/constants/constants.dart';
import 'package:flutter/material.dart';

/// The vertical three-dot button on a selected row, opening its context
/// menu at the tap position.
class MoreMenuButton extends StatelessWidget {
  /// Creates a button calling [onPressed] with the tap's global position.
  const MoreMenuButton({super.key, required this.onPressed});

  /// Opens the menu at the given global position.
  final ValueChanged<Offset> onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (details) => onPressed(details.globalPosition),
      child: Container(
        width: AppSize.compactContextButton,
        height: AppSize.compactContextButton,
        alignment: Alignment.center,
        child: Icon(
          Icons.more_vert,
          size: AppIconSize.small,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  /// Where `showMenu` places a menu opened at global [position].
  static RelativeRect menuPosition(Offset position) =>
      RelativeRect.fromLTRB(position.dx, position.dy, position.dx, position.dy);
}
