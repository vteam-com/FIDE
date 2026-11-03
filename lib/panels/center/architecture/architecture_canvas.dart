import 'package:fide/constants/constants.dart';
import 'package:fide/models/architecture_focus.dart';
import 'package:fide/models/architecture_layout.dart';
import 'package:fide/panels/center/architecture/architecture_edge_painter.dart';
import 'package:fide/panels/center/architecture/architecture_node.dart';
import 'package:flutter/material.dart';

/// The architecture graph of [layout], zoomed by a trackpad pinch or the
/// mouse wheel and panned by dragging: the layer and folder captions, the
/// imports, and one [ArchitectureNode] per file, highlighted around
/// [focus]. Pressing the background clears the selection.
class ArchitectureCanvas extends StatelessWidget {
  /// Creates the canvas of [layout].
  const ArchitectureCanvas({
    super.key,
    required this.layout,
    required this.focus,
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

  /// What is highlighted.
  final ArchitectureFocus focus;

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
  Widget build(BuildContext context) {
    final graph = layout.graph;
    return InteractiveViewer(
      transformationController: controller,
      constrained: false,
      boundaryMargin: const EdgeInsets.all(double.infinity),
      minScale: minScale,
      maxScale: maxScale,
      onInteractionStart: (_) => onInteractionStart?.call(),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onSelect(null),
        child: SizedBox.fromSize(
          size: layout.size,
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: ArchitectureEdgePainter(
                    layout: layout,
                    focus: focus,
                    theme: Theme.of(context),
                    showAll: showAllImports,
                  ),
                ),
              ),
              for (final caption in layout.captions)
                Positioned.fromRect(
                  rect: caption.rect,
                  child: _caption(context, caption),
                ),
              for (final MapEntry(key: file, value: rect)
                  in layout.nodes.entries)
                Positioned.fromRect(
                  rect: rect,
                  child: ArchitectureNode(
                    path: file,
                    rootPath: graph.rootPath,
                    role: focus.roleOf(file),
                    isSelected: file == selected,
                    isMatch: focus.isMatch(file),
                    issues: graph.issues[file] ?? const [],
                    onHover: (isInside) => onHover(file, isInside),
                    onSelect: () => onSelect(file),
                    onOpen: () => onOpen(file),
                  ),
                ),
            ],
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
}
