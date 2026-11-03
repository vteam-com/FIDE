import 'package:fide/constants/constants.dart';
import 'package:fide/widgets/compact_text_button.dart';
import 'package:flutter/material.dart';

/// The zoom of a zoomable canvas (an image preview, the architecture
/// graph) as a percent, pressed to return to actual size; disabled while
/// already there.
class ZoomLabel extends StatelessWidget {
  /// Creates the label for the zoom in [controller].
  const ZoomLabel({super.key, required this.controller});

  /// Zoom and pan of the canvas.
  final TransformationController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (_, _) {
        final scale = controller.value.getMaxScaleOnAxis();
        return Tooltip(
          message: 'Actual Size',
          child: CompactTextButton(
            label: AppZoom.label(scale),
            onPressed: scale == AppZoom.actualSize
                ? null
                : () => controller.value = Matrix4.identity(),
          ),
        );
      },
    );
  }
}
