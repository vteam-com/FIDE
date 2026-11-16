import 'package:fide/widgets/compact_icon_button.dart';
import 'package:fide/widgets/zoom_label.dart';
import 'package:material_ui/material_ui.dart';

/// Zoom Out, the current zoom (resetting it on a click) and Zoom In.
///
/// The one set of zoom controls of the app: the UI zoom in Settings and
/// the zoomable views (architecture graph, widget previews) all use it.
class ZoomButtons extends StatelessWidget {
  /// Creates the buttons around [label], calling [onZoomOut] and
  /// [onZoomIn]; a null callback disables its button, such as at the last
  /// zoom level.
  const ZoomButtons({
    super.key,
    required this.label,
    required this.onZoomOut,
    required this.onZoomIn,
    this.zoomOutTooltip = 'Zoom Out',
    this.zoomInTooltip = 'Zoom In',
  });

  /// Creates the buttons for the zoom in [controller], calling
  /// [onZoomOut] and [onZoomIn].
  ZoomButtons.canvas({
    super.key,
    required TransformationController controller,
    required this.onZoomOut,
    required this.onZoomIn,
  }) : label = ZoomLabel.canvas(controller: controller),
       zoomOutTooltip = 'Zoom Out',
       zoomInTooltip = 'Zoom In';

  /// The current zoom between the buttons.
  final ZoomLabel label;

  /// Zooms in; the button is disabled when null.
  final VoidCallback? onZoomIn;

  /// Zooms out; the button is disabled when null.
  final VoidCallback? onZoomOut;

  /// Hover text of Zoom In, such as the action and its shortcut.
  final String zoomInTooltip;

  /// Hover text of Zoom Out, such as the action and its shortcut.
  final String zoomOutTooltip;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CompactIconButton.header(
          icon: Icons.zoom_out,
          tooltip: zoomOutTooltip,
          onPressed: onZoomOut,
        ),
        label,
        CompactIconButton.header(
          icon: Icons.zoom_in,
          tooltip: zoomInTooltip,
          onPressed: onZoomIn,
        ),
      ],
    );
  }
}
