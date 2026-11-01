import 'package:flutter/material.dart';

/// Scales [child] by [zoom], as a browser zooms a page: the child lays out
/// in the space divided by [zoom] and is painted (and hit-tested) enlarged
/// to fill the space, so text, icons and padding all grow together.
class ZoomedView extends StatelessWidget {
  /// Creates a view showing [child] at [zoom].
  const ZoomedView({super.key, required this.zoom, required this.child});

  /// The widget scaled.
  final Widget child;

  /// The scale factor; `1` shows [child] unchanged.
  final double zoom;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return LayoutBuilder(
      builder: (_, constraints) => FittedBox(
        fit: BoxFit.fill,
        alignment: Alignment.topLeft,
        child: SizedBox.fromSize(
          size: constraints.biggest / zoom,
          // Media metrics in the child's logical pixels; the higher pixel
          // ratio keeps images and text sharp when enlarged
          child: MediaQuery(
            data: media.copyWith(
              size: media.size / zoom,
              devicePixelRatio: media.devicePixelRatio * zoom,
              padding: media.padding / zoom,
              viewPadding: media.viewPadding / zoom,
              viewInsets: media.viewInsets / zoom,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
