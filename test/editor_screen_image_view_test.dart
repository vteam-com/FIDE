import 'dart:ui';

import 'package:fide/panels/center/editor/editor_screen_image_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('a trackpad pinch zooms the image and the percent resets it', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(1280, 800)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: EditorScreenImageView(filePath: 'assets/app.png'),
          ),
        ),
      ),
    );
    expect(find.text('100%'), findsOneWidget);

    final viewer = tester.getCenter(find.byType(InteractiveViewer));
    final pinch = await tester.createGesture(kind: PointerDeviceKind.trackpad);
    await pinch.panZoomStart(viewer);
    await pinch.panZoomUpdate(viewer, scale: 2);
    await pinch.panZoomEnd();
    await tester.pump();
    expect(find.text('200%'), findsOneWidget);

    await tester.tap(find.text('200%'));
    await tester.pump();
    expect(find.text('100%'), findsOneWidget);
  });
}
