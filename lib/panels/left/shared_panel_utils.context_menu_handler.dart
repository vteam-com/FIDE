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
    final colorScheme = Theme.of(context).colorScheme;
    showMenu<NodeAction>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx + 1,
        position.dy + 1,
      ),
      items: [
        for (final action in NodeAction.values)
          if (action.appliesTo(node))
            PopupMenuItem(
              value: action,
              child: Row(
                spacing: AppSpacing.medium,
                children: [
                  Icon(
                    action.icon,
                    size: AppIconSize.medium,
                    color: action.isDestructive
                        ? colorScheme.error
                        : colorScheme.primary,
                  ),
                  Text(
                    action.label,
                    style: action.isDestructive
                        ? TextStyle(color: colorScheme.error)
                        : null,
                  ),
                ],
              ),
            ),
      ],
    ).then((action) {
      if (action != null) onAction(action, node);
    });
  }
}
