import 'dart:io';
import 'dart:typed_data';

import 'package:fide/constants/constants.dart';
import 'package:fide/panels/center/editor/editor_screen_font_view.dart';
import 'package:fide/services/font_file_loader.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'widget_test_support.dart';

void main() {
  group('FontFileLoader.isFontData', () {
    test('accepts TrueType, OpenType and collection signatures', () {
      for (final signature in ['\x00\x01\x00\x00', 'true', 'OTTO', 'ttcf']) {
        final bytes = Uint8List.fromList([...signature.codeUnits, 0, 0]);
        expect(FontFileLoader.isFontData(bytes), true, reason: signature);
      }
    });

    test('rejects other and too short data', () {
      expect(
        FontFileLoader.isFontData(Uint8List.fromList('wOFF'.codeUnits)),
        false,
      );
      expect(FontFileLoader.isFontData(Uint8List.fromList([0, 1])), false);
    });
  });

  test('a font sample combines underline and strikethrough', () {
    final style = AppTextStyle.fontSample(
      family: 'Sample',
      fontSize: AppFontSize.title,
      color: Colors.black,
      bold: true,
      italic: true,
      underline: true,
      strikethrough: true,
    );
    expect(style.fontWeight, FontWeight.bold);
    expect(style.fontStyle, FontStyle.italic);
    expect(style.decoration!.contains(TextDecoration.underline), true);
    expect(style.decoration!.contains(TextDecoration.lineThrough), true);
  });

  testWidgets('a file that is not a font says so; the toggles still flip', (
    tester,
  ) async {
    final folder = await tester.runAsync(
      () => Directory.systemTemp.createTemp('fide_font_view'),
    );
    addTearDown(() => folder!.deleteSync(recursive: true));
    final file = File('${folder!.path}/broken.ttf')
      ..writeAsStringSync('not a font');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: EditorScreenFontView(filePath: file.path)),
      ),
    );
    await settle(
      tester,
      until: () => find.text("Can't open this font").evaluate().isNotEmpty,
    );
    expect(find.text("Can't open this font"), findsOneWidget);
    expect(find.text('Not a TrueType or OpenType font'), findsOneWidget);

    expect(find.byTooltip('Bold (OFF)'), findsOneWidget);
    await tester.tap(find.byTooltip('Bold (OFF)'));
    await tester.pump();
    expect(find.byTooltip('Bold (ON)'), findsOneWidget);
    expect(find.byTooltip('White on black'), findsOneWidget);
  });
}
