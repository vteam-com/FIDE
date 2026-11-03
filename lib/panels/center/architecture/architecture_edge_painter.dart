import 'dart:math' as math;

import 'package:fide/constants/constants.dart';
import 'package:fide/models/architecture_focus.dart';
import 'package:fide/models/architecture_layout.dart';
import 'package:fide/panels/center/architecture/architecture_role_style.dart';
import 'package:flutter/material.dart';

/// Paints the imports of an [ArchitectureLayout], each a curve from the
/// right of the importing file to the left of the imported one: the
/// imports of the focused file in its callees' and callers' colors on
/// top, the others faint, or left out unless [showAll].
class ArchitectureEdgePainter extends CustomPainter {
  /// Creates the painter of [layout]'s imports around [focus], colored
  /// from [theme].
  ArchitectureEdgePainter({
    required this.layout,
    required this.focus,
    required this.theme,
    required this.showAll,
  });

  /// Share of the span between two files, or of a column gap when
  /// shorter, that a curve leaves level before bending toward its end.
  static const double _bendShare = 0.5;

  /// What is highlighted.
  final ArchitectureFocus focus;

  /// Where each file is.
  final ArchitectureLayout layout;

  /// Whether the imports away from the focused file are drawn, faint.
  final bool showAll;

  /// The theme the colors come from.
  final ThemeData theme;

  @override
  void paint(Canvas canvas, Size size) {
    final faint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = AppSize.borderThin
      ..color = theme.dividerColor;
    final highlighted = <(Path, Color)>[];
    final graph = layout.graph;
    for (final MapEntry(key: source, value: targets) in graph.callees.entries) {
      for (final target in targets) {
        final path = _edge(layout.nodes[source]!, layout.nodes[target]!);
        if (focus.isHighlighted(source, target)) {
          final role = source == focus.file
              ? ArchitectureRole.callee
              : ArchitectureRole.caller;
          highlighted.add((path, role.color(theme)));
        } else if (showAll) {
          canvas.drawPath(path, faint);
        }
      }
    }
    final strong = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = AppBorderWidth.medium;
    for (final (path, color) in highlighted) {
      canvas.drawPath(path, strong..color = color);
    }
  }

  @override
  bool shouldRepaint(ArchitectureEdgePainter oldDelegate) =>
      oldDelegate.layout != layout ||
      oldDelegate.focus.file != focus.file ||
      oldDelegate.showAll != showAll ||
      oldDelegate.theme != theme;

  /// The curve from the right middle of [from] to the left middle of [to],
  /// leaving and arriving level, bent at least [_bendShare] of a column gap
  /// so an import within one column still loops out and back.
  static Path _edge(Rect from, Rect to) {
    final start = from.centerRight;
    final end = to.centerLeft;
    final bend =
        math.max((end.dx - start.dx).abs(), ArchitectureLayout.columnGap) *
        _bendShare;
    return Path()
      ..moveTo(start.dx, start.dy)
      ..cubicTo(
        start.dx + bend,
        start.dy,
        end.dx - bend,
        end.dy,
        end.dx,
        end.dy,
      );
  }
}
