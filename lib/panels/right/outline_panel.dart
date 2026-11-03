import 'package:fide/constants/constants.dart';
import 'package:fide/models/file_system_item.dart';
import 'package:fide/models/outline_node.dart';
import 'package:fide/models/reference_search.dart';
import 'package:fide/models/search_result.dart';
import 'package:fide/providers/active_editor.dart';
import 'package:fide/providers/editor_navigation.dart';
import 'package:fide/providers/left_panel_tab.dart';
import 'package:fide/providers/outline_controller.dart';
import 'package:fide/providers/panel_actions.dart';
import 'package:fide/providers/ui_state_providers.dart';
import 'package:fide/widgets/container_counter.dart';
import 'package:fide/widgets/empty_state.dart';
import 'package:fide/widgets/icon_menu_item.dart';
import 'package:fide/widgets/inline_spinner.dart';
import 'package:fide/widgets/loading_indicator.dart';
import 'package:fide/widgets/message_box.dart';
import 'package:fide/widgets/more_menu_button.dart';
import 'package:fide/widgets/outline_kind_style.dart';
import 'package:fide/widgets/output_panel.dart';
import 'package:fide/widgets/tree_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The outline of a file: its declarations, headings or keys, the one
/// under the editor's cursor highlighted with its consumers counted.
class OutlinePanel extends ConsumerWidget {
  /// Creates the outline of [file].
  const OutlinePanel({super.key, required this.file});

  /// The file outlined; its editor text when open, else its saved text.
  final FileSystemItem file;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final outline = ref.watch(outlineControllerProvider(file.path));
    final list = ListView.builder(
      padding: AppPadding.panelContent,
      itemCount: outline.nodes.length,
      itemBuilder: (_, index) =>
          _buildOutlineNode(context, ref, outline, outline.nodes[index]),
    );

    return LayoutBuilder(
      builder: (_ /*context*/, constraints) {
        final isConstrained = constraints.maxHeight.isFinite;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (outline.isLoading)
              const LoadingIndicator()
            else if (outline.error.isNotEmpty)
              OutputPanel(
                title: 'Parse Error',
                text: outline.error,
                isExpanded: true,
                onClear: ref
                    .read(outlineControllerProvider(file.path).notifier)
                    .parse,
              )
            else if (outline.nodes.isEmpty)
              const Padding(
                padding: AppPadding.panelContent,
                child: EmptyState(message: 'No outline available'),
              )
            else if (isConstrained)
              Expanded(child: list)
            else
              Flexible(
                child: SizedBox(
                  height: AppSize.outlineFallbackHeight,
                  child: list,
                ),
              ),
          ],
        );
      },
    );
  }

  /// One entry of [outline] with its icon and label, highlighted when the
  /// cursor is on it.
  Widget _buildOutlineNode(
    BuildContext context,
    WidgetRef ref,
    OutlineState outline,
    OutlineNode node,
  ) {
    final kind = node.kind;
    return TreeRow(
      icon: Icon(
        kind.icon,
        color: kind.colorIn(Theme.of(context).colorScheme),
        size: AppIconSize.medium,
      ),
      name: node.name,
      depth: node.level,
      highlighted: outline.isHighlighted(node),
      // Navigate to the corresponding line and column in the editor
      onTap: () => ref
          .read(activeEditorProvider)
          .navigateToLine(node.line, column: node.column),
      trailing: [
        if (outline.isCounted(node)) ...[
          _buildConsumerCount(ref, outline, node),
          if (!outline.isRenaming)
            MoreMenuButton(
              onPressed: (position) =>
                  _showNodeMenu(context, ref, outline, node, position),
            ),
        ],
      ],
    );
  }

  /// [node]'s consumer count, clickable to list them in the Search panel,
  /// or a spinner while they are found.
  Widget _buildConsumerCount(
    WidgetRef ref,
    OutlineState outline,
    OutlineNode node,
  ) {
    final consumers = outline.consumersOf(node);
    if (consumers == null || outline.isRenaming) {
      return const InlineSpinner(size: AppSize.compactProgressIndicator);
    }
    return ContainerCounter(
      count: consumers.length,
      tooltip: consumers.length == 1
          ? '1 consumer; click to list it in Search'
          : '${consumers.length} consumers; click to list them in Search',
      onTap: () => _showConsumers(ref, node, consumers),
    );
  }

  /// [node]'s actions: Rename, and once its consumers are known, Jump to
  /// caller (when there is exactly one) and Show all callers.
  void _showNodeMenu(
    BuildContext context,
    WidgetRef ref,
    OutlineState outline,
    OutlineNode node,
    Offset position,
  ) {
    final consumers = outline.consumersOf(node);
    showActionMenu(context, position, [
      IconMenuItem(
        value: () => _rename(context, ref, node),
        icon: Icons.drive_file_rename_outline,
        label: 'Rename…',
      ),
      if (consumers != null && consumers.length == 1)
        IconMenuItem(
          value: () => openFileAtLine(
            ref,
            consumers.single.filePath,
            consumers.single.lineNumber,
          ),
          icon: Icons.call_made,
          label: 'Jump to caller',
        ),
      if (consumers != null && consumers.isNotEmpty)
        IconMenuItem(
          value: () => _showConsumers(ref, node, consumers),
          icon: Icons.manage_search,
          label: 'Show all callers',
        ),
    ]);
  }

  /// Asks for a new name and renames [node] and its uses across the
  /// project, reporting how many files changed.
  Future<void> _rename(
    BuildContext context,
    WidgetRef ref,
    OutlineNode node,
  ) async {
    final controller = ref.read(outlineControllerProvider(file.path).notifier);
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
      if (context.mounted) MessageBox.showError(context, 'Rename failed: $e');
    }
  }

  /// Lists [consumers], the uses of [node], in the left panel's Search tab.
  void _showConsumers(
    WidgetRef ref,
    OutlineNode node,
    List<SearchResult> consumers,
  ) {
    ref.read(referenceSearchProvider.notifier).state = ReferenceSearch(
      name: node.usedName,
      results: consumers,
    );
    showLeftPanelTab(ref.read, LeftPanelTab.search);
  }
}
