import 'package:fide/constants/constants.dart';
import 'package:fide/models/architecture_focus.dart';
import 'package:fide/models/architecture_layout.dart';
import 'package:fide/panels/center/architecture/architecture_edge_painter.dart';
import 'package:fide/panels/center/architecture/architecture_node.dart';
import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

/// The architecture graph of [layout], zoomed by a trackpad pinch or the
/// mouse wheel and panned by dragging: the layer and folder captions, the
/// imports, and one [ArchitectureNode] per file, highlighted around the
/// [hovered] file, else the [selected] one, else the files matching
/// [filter]. Pressing the background clears the selection.
///
/// Built to stay smooth on large projects: zooming and panning move the
/// graph's painted layers without painting them again; hovering a file
/// rebuilds only the boxes whose look changes and repaints only the
/// focused file's imports.
class ArchitectureCanvas extends StatefulWidget {
  /// Creates the canvas of [layout].
  const ArchitectureCanvas({
    super.key,
    required this.layout,
    required this.filter,
    required this.hovered,
    required this.controller,
    required this.selected,
    required this.showAllImports,
    required this.onHover,
    required this.onSelect,
    required this.onOpen,
    this.onInteractionStart,
  });

  /// Zoom and pan of the canvas.
  final TransformationController controller;

  /// The files matching the Find File box, with no file in focus.
  final ArchitectureFocus filter;

  /// The file under the pointer; null for none.
  final ValueListenable<String?> hovered;

  /// Where each file and caption is.
  final ArchitectureLayout layout;

  /// Largest zoom.
  static const double maxScale = 3;

  /// Smallest zoom, showing a large project whole.
  static const double minScale = 0.05;

  /// Called with a file and true when the pointer enters its box, false
  /// when it leaves.
  final void Function(String file, bool isInside) onHover;

  /// Called when the user starts zooming or panning.
  final VoidCallback? onInteractionStart;

  /// Opens a file in the editor.
  final ValueChanged<String> onOpen;

  /// Selects a file, or clears the selection with null.
  final ValueChanged<String?> onSelect;

  /// The selected file; null for none.
  final String? selected;

  /// Whether every import is drawn, or only the focused file's.
  final bool showAllImports;

  @override
  State<ArchitectureCanvas> createState() => _ArchitectureCanvasState();
}

/// How one file's box looks; a box looking the same is not built again.
typedef _NodeLook = ({ArchitectureRole role, bool isSelected, bool isMatch});

class _ArchitectureCanvasState extends State<ArchitectureCanvas> {
  /// Each file's box as last built, with how it looks, reused while its
  /// look stays the same.
  final Map<String, (_NodeLook, Widget)> _nodes = {};

  @override
  void didUpdateWidget(ArchitectureCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    // New boxes for another layout, which may lack some files
    if (oldWidget.layout != widget.layout) _nodes.clear();
  }

  @override
  Widget build(BuildContext context) {
    final layout = widget.layout;
    final theme = Theme.of(context);
    return InteractiveViewer(
      transformationController: widget.controller,
      constrained: false,
      boundaryMargin: const EdgeInsets.all(double.infinity),
      minScale: ArchitectureCanvas.minScale,
      maxScale: ArchitectureCanvas.maxScale,
      onInteractionStart: (_) => widget.onInteractionStart?.call(),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => widget.onSelect(null),
        // Zooming and panning move this layer without painting it again
        child: RepaintBoundary(
          child: SizedBox.fromSize(
            size: layout.size,
            child: Stack(
              children: [
                if (widget.showAllImports)
                  Positioned.fill(
                    child: RepaintBoundary(
                      child: CustomPaint(
                        painter: ArchitectureEdgePainter.all(
                          layout: layout,
                          theme: theme,
                        ),
                      ),
                    ),
                  ),
                for (final caption in layout.captions)
                  Positioned.fromRect(
                    rect: caption.rect,
                    child: _caption(context, caption),
                  ),
                Positioned.fill(
                  child: ValueListenableBuilder(
                    valueListenable: widget.hovered,
                    builder: (_ /*context*/, hovered, _ /*child*/) =>
                        _focused(theme, hovered),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// A layer's name and file count, or a folder's path, at the bottom of
  /// its box.
  Widget _caption(BuildContext context, ArchitectureCaption caption) {
    final detail = caption.detail;
    return Align(
      alignment: Alignment.bottomLeft,
      child: Text.rich(
        TextSpan(
          text: caption.text,
          children: [
            if (detail != null)
              TextSpan(
                text: '  $detail',
                style: AppTextStyle.secondary(context),
              ),
          ],
        ),
        style: caption.isLayer
            ? AppTextStyle.title
            : AppTextStyle.captionStrong,
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
      ),
    );
  }

  /// The focused file's imports and every file's box, highlighted around
  /// [hovered], else the selected file.
  Widget _focused(ThemeData theme, String? hovered) {
    final layout = widget.layout;
    final selected = widget.selected;
    // A file gone after a re-analysis is no longer hovered
    final pointed = layout.nodes.containsKey(hovered) ? hovered : null;
    final focus = widget.filter.focusing(pointed ?? selected);
    return Stack(
      children: [
        Positioned.fill(
          child: RepaintBoundary(
            child: CustomPaint(
              painter: ArchitectureEdgePainter.focused(
                layout: layout,
                focus: focus,
                theme: theme,
              ),
            ),
          ),
        ),
        for (final MapEntry(key: file, value: rect) in layout.nodes.entries)
          Positioned.fromRect(rect: rect, child: _node(file, focus)),
      ],
    );
  }

  /// The box of [file] around [focus], the one built before while it
  /// looks the same.
  Widget _node(String file, ArchitectureFocus focus) {
    final look = (
      role: focus.roleOf(file),
      isSelected: file == widget.selected,
      isMatch: focus.isMatch(file),
    );
    if (_nodes[file] case (final built, final node) when built == look) {
      return node;
    }
    final node = ArchitectureNode(
      path: file,
      rootPath: widget.layout.graph.rootPath,
      role: look.role,
      isSelected: look.isSelected,
      isMatch: look.isMatch,
      issues: widget.layout.graph.issues[file] ?? const [],
      // Through the current widget: a box is kept across rebuilds
      onHover: (isInside) => widget.onHover(file, isInside),
      onSelect: () => widget.onSelect(file),
      onOpen: () => widget.onOpen(file),
    );
    _nodes[file] = (look, node);
    return node;
  }
}
