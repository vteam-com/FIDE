import 'package:fide/widgets/compact_icon_button.dart';
import 'package:fide/widgets/zoom_label.dart';
import 'package:flutter/material.dart';

/// Zoom Out, the zoom in [controller] (resetting it on a click) and Zoom
/// In, for the header of a zoomable view such as the architecture graph or
/// the widget previews.
class ZoomButtons extends StatelessWidget {
  /// Creates the buttons for the zoom in [controller], calling [onZoomOut]
  /// and [onZoomIn].
  const ZoomButtons({
    super.key,
    required this.controller,
    required this.onZoomOut,
    required this.onZoomIn,
  });

  /// Zoom and pan of the view.
  final TransformationController controller;

  /// Zooms the view in.
  final VoidCallback onZoomIn;

  /// Zooms the view out.
  final VoidCallback onZoomOut;
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CompactIconButton.header(
          icon: Icons.zoom_out,
          tooltip: 'Zoom Out',
          onPressed: onZoomOut,
        ),
        ZoomLabel(controller: controller),
        CompactIconButton.header(
          icon: Icons.zoom_in,
          tooltip: 'Zoom In',
          onPressed: onZoomIn,
        ),
      ],
    );
  }
}
