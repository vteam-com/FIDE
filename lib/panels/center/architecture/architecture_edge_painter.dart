import 'package:fide/constants/constants.dart';
import 'package:fide/models/architecture_focus.dart';
import 'package:fide/models/architecture_layout.dart';
import 'package:fide/panels/center/architecture/architecture_edge_paths.dart';
import 'package:fide/panels/center/architecture/architecture_role_style.dart';
import 'package:material_ui/material_ui.dart';

/// Paints the imports of an [ArchitectureLayout] from their
/// [ArchitectureEdgePaths], built once per layout: every import faint
/// ([ArchitectureEdgePainter.all]), or only the focused file's in its
/// callees' and callers' colors ([ArchitectureEdgePainter.focused]),
/// drawn on top, so hovering a file repaints only its few imports.
class ArchitectureEdgePainter extends CustomPainter {
  /// Creates the painter of every import of [layout], faint, colored from
  /// [theme].
  ArchitectureEdgePainter.all({required this.layout, required this.theme})
    : focus = null;

  /// Creates the painter of the imports of [focus]'s file in [layout],
  /// colored from [theme]; nothing when no file is in focus.
  ArchitectureEdgePainter.focused({
    required this.layout,
    required ArchitectureFocus this.focus,
    required this.theme,
  });

  /// What is highlighted; null to paint every import faint.
  final ArchitectureFocus? focus;

  /// Where each file is.
  final ArchitectureLayout layout;

  /// The theme the colors come from.
  final ThemeData theme;

  @override
  void paint(Canvas canvas, Size size) {
    final edges = ArchitectureEdgePaths.of(layout);
    final paint = Paint()..style = PaintingStyle.stroke;
    final focus = this.focus;
    if (focus == null) {
      paint
        ..strokeWidth = AppSize.borderThin
        ..color = theme.dividerColor;
      for (final edge in edges.all) {
        canvas.drawPath(edge.path, paint);
      }
      return;
    }
    final file = focus.file;
    if (file == null) return;
    paint.strokeWidth = AppBorderWidth.medium;
    for (final edge in edges.touching(file)) {
      final role = edge.source == file
          ? ArchitectureRole.callee
          : ArchitectureRole.caller;
      canvas.drawPath(edge.path, paint..color = role.color(theme));
    }
  }

  @override
  bool shouldRepaint(ArchitectureEdgePainter oldDelegate) =>
      oldDelegate.layout != layout ||
      oldDelegate.focus?.file != focus?.file ||
      oldDelegate.theme != theme;
}
