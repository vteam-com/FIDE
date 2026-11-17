import 'dart:math' as math;

import 'package:fide/models/architecture_layout.dart';
import 'package:material_ui/material_ui.dart';

/// One import of the architecture graph: the importing file, the imported
/// one, and the curve drawn between them.
typedef ArchitectureEdge = ({String source, String target, Path path});

/// The curves of an [ArchitectureLayout]'s imports, built once per layout
/// and reused by every paint: each runs from the importing file to the
/// imported one along the layers' stacking (bottom to top when top down,
/// right to left when left to right).
class ArchitectureEdgePaths {
  /// Builds the curves of every import of [layout].
  ArchitectureEdgePaths._(ArchitectureLayout layout)
    : all = [
        for (final MapEntry(key: source, value: targets)
            in layout.graph.callees.entries)
          for (final target in targets)
            (
              source: source,
              target: target,
              path: _edge(
                layout.nodes[source]!,
                layout.nodes[target]!,
                layout.orientation,
              ),
            ),
      ];

  /// The curves of [layout]'s imports, built the first time they are
  /// asked for and kept as long as [layout] is.
  factory ArchitectureEdgePaths.of(ArchitectureLayout layout) =>
      _byLayout[layout] ??= ArchitectureEdgePaths._(layout);

  /// Every import, in the graph's order.
  final List<ArchitectureEdge> all;

  /// Share of the span between two files, or of a layer gap when shorter,
  /// that a curve runs straight out before bending toward its end.
  static const double _bendShare = 0.5;

  /// The curves already built, by layout.
  static final Expando<ArchitectureEdgePaths> _byLayout = Expando();

  /// The imports into and out of each file, indexed on first use.
  late final Map<String, List<ArchitectureEdge>> _byFile = () {
    final byFile = <String, List<ArchitectureEdge>>{};
    for (final edge in all) {
      (byFile[edge.source] ??= []).add(edge);
      if (edge.target != edge.source) (byFile[edge.target] ??= []).add(edge);
    }
    return byFile;
  }();

  /// The imports into and out of [file].
  List<ArchitectureEdge> touching(String file) => _byFile[file] ?? const [];

  /// The curve from [from] to [to] across the layers of [orientation]:
  /// out of the bottom middle of [from] into the top middle of [to] when
  /// top down, out of its right middle into the left middle of [to] when
  /// left to right; bent at least [_bendShare] of a layer gap, so an
  /// import within one layer still loops out and back.
  static Path _edge(Rect from, Rect to, ArchitectureOrientation orientation) {
    final isTopDown = orientation == ArchitectureOrientation.topDown;
    final start = isTopDown ? from.bottomCenter : from.centerRight;
    final end = isTopDown ? to.topCenter : to.centerLeft;
    final span = isTopDown ? end.dy - start.dy : end.dx - start.dx;
    final bend = math.max(span.abs(), ArchitectureLayout.layerGap) * _bendShare;
    final out = isTopDown ? Offset(0, bend) : Offset(bend, 0);
    final startControl = start + out;
    final endControl = end - out;
    return Path()
      ..moveTo(start.dx, start.dy)
      ..cubicTo(
        startControl.dx,
        startControl.dy,
        endControl.dx,
        endControl.dy,
        end.dx,
        end.dy,
      );
  }
}
