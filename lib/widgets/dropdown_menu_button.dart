import 'package:fide/constants/constants.dart';
import 'package:material_ui/material_ui.dart';

/// A "pick one" menu: the current value [label] then a drop-down arrow,
/// opening under it the entries [itemBuilder] builds and calling
/// [onSelected] with the one picked.
///
/// Every pick-one menu (the project, the open file, the AI action) is one,
/// so they all look, open and highlight alike.
class DropdownMenuButton<T> extends StatelessWidget {
  /// Creates the menu showing [label].
  const DropdownMenuButton({
    super.key,
    required this.label,
    required this.itemBuilder,
    required this.onSelected,
    this.initialValue,
    this.tooltip,
  });

  /// The entry highlighted when the menu opens, such as the current one.
  final T? initialValue;

  /// Builds the entries each time the menu opens.
  final PopupMenuItemBuilder<T> itemBuilder;

  /// The current value, such as a project or file name; shortened when
  /// space runs out.
  final Widget label;

  /// Called with the picked entry's value.
  final PopupMenuItemSelected<T> onSelected;

  /// Hover text; the platform's "Show menu" when null.
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<T>(
      initialValue: initialValue,
      tooltip: tooltip,
      position: PopupMenuPosition.under,
      itemBuilder: itemBuilder,
      onSelected: onSelected,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: AppSpacing.tiny,
        children: [
          Flexible(child: label),
          Icon(
            Icons.arrow_drop_down,
            size: AppIconSize.medium,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ],
      ),
    );
  }
}
