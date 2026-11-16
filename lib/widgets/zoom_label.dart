import 'package:fide/constants/constants.dart';
import 'package:fide/widgets/compact_text_button.dart';
import 'package:material_ui/material_ui.dart';

/// A zoom as a percent, pressed to return to actual size; disabled while
/// already there.
///
/// The one zoom readout of the app: the UI zoom in Settings, an image
/// preview, the architecture graph and the widget previews all show it.
class ZoomLabel extends StatelessWidget {
  /// Creates the label for [scale], calling [onReset] when pressed.
  const ZoomLabel({
    super.key,
    required double this.scale,
    required VoidCallback this.onReset,
    this.tooltip = defaultTooltip,
  }) : controller = null;

  /// Creates the label for the zoom in [controller], resetting it to
  /// identity when pressed.
  const ZoomLabel.canvas({
    super.key,
    required TransformationController this.controller,
  }) : scale = null,
       onReset = null,
       tooltip = defaultTooltip;

  /// Zoom and pan of a canvas, followed live; null for a fixed [scale].
  final TransformationController? controller;

  /// Hover text when none is given.
  static const String defaultTooltip = 'Actual Size';

  /// Returns to actual size; null when [controller] does.
  final VoidCallback? onReset;

  /// The zoom shown, [AppZoom.actualSize] for unscaled; null when read
  /// from [controller].
  final double? scale;

  /// Hover text, such as the reset action and its shortcut.
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final controller = this.controller;
    if (controller == null) return _build(scale!, onReset!);
    return ListenableBuilder(
      listenable: controller,
      builder: (_, _) => _build(
        controller.value.getMaxScaleOnAxis(),
        () => controller.value = Matrix4.identity(),
      ),
    );
  }

  /// The button for [zoom], calling [reset] unless already actual size.
  Widget _build(double zoom, VoidCallback reset) {
    return CompactTextButton(
      label: AppZoom.label(zoom),
      tooltip: tooltip,
      onPressed: zoom == AppZoom.actualSize ? null : reset,
    );
  }
}
