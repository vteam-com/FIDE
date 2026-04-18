part of 'shared_panel_utils.dart';

/// Shared context menu handler.
class ContextMenuHandler {
  /// Handles `ContextMenuHandler.showNodeContextMenu`.
  static void showNodeContextMenu(
    BuildContext context,
    ProjectNode node,
    Offset position,
    Function(String, ProjectNode) onAction,
  ) {
    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx + 1,
        position.dy + 1,
      ),
      items: [
        const PopupMenuItem(value: 'open', child: Text('Open')),
        const PopupMenuItem(
          value: 'copy_full_path',
          child: Text('Copy Full Path'),
        ),
        const PopupMenuItem(
          value: 'copy_relative_path',
          child: Text('Copy Relative Path'),
        ),
        if (node.isDirectory) ...[
          const PopupMenuItem(value: 'new_file', child: Text('New File')),
          const PopupMenuItem(value: 'new_folder', child: Text('New Folder')),
        ],
        const PopupMenuItem(value: 'rename', child: Text('Rename')),
        const PopupMenuItem(
          value: 'delete',
          child: Text('Delete', style: TextStyle(color: Colors.red)),
        ),
      ],
    ).then((value) {
      if (value == null) return;
      onAction(value, node);
    });
  }

  /// Handles `ContextMenuHandler.showFileContextMenu`.
  static void showFileContextMenu(
    BuildContext context,
    ProjectNode node,
    Offset position,
    Function(String, ProjectNode) onAction,
  ) {
    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx + 1,
        position.dy + 1,
      ),
      items: [
        PopupMenuItem(
          value: 'reveal',
          child: Row(
            children: [
              Icon(
                Platform.isMacOS ? Icons.folder_open : Icons.folder,
                size: AppIconSize.medium,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: AppSpacing.medium),
              Text(Platform.isMacOS ? 'Reveal in Finder' : 'Show in Explorer'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'copy_full_path',
          child: Row(
            children: [
              Icon(
                Icons.content_copy,
                size: AppIconSize.medium,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: AppSpacing.medium),
              const Text('Copy Full Path'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'copy_relative_path',
          child: Row(
            children: [
              Icon(
                Icons.content_copy,
                size: AppIconSize.medium,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: AppSpacing.medium),
              const Text('Copy Relative Path'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'rename',
          child: Row(
            children: [
              Icon(
                Icons.edit,
                size: AppIconSize.medium,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: AppSpacing.medium),
              const Text('Rename'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(
                Icons.delete,
                size: AppIconSize.medium,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(width: AppSpacing.medium),
              Text(
                'Delete',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ),
        ),
      ],
    ).then((value) {
      if (value == null) return;
      onAction(value, node);
    });
  }
}
