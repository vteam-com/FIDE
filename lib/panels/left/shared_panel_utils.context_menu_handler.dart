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
    final shell = ProviderScope.containerOf(
      context,
      listen: false,
    ).read(desktopShellProvider);
    showMenuAt<NodeAction>(context, position, [
      for (final action in NodeAction.values)
        if (action.appliesTo(node))
          IconMenuItem(
            value: action,
            icon: action.icon,
            label: action.labelIn(shell),
            isError: action.isDestructive,
          ),
    ]).then((action) {
      if (action != null) onAction(action, node);
    });
  }
}
