part of 'window_rect_reporter.dart';

/// Lays out and paints its child unchanged, and measures it each time it
/// paints: any layout change around it repaints it, so a move it has not
/// reported yet is caught there.
class _RenderWindowRectReporter extends RenderProxyBox {
  _RenderWindowRectReporter({required this.onMoved, required this.view});

  /// Where the child sat in the window when last reported.
  Rect? _reported;

  /// Called with where the child sits in the window, each time it moves.
  ValueChanged<Rect> onMoved;

  /// The window the child is measured in.
  FlutterView view;

  @override
  void paint(PaintingContext context, Offset offset) {
    super.paint(context, offset);
    final window = view.physicalSize / view.devicePixelRatio;
    // A minimized window has no size to place the child in
    if (window.isEmpty) return;
    final rect = MatrixUtils.transformRect(
      getTransformTo(null),
      Offset.zero & size,
    );
    final where = Rect.fromLTRB(
      rect.left / window.width,
      rect.top / window.height,
      rect.right / window.width,
      rect.bottom / window.height,
    );
    if (where == _reported) return;
    _reported = where;
    SchedulerBinding.instance.addPostFrameCallback((_) => onMoved(where));
  }
}
