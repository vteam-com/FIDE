import 'dart:typed_data';

import 'package:fide/models/image_diff_mode.dart';
import 'package:fide/widgets/image_diff.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

/// A 2 by 2 PNG of [color].
Uint8List _png(img.Color color) =>
    img.encodePng(img.Image(width: 2, height: 2, numChannels: 4)..clear(color));

void main() {
  final red = _png(img.ColorRgba8(255, 0, 0, 255));
  final blue = _png(img.ColorRgba8(0, 0, 255, 255));

  Future<void> pump(WidgetTester tester, {Uint8List? oldBytes}) async {
    tester.view
      ..physicalSize = const Size(1280, 800)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: ImageDiff(path: 'a.png', oldBytes: oldBytes, newBytes: blue),
          ),
        ),
      ),
    );
  }

  testWidgets('a file not in HEAD offers 2-up only', (tester) async {
    await pump(tester);

    expect(find.text('Not in HEAD'), findsOneWidget);
    expect(find.byTooltip(ImageDiffMode.twoUp.label), findsOneWidget);
    expect(find.byTooltip(ImageDiffMode.swipe.label), findsNothing);
    expect(find.byTooltip(ImageDiffMode.difference.label), findsNothing);
  });

  testWidgets('every mode shows once the pixels are compared', (tester) async {
    await tester.runAsync(() async {
      await pump(tester, oldBytes: red);
      // The comparison runs on another isolate
      await Future<void>.delayed(const Duration(seconds: 1));
    });
    await tester.pump();

    expect(find.textContaining('2 × 2 px'), findsNWidgets(2));
    for (final mode in ImageDiffMode.values.skip(1)) {
      await tester.tap(find.byTooltip(mode.label));
      await tester.pump();
      expect(
        find.byType(Slider),
        mode == ImageDiffMode.difference ? findsNothing : findsOneWidget,
      );
    }
    expect(find.text('100% of pixels changed'), findsOneWidget);
  });
}
