part of 'shared_panel_utils.dart';

/// Shows the project tree's context menu.
class ContextMenuHandler {
  /// Shows the [NodeAction]s that apply to [node] at [position] and passes
  /// the chosen one to [onAction].
  static void showNodeContextMenu(
    BuildContext context,
    ProjectNode node,
    Offset position,
    void Function(NodeAction, ProjectNode) onAction,
  ) {
    showMenu<NodeAction>(
      context: context,
      position: MoreMenuButton.menuPosition(position),
      items: [
        for (final action in NodeAction.values)
          if (action.appliesTo(node))
            PopupMenuItem(
              value: action,
              child: IconMenuRow(
                icon: action.icon,
                label: action.label,
                isError: action.isDestructive,
              ),
            ),
      ],
    ).then((action) {
      if (action != null) onAction(action, node);
    });
  }
}
