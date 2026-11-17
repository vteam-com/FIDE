import 'package:fide/constants/constants.dart';
import 'package:material_ui/material_ui.dart';

/// A thin indeterminate horizontal bar telling that a panel is working:
/// the one progress indicator of a panel busy with a single task, drawn
/// across the top edge of its content, right under its header.
///
/// The bar moves on its own layer, so each frame repaints the bar alone,
/// not the content under it.
class BusyBar extends StatelessWidget {
  /// Creates the bar alone.
  const BusyBar({super.key}) : busy = true, child = null;

  /// Creates [child] with the bar across its top edge while [busy].
  const BusyBar.over({
    super.key,
    required this.busy,
    required Widget this.child,
  });

  /// Whether the bar shows.
  final bool busy;

  /// The content under the bar; the bar alone when null.
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    const bar = RepaintBoundary(
      child: LinearProgressIndicator(
        minHeight: AppBorderWidth.medium,
        backgroundColor: Colors.transparent,
      ),
    );
    final child = this.child;
    if (child == null) return bar;
    return Stack(
      // The content keeps the constraints it would get without the bar
      fit: StackFit.passthrough,
      children: [
        child,
        if (busy) const Positioned(top: 0, left: 0, right: 0, child: bar),
      ],
    );
  }
}
