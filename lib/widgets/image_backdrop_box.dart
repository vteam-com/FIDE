import 'dart:math';

import 'package:fide/constants/constants.dart';
import 'package:fide/models/image_backdrop.dart';
import 'package:flutter/material.dart';

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
      ImageBackdrop.rainbow => DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(colors: AppColor.rainbow),
        ),
        child: child,
      ),
    };
  }
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
