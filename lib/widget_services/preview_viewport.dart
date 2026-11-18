import 'package:fide/providers/preview_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// Tells the previews, once the frame is laid out, the [width] of the
/// list showing them, the [zoom] they are drawn at, and the screen's pixel
/// ratio and FIDE's brightness from [context], so they lay out and render
/// to fit.
void configurePreviewViewport(
  WidgetRef ref,
  BuildContext context,
  double width,
  double zoom,
) {
  final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
  final brightness = Theme.of(context).brightness;
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!context.mounted) return;
    ref
        .read(previewControllerProvider.notifier)
        .configure(
          width: width,
          devicePixelRatio: devicePixelRatio,
          zoom: zoom,
          appBrightness: brightness,
        );
  });
}
