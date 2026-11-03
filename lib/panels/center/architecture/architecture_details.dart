import 'package:fide/constants/constants.dart';
import 'package:fide/models/architecture_focus.dart';
import 'package:fide/models/architecture_graph.dart';
import 'package:fide/models/status_tone.dart';
import 'package:fide/panels/center/architecture/architecture_role_style.dart';
import 'package:fide/providers/panel_actions.dart';
import 'package:fide/widgets/compact_icon_button.dart';
import 'package:fide/widgets/file_icon_utils.dart';
import 'package:fide/widgets/panel_scroll_view.dart';
import 'package:fide/widgets/path_text.dart';
import 'package:fide/widgets/secondary_button.dart';
import 'package:fide/widgets/section_panel.dart';
import 'package:fide/widgets/status_indicator.dart';
import 'package:fide/widgets/tree_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

/// The side of the architecture view about the selected [file]: its path
/// and layer, fCheck's findings about it, and the files it imports and
/// those importing it, each a jump to that file in the graph or to its
/// source.
class ArchitectureDetails extends ConsumerWidget {
  /// Creates the details of [file] in [graph].
  const ArchitectureDetails({
    super.key,
    required this.graph,
    required this.file,
    required this.onSelect,
    required this.onOpen,
  });

  /// The selected file.
  final String file;

  /// The graph [file] is part of.
  final ArchitectureGraph graph;

  /// Opens a file in the editor.
  final ValueChanged<String> onOpen;

  /// Selects a file and shows it in the graph, or clears the selection
  /// with null.
  final ValueChanged<String?> onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final layer = graph.layers[file];
    return PanelScrollView(
      children: [
        Row(
          spacing: AppSpacing.tiny,
          children: [
            FileIconUtils.ofPath(file),
            Expanded(
              child: PathText(
                file,
                rootPath: graph.rootPath,
                style: AppTextStyle.bodyStrong,
                selectable: true,
              ),
            ),
            CompactIconButton(
              icon: Icons.close,
              tooltip: 'Clear selection',
              onPressed: () => onSelect(null),
            ),
          ],
        ),
        if (graph.isLayered && layer != null)
          Text('Layer $layer', style: AppTextStyle.secondary(context)),
        Wrap(
          spacing: AppSpacing.medium,
          runSpacing: AppSpacing.medium,
          children: [
            SecondaryButton(
              icon: Icons.code,
              label: 'Open',
              onPressed: () => onOpen(file),
            ),
            SecondaryButton(
              icon: Icons.folder_open,
              label: 'Reveal in Explorer',
              onPressed: () => revealInExplorer(ref, file),
            ),
          ],
        ),
        for (final issue in graph.issues[file] ?? const <String>[])
          StatusIndicator.tone(StatusTone.warning, label: issue),
        _section(
          context,
          title: 'Imports',
          role: ArchitectureRole.callee,
          files: graph.callees[file] ?? const [],
        ),
        _section(
          context,
          title: 'Imported by',
          role: ArchitectureRole.caller,
          files: graph.callers[file] ?? const [],
        ),
      ],
    );
  }

  /// The [files] related to [file] in [role], under [title] marked with
  /// the role's color: pressing one shows it in the graph, its button
  /// opens it.
  Widget _section(
    BuildContext context, {
    required String title,
    required ArchitectureRole role,
    required List<String> files,
  }) {
    return SectionPanel(
      title: title,
      count: files.length,
      isExpanded: true,
      rightWidget: Icon(
        role == ArchitectureRole.callee ? Icons.east : Icons.west,
        size: AppIconSize.small,
        color: role.color(Theme.of(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final related in files)
            TreeRow(
              icon: FileIconUtils.ofPath(related),
              name: p.basename(related),
              path: related,
              rootPath: graph.rootPath,
              note: graph.isLayered ? 'Layer ${graph.layers[related]}' : null,
              onTap: () => onSelect(related),
              trailing: [
                CompactIconButton(
                  icon: Icons.code,
                  tooltip: 'Open',
                  onPressed: () => onOpen(related),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
