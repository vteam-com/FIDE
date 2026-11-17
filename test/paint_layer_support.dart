import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// The layers last painted into the repaint boundary at or above the
/// render object of [finder]: the same layers after a frame mean the
/// boundary was not painted again, new ones that it was.
List<Layer> paintedLayers(WidgetTester tester, Finder finder) {
  RenderObject? object = tester.renderObject(finder);
  while (object != null && !object.isRepaintBoundary) {
    object = object.parent;
  }
  final layers = <Layer>[];
  for (
    var layer = object?.debugLayer?.firstChild;
    layer != null;
    layer = layer.nextSibling
  ) {
    layers.add(layer);
  }
  return layers;
}

/// The [CustomPaint] whose painter is of the private type named
/// [painterType].
Finder findPainter(String painterType) => find.byWidgetPredicate(
  (widget) =>
      widget is CustomPaint &&
      (widget.painter ?? widget.foregroundPainter).runtimeType.toString() ==
          painterType,
);

/// Matches layers that are, one by one, the very layers of [expected]:
/// nothing was painted again.
Matcher samePaintedLayers(List<Layer> expected) =>
    pairwiseCompare<Layer, Layer>(
      expected,
      identical,
      'the same painted layer',
    );
