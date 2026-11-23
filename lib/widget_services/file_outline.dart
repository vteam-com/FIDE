import 'package:fide/constants/constants.dart';
import 'package:fide/models/outline_node.dart';
import 'package:fide/models/readable_error.dart';
import 'package:fide/models/status_tone.dart';
import 'package:fide/models/widget_wrapper.dart';
import 'package:fide/providers/active_editor.dart';
import 'package:fide/providers/editor_navigation.dart';
import 'package:fide/providers/outline_controller.dart';
import 'package:fide/providers/outline_providers.dart';
import 'package:fide/providers/panel_actions.dart';
import 'package:fide/providers/right_panel_tab.dart';
import 'package:fide/providers/ui_state_providers.dart';
import 'package:fide/services/widget_editor.dart';
import 'package:fide/widgets/container_counter.dart';
import 'package:fide/widgets/icon_menu_item.dart';
import 'package:fide/widgets/inline_spinner.dart';
import 'package:fide/widgets/message_box.dart';
import 'package:fide/widgets/more_menu_button.dart';
import 'package:fide/widgets/outline_kind_style.dart';
import 'package:fide/widgets/status_indicator.dart';
import 'package:fide/widgets/tree_row.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// The outline of the selected file, nested under its row in a project
/// tree: its declarations, headings or keys, the widget tree of the
/// declaration under the editor's cursor, the entries under the cursor
/// highlighted and the declaration's consumers counted. Each widget-tree
/// entry has a menu of widget edits (wrap, remove, swap, move), on its
/// ⋯ button under the cursor and on a secondary click. Nothing for a file
/// type without an outline, or while its row folds it.
class FileOutline extends ConsumerWidget {
  /// Creates the outline of the file at [path].
  const FileOutline({super.key, required this.path});

  /// The file outlined; its editor text when open, else its saved text.
  final String path;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isFolded = ref.watch(
      foldedOutlinePathProvider.select((folded) => folded == path),
    );
    if (isFolded || ref.watch(outlineParserProvider(path)) == null) {
      return const SizedBox.shrink();
    }
    final outline = ref.watch(outlineControllerProvider(path));
    // An outline that never parsed says why; a later failure, such as
    // YAML mid-edit, keeps the last one shown
    if (outline.nodes.isEmpty && outline.error.isNotEmpty) {
      return _buildError(ref, outline.error);
    }
    final selectedWidget = outline.selectedWidget;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (:node, :foldedWidgets) in outline.shownNodes)
          _buildNode(
            context,
            ref,
            outline,
            node,
            foldedWidgets,
            isSelectedWidget: node.isSameAs(selectedWidget),
          ),
      ],
    );
  }

  /// The row telling the file can't be outlined, [error] in its tooltip;
  /// clicking it parses the file again.
  Widget _buildError(WidgetRef ref, String error) {
    return TreeRow(
      icon: StatusIndicator.tone(StatusTone.error),
      name: 'Parse error',
      note: '$error\n\nClick to parse again',
      onTap: ref.read(outlineControllerProvider(path).notifier).parse,
    );
  }

  /// One entry of [outline] with its icon and label, highlighted when the
  /// cursor is on it; [foldedWidgets] counts the widgets folded under it.
  /// A widget-tree entry opens its widget menu on a secondary click, and
  /// on its ⋯ button when [isSelectedWidget], the innermost under the
  /// cursor.
  Widget _buildNode(
    BuildContext context,
    WidgetRef ref,
    OutlineState outline,
    OutlineNode node,
    int foldedWidgets, {
    required bool isSelectedWidget,
  }) {
    final kind = node.kind;
    // Moving the cursor there also unfolds the entry's widget tree
    void goToNode() => ref
        .read(activeEditorProvider)
        .navigateToLine(node.line, column: node.column);
    return TreeRow(
      icon: Icon(
        kind.icon,
        color: kind.colorIn(Theme.of(context).colorScheme),
        size: AppIconSize.medium,
      ),
      name: node.name,
      depth: node.level,
      highlighted: outline.isHighlighted(node),
      onTap: goToNode,
      onContextMenu: kind.isWidget && !outline.isEditing
          ? (position) => _showWidgetMenu(context, ref, node, position)
          : null,
      showMenuButton: isSelectedWidget,
      trailing: [
        if (outline.isEdited(node)) const InlineSpinner.small(),
        if (foldedWidgets > 0)
          ContainerCounter(
            count: foldedWidgets,
            tooltip: foldedWidgets == 1
                ? 'Builds 1 widget; click to show it'
                : 'Builds $foldedWidgets widgets; click to show its widget '
                      'tree',
            onTap: goToNode,
          ),
        if (outline.isCounted(node)) ...[
          _buildConsumerCount(ref, outline, node),
          if (!outline.isEditing)
            MoreMenuButton(
              onPressed: (position) =>
                  _showNodeMenu(context, ref, node, position),
            ),
        ],
      ],
    );
  }

  /// [node]'s consumer count, clickable to list them in the Info tab, or
  /// a spinner while they are found.
  Widget _buildConsumerCount(
    WidgetRef ref,
    OutlineState outline,
    OutlineNode node,
  ) {
    final consumers = outline.consumersOf(node);
    if (consumers == null || outline.isRenaming) {
      return const InlineSpinner.small();
    }
    return ContainerCounter(
      count: consumers.length,
      tooltip: consumers.length == 1
          ? '1 consumer; click to list it in Info'
          : '${consumers.length} consumers; click to list them in Info',
      onTap: () => showRightPanelTab(ref.read, RightPanelTab.info),
    );
  }

  /// [node]'s actions: Rename; the Info tab lists its callers.
  void _showNodeMenu(
    BuildContext context,
    WidgetRef ref,
    OutlineNode node,
    Offset position,
  ) {
    showActionMenu(context, position, [
      IconMenuItem(
        value: () => _rename(context, ref, node),
        icon: Icons.drive_file_rename_outline,
        label: 'Rename…',
      ),
    ]);
  }

  /// [node]'s widget edits that apply to it: wrap it in a common widget or
  /// one the user names, remove it in favor of its children, swap it with
  /// its parent, move it among the widgets of its list.
  void _showWidgetMenu(
    BuildContext context,
    WidgetRef ref,
    OutlineNode node,
    Offset position,
  ) {
    final editor = ref
        .read(outlineControllerProvider(path).notifier)
        .widgetEditorOf(node);
    if (editor == null) return;
    void edit(WidgetEdit change) => _editWidget(context, ref, node, change);
    final reshapes = [
      if (editor.canRemove)
        IconMenuItem<VoidCallback>(
          value: () => edit((editor) => editor.remove()),
          icon: Icons.layers_clear,
          label: 'Remove Widget',
        ),
      if (editor.canSwapWithParent)
        IconMenuItem<VoidCallback>(
          value: () => edit((editor) => editor.swapWithParent()),
          icon: Icons.swap_vert,
          label: 'Swap with Parent',
        ),
      if (editor.canMoveUp)
        IconMenuItem<VoidCallback>(
          value: () => edit((editor) => editor.moveUp()),
          icon: Icons.arrow_upward,
          label: 'Move Up',
        ),
      if (editor.canMoveDown)
        IconMenuItem<VoidCallback>(
          value: () => edit((editor) => editor.moveDown()),
          icon: Icons.arrow_downward,
          label: 'Move Down',
        ),
    ];
    showActionMenu(context, position, [
      for (final wrapper in WidgetWrapper.common)
        IconMenuItem(
          value: () => edit((editor) => editor.wrap(wrapper)),
          icon: Icons.add_box_outlined,
          label: 'Wrap with ${wrapper.name}',
        ),
      IconMenuItem(
        value: () => _wrapWithNamed(context, ref, node),
        icon: Icons.add_box_outlined,
        label: 'Wrap with Widget…',
      ),
      if (reshapes.isNotEmpty) ...[const PopupMenuDivider(), ...reshapes],
    ]);
  }

  /// Asks for a widget's name and wraps [node] in it.
  Future<void> _wrapWithNamed(
    BuildContext context,
    WidgetRef ref,
    OutlineNode node,
  ) async {
    final name = await MessageBox.promptForText(
      context,
      title: 'Wrap ${node.name}',
      labelText: 'Widget',
      hintText: 'Enter the widget class name',
      confirmLabel: 'Wrap',
    );
    if (!context.mounted || name == null || name.trim().isEmpty) return;
    final wrapper = WidgetWrapper.named(name);
    if (wrapper == null) {
      MessageBox.showError(context, '$name is not a widget name');
      return;
    }
    await _editWidget(context, ref, node, (editor) => editor.wrap(wrapper));
  }

  /// Makes [edit] to [node], then moves the caret to the widget edited, or
  /// says why it couldn't.
  Future<void> _editWidget(
    BuildContext context,
    WidgetRef ref,
    OutlineNode node,
    WidgetEdit edit,
  ) async {
    try {
      final at = await ref
          .read(outlineControllerProvider(path).notifier)
          .editWidget(node, edit);
      if (context.mounted) {
        await openFileAtLine(ref, path, at.line, column: at.column);
      }
    } catch (e) {
      if (context.mounted) {
        MessageBox.showError(
          context,
          'Widget edit failed: ${ReadableError.describe(e)}',
        );
      }
    }
  }

  /// Asks for a new name and renames [node] and its uses across the
  /// project, reporting how many files changed.
  Future<void> _rename(
    BuildContext context,
    WidgetRef ref,
    OutlineNode node,
  ) async {
    final controller = ref.read(outlineControllerProvider(path).notifier);
    if (!controller.canRename) return;
    final name = node.usedName;
    final newName = await MessageBox.promptForText(
      context,
      title: 'Rename $name',
      labelText: 'New name',
      hintText: 'Enter the new name',
      confirmLabel: 'Rename',
      initialText: name,
    );
    if (!context.mounted ||
        newName == null ||
        newName.isEmpty ||
        newName == name) {
      return;
    }

    try {
      final files = await controller.rename(node, newName);
      if (!context.mounted) return;
      MessageBox.showSuccess(
        context,
        files.length == 1
            ? 'Renamed $name to $newName'
            : 'Renamed $name to $newName in ${files.length} files',
      );
    } catch (e) {
      if (context.mounted) {
        MessageBox.showError(
          context,
          'Rename failed: ${ReadableError.describe(e)}',
        );
      }
    }
  }
}
