import 'dart:math';
import 'dart:ui' show lerpDouble;

import 'package:fide/constants/constants.dart';
import 'package:fide/models/image_backdrop.dart';
import 'package:material_ui/material_ui.dart';

/// Draws [child], an image or a widget preview, on [backdrop].
class ImageBackdropBox extends StatelessWidget {
  /// Creates [child] drawn on [backdrop].
  const ImageBackdropBox({
    super.key,
    required this.backdrop,
    required this.child,
  });

  /// What [child] is drawn on.
  final ImageBackdrop backdrop;

  /// The image.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return switch (backdrop) {
      ImageBackdrop.transparent => CustomPaint(
        painter: _TransparencyPainter(),
        child: child,
      ),
      ImageBackdrop.black => ColoredBox(color: Colors.black, child: child),
      ImageBackdrop.white => ColoredBox(color: Colors.white, child: child),
      ImageBackdrop.blend => CustomPaint(
        painter: _BlendPainter(),
        child: child,
      ),
    };
  }
}

/// The blend backdrop: [AppColor.blendSpots] melting into one another over
/// [AppColor.blendBase], in near-square cells along the box's longest
/// side, so a long, short box, such as a wide widget preview, shows them
/// as densely as a square one, not as small dots far apart.
///
/// The first cell lays the spots out as [AppColor.blendSpots] places them;
/// each other cell shuffles their colors and moves them a little, from a
/// seed of its own, so the cells never look repeated yet the backdrop is
/// the same on every paint.
class _BlendPainter extends CustomPainter {
  /// The spots of the cell at [index]: the base layout for the first,
  /// else its colors shuffled and its places moved by up to
  /// [AppGradient.blendSpotJitter].
  static List<({Alignment center, Color color})> _spotsOf(int index) {
    const spots = AppColor.blendSpots;
    if (index == 0) return spots;
    final random = Random(index);
    final colors = [for (final spot in spots) spot.color]..shuffle(random);
    const jitter = AppGradient.blendSpotJitter;
    double moved(double value) =>
        (value + lerpDouble(-jitter, jitter, random.nextDouble())!).clamp(
          -1,
          1,
        );
    return [
      for (final (position, spot) in spots.indexed)
        (
          center: Alignment(moved(spot.center.x), moved(spot.center.y)),
          color: colors[position],
        ),
    ];
  }

  @override
  void paint(Canvas canvas, Size size) {
    final box = Offset.zero & size;
    canvas
      ..clipRect(box)
      ..drawRect(box, Paint()..color = AppColor.blendBase);
    final shortest = size.shortestSide;
    if (shortest <= 0) return;
    final isWide = size.width >= size.height;
    final cells = max(1, (size.longestSide / shortest).round());
    final cell = isWide
        ? Size(size.width / cells, size.height)
        : Size(size.width, size.height / cells);
    final radius = AppGradient.blendSpotRadius * shortest;
    final layouts = [
      for (var index = 0; index < cells; index++) _spotsOf(index),
    ];
    final paint = Paint();
    // Each cell's first spot on top; spots spill into the neighbor cells,
    // so they join without a seam
    for (var layer = AppColor.blendSpots.length - 1; layer >= 0; layer--) {
      for (final (index, spots) in layouts.indexed) {
        final origin = isWide
            ? Offset(cell.width * index, 0)
            : Offset(0, cell.height * index);
        final spot = spots[layer];
        final center = spot.center.withinRect(origin & cell);
        paint.shader = RadialGradient(
          colors: [spot.color, spot.color.withValues(alpha: 0)],
        ).createShader(Rect.fromCircle(center: center, radius: radius));
        canvas.drawCircle(center, radius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_BlendPainter oldDelegate) => false;
}

/// A checkerboard behind an image, so its transparent parts show as such,
/// light or dark artwork alike.
class _TransparencyPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = AppColor.transparencyLight,
    );
    final dark = Paint()..color = AppColor.transparencyDark;
    const square = AppSize.transparencySquare;
    for (var y = 0.0; y < size.height; y += square) {
      for (var x = 0.0; x < size.width; x += square) {
        if (((x + y) / square).round().isOdd) {
          canvas.drawRect(
            Rect.fromLTWH(
              x,
              y,
              min(square, size.width - x),
              min(square, size.height - y),
            ),
            dark,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(_TransparencyPainter oldDelegate) => false;
}
