part of 'side_by_side_diff.dart';

/// The strip beside a diff that marks each deleted line red and each added
/// line green at its place in the whole text, shades the part in view, and
/// scrolls there when tapped or dragged.
///
/// The marks are painted once per diff on their own layer; scrolling only
/// moves the band shading the part in view.
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
          // Scrolling repaints the band alone, not the diff around it
          child: RepaintBoundary(
            child: CustomPaint(
              painter: _DiffMinimapBandPainter(
                lineCount: lines.length,
                controller: controller,
                color: Theme.of(context).colorScheme.onSurface
                    .withValues(alpha: AppOpacity.subtle),
              ),
              // Over the band, on a layer of their own: never repainted
              // by scrolling
              child: RepaintBoundary(
                child: CustomPaint(
                  size: Size(AppSize.diffMinimapWidth, constraints.maxHeight),
                  painter: _DiffMinimapMarksPainter(lines: lines),
                ),
              ),
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

/// Paints the minimap's band shading the lines in view, repainting as the
/// diff scrolls.
class _DiffMinimapBandPainter extends CustomPainter {
  _DiffMinimapBandPainter({
    required this.lineCount,
    required this.controller,
    required Color color,
  }) : _band = Paint()..color = color,
       super(repaint: controller);

  /// The diff scroller whose in-view part is shaded.
  final ScrollController controller;

  /// How many rows the diff has.
  final int lineCount;

  /// Fill of the band, made once for every scroll frame.
  final Paint _band;

  @override
  void paint(Canvas canvas, Size size) {
    if (lineCount == 0 || !controller.hasClients) return;
    final position = controller.position;
    final scale = size.height / lineCount / AppSize.diffRowHeight;
    canvas.drawRect(
      Rect.fromLTWH(
        0,
        position.pixels * scale,
        size.width,
        position.viewportDimension * scale,
      ),
      _band,
    );
  }

  @override
  bool shouldRepaint(_DiffMinimapBandPainter oldDelegate) =>
      oldDelegate.lineCount != lineCount ||
      oldDelegate.controller != controller ||
      oldDelegate._band.color != _band.color;
}

/// Paints the minimap's change marks, one per run of same-type changed
/// lines; repaints only when the diff changes.
class _DiffMinimapMarksPainter extends CustomPainter {
  _DiffMinimapMarksPainter({required this.lines});

  /// Every row of the diff.
  final List<DiffLine> lines;

  @override
  void paint(Canvas canvas, Size size) {
    if (lines.isEmpty) return;
    final lineHeight = size.height / lines.length;
    final mark = Paint();
    var runStart = 0;
    for (var i = 1; i <= lines.length; i++) {
      final type = lines[runStart].type;
      if (i < lines.length && lines[i].type == type) continue;
      final color = type.tone?.color;
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
          mark..color = color,
        );
      }
      runStart = i;
    }
  }

  @override
  bool shouldRepaint(_DiffMinimapMarksPainter oldDelegate) =>
      oldDelegate.lines != lines;
}
