import 'dart:ui' as ui;

import 'package:fide/widgets/pixel_image.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late ui.Image image;

  setUp(() async => image = await createTestImage(width: 16, height: 16));
  tearDown(() => image.dispose());

  /// The filter the image was last painted with.
  FilterQuality? filterOf(WidgetTester tester) {
    FilterQuality? quality;
    expect(
      tester.renderObject(find.byType(PixelRawImage)),
      paints..something((method, arguments) {
        if (method != #drawImageRect) return false;
        quality = (arguments.last as Paint).filterQuality;
        return true;
      }),
    );
    return quality;
  }

  Future<void> pump(WidgetTester tester, double side, {double zoom = 1}) {
    return tester.pumpWidget(
      Center(
        child: Transform.scale(
          scale: zoom,
          child: PixelRawImage(image: image, width: side, height: side),
        ),
      ),
    );
  }

  testWidgets('enlarged pixels stay sharp squares', (tester) async {
    await pump(tester, 128);
    expect(filterOf(tester), FilterQuality.none);
  });

  testWidgets('shrunk pixels are smoothed', (tester) async {
    await pump(tester, 4);
    expect(filterOf(tester), FilterQuality.medium);
  });

  testWidgets('zooming in above the image sharpens it', (tester) async {
    await pump(tester, 4, zoom: 8);
    expect(filterOf(tester), FilterQuality.none);
  });
}
