import 'dart:ui' show FlutterView;

import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

part 'window_rect_reporter.render.dart';

/// Tells [onMoved] where [child] sits in the window, as fractions of the
/// window's width and height: once it first paints, then each time the
/// window, the zoom or the layout around it moves or resizes it.
///
/// It reports after the frame, so [onMoved] may change app state.
class WindowRectReporter extends SingleChildRenderObjectWidget {
  /// Creates a reporter telling [onMoved] where [child] sits.
  const WindowRectReporter({super.key, required this.onMoved, super.child});

  /// Called with where [child] sits in the window, each time it moves.
  final ValueChanged<Rect> onMoved;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderWindowRectReporter(onMoved: onMoved, view: View.of(context));

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) {
    (renderObject as _RenderWindowRectReporter)
      ..onMoved = onMoved
      ..view = View.of(context);
  }
}
