import 'dart:math';

import 'package:fide/constants/constants.dart';
import 'package:fide/models/image_backdrop.dart';
import 'package:material_ui/material_ui.dart';

/// Draws [child], an image, on [backdrop].
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
      ImageBackdrop.blend => ColoredBox(
        color: AppColor.blendBase,
        child: AppColor.blendSpots.fold<Widget>(child, _overSpot),
      ),
    };
  }

  /// Draws [inner] over [spot], a radial glow of its color fading out to
  /// the same color fully transparent, so its edge never darkens.
  static Widget _overSpot(
    Widget inner,
    ({Alignment center, Color color}) spot,
  ) => DecoratedBox(
    decoration: BoxDecoration(
      gradient: RadialGradient(
        center: spot.center,
        radius: AppGradient.blendSpotRadius,
        colors: [spot.color, spot.color.withValues(alpha: 0)],
      ),
    ),
    child: inner,
  );
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
