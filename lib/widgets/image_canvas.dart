import 'package:fide/constants/constants.dart';
import 'package:fide/models/image_backdrop.dart';
import 'package:fide/widgets/image_backdrop_box.dart';
import 'package:flutter/material.dart';

/// The surface an image preview is drawn on: [child] on [backdrop], at
/// most a share of the screen, zoomed by a trackpad pinch or the mouse
/// wheel and panned by dragging. Canvases sharing a [controller] zoom and
/// pan together, as the sides of an image diff do.
class ImageCanvas extends StatelessWidget {
  /// Creates the canvas drawing [child] on [backdrop].
  const ImageCanvas({
    super.key,
    required this.controller,
    required this.backdrop,
    required this.child,
  });

  /// What [child] is drawn on.
  final ImageBackdrop backdrop;

  /// The image, or a stack of images.
  final Widget child;

  /// Zoom and pan of the canvas.
  final TransformationController controller;

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    return InteractiveViewer(
      transformationController: controller,
      minScale: EditorConfig.imagePreviewMinScale,
      maxScale: EditorConfig.imagePreviewMaxScale,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.large),
          child: Container(
            constraints: BoxConstraints(
              maxWidth: screen.width * EditorConfig.imagePreviewMaxWidthFactor,
              maxHeight:
                  screen.height * EditorConfig.imagePreviewMaxHeightFactor,
            ),
            child: ImageBackdropBox(backdrop: backdrop, child: child),
          ),
        ),
      ),
    );
  }
}
