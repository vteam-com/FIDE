import 'package:fide/widgets/icon_menu_row.dart';
import 'package:flutter/material.dart';

/// A popup menu entry worth [value], showing an [IconMenuRow] of [icon]
/// and [label]; every menu builds its entries from it.
class IconMenuItem<T> extends PopupMenuItem<T> {
  /// Creates the entry; [isError], [leading] and [trailing] are passed to
  /// its [IconMenuRow].
  IconMenuItem({
    super.key,
    required T super.value,
    required IconData? icon,
    required String label,
    bool isError = false,
    Widget? leading,
    Widget? trailing,
  }) : super(
         child: IconMenuRow(
           icon: icon,
           label: label,
           isError: isError,
           leading: leading,
           trailing: trailing,
         ),
       );
}

/// Shows the popup menu of [items] at global [position], completing with
/// the chosen entry's value, or null when dismissed.
Future<T?> showMenuAt<T>(
  BuildContext context,
  Offset position,
  List<PopupMenuEntry<T>> items,
) {
  return showMenu<T>(
    context: context,
    position: RelativeRect.fromLTRB(
      position.dx,
      position.dy,
      position.dx,
      position.dy,
    ),
    items: items,
  );
}

/// Shows the menu of [items] at global [position] and runs the chosen
/// entry's action.
Future<void> showActionMenu(
  BuildContext context,
  Offset position,
  List<PopupMenuEntry<VoidCallback>> items,
) async {
  final action = await showMenuAt(context, position, items);
  action?.call();
}
