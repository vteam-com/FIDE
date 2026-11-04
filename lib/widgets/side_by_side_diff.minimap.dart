part of 'side_by_side_diff.dart';

/// The strip beside a diff that marks each deleted line red and each added
/// line green at its place in the whole text, shades the part in view, and
/// scrolls there when tapped or dragged.
class _DiffMinimap extends StatelessWidget {
  /// Creates the minimap of [lines], kept in step with [controller].
  const _DiffMinimap({required this.lines, required this.controller});

  /// Splits the view's height in half to center a line in it.
  static const int _halves = 2;

  /// The diff scroller this map follows and drives.
  final ScrollController controller;

  /// Every row of the diff.
  final List<DiffLine> lines;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        void scrollTo(double dy) => _scrollTo(dy, constraints.maxHeight);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (details) => scrollTo(details.localPosition.dy),
          onVerticalDragUpdate: (details) => scrollTo(details.localPosition.dy),
          child: CustomPaint(
            size: Size(AppSize.diffMinimapWidth, constraints.maxHeight),
            painter: _DiffMinimapPainter(
              lines: lines,
              controller: controller,
              viewportColor: Theme.of(context).colorScheme.onSurface
                  .withValues(alpha: AppOpacity.subtle),
            ),
          ),
        );
      },
    );
  }

  /// Centers the view on the line at [dy] down a map [height] tall.
  void _scrollTo(double dy, double height) {
    if (!controller.hasClients || height <= 0) return;
    final position = controller.position;
    final contentOffset = dy / height * lines.length * AppSize.diffRowHeight;
    controller.jumpTo(
      (contentOffset - position.viewportDimension / _halves).clamp(
        position.minScrollExtent,
        position.maxScrollExtent,
      ),
    );
  }
}

/// Paints the minimap's change marks and its in-view band, repainting as
/// the diff scrolls.
class _DiffMinimapPainter extends CustomPainter {
  _DiffMinimapPainter({
    required this.lines,
    required this.controller,
    required this.viewportColor,
  }) : super(repaint: controller);

  /// The diff scroller whose in-view part is shaded.
  final ScrollController controller;

  /// Every row of the diff.
  final List<DiffLine> lines;

  /// Fill of the band showing the part in view.
  final Color viewportColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (lines.isEmpty) return;
    final lineHeight = size.height / lines.length;
    _paintViewport(canvas, size, lineHeight);
    // One mark per run of same-type changed lines.
    var runStart = 0;
    for (var i = 1; i <= lines.length; i++) {
      final type = lines[runStart].type;
      if (i < lines.length && lines[i].type == type) continue;
      final color = type.markColor;
      if (color != null) {
        canvas.drawRect(
          Rect.fromLTWH(
            0,
            runStart * lineHeight,
            size.width,
            ((i - runStart) * lineHeight).clamp(
              AppSize.diffMinimapMinMark,
              size.height,
            ),
          ),
          Paint()..color = color,
        );
      }
      runStart = i;
    }
  }

  @override
  bool shouldRepaint(_DiffMinimapPainter oldDelegate) =>
      oldDelegate.lines != lines ||
      oldDelegate.controller != controller ||
      oldDelegate.viewportColor != viewportColor;

  /// Shades the lines in view, each [lineHeight] tall on the map.
  void _paintViewport(Canvas canvas, Size size, double lineHeight) {
    if (!controller.hasClients) return;
    final position = controller.position;
    final scale = lineHeight / AppSize.diffRowHeight;
    canvas.drawRect(
      Rect.fromLTWH(
        0,
        position.pixels * scale,
        size.width,
        position.viewportDimension * scale,
      ),
      Paint()..color = viewportColor,
    );
  }
}
