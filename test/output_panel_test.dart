import 'dart:io';

import 'package:fide/widget_services/output_panel.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  /// Shows an [OutputPanel] of [text], cleared by [onClear] and fixed by
  /// [onFixWithAi].
  Future<void> show(
    WidgetTester tester,
    String text, {
    VoidCallback? onClear,
    VoidCallback? onFixWithAi,
  }) => tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: OutputPanel(
            title: 'Output',
            isExpanded: true,
            text: text,
            onClear: onClear ?? () {},
            onFixWithAi: onFixWithAi,
          ),
        ),
      ),
    ),
  );

  testWidgets('every output offers to clear it', (tester) async {
    var clears = 0;
    await show(tester, 'done', onClear: () => clears++);

    await tester.tap(find.byTooltip('Clear output').hitTestable());

    expect(clears, 1);
  });

  testWidgets('offers Fix with AI only when the output can be fixed', (
    tester,
  ) async {
    await show(tester, 'error');
    expect(find.byTooltip('Fix with AI'), findsNothing);

    var fixes = 0;
    await show(tester, 'error', onFixWithAi: () => fixes++);
    await tester.tap(find.byTooltip('Fix with AI').hitTestable());

    expect(fixes, 1);
  });

  /// The link spans of the panel's text, by their text.
  Map<String, TapGestureRecognizer> links(WidgetTester tester) {
    final text = tester.widget<SelectableText>(find.byType(SelectableText));
    final found = <String, TapGestureRecognizer>{};
    text.textSpan!.visitChildren((span) {
      if (span is TextSpan && span.recognizer is TapGestureRecognizer) {
        found[span.text!] = span.recognizer! as TapGestureRecognizer;
      }
      return true;
    });
    return found;
  }

  testWidgets('links references in appended text, keeping earlier links', (
    tester,
  ) async {
    final folder = Directory.systemTemp.createTempSync('output_panel_');
    addTearDown(() => folder.deleteSync(recursive: true));
    final first = '${folder.path}/a.dart';
    final second = '${folder.path}/b.dart';
    File(first).writeAsStringSync('');
    File(second).writeAsStringSync('');

    final before = 'error at $first:3:5\n';
    await show(tester, before);
    final firstLink = links(tester)['$first:3:5'];
    expect(firstLink, isNotNull);

    await show(tester, '${before}error at $second:7\n');

    final after = links(tester);
    expect(after.keys, ['$first:3:5', '$second:7']);
    expect(identical(after['$first:3:5'], firstLink), isTrue);
  });

  testWidgets('links again a text that does not extend the old one', (
    tester,
  ) async {
    final folder = Directory.systemTemp.createTempSync('output_panel_');
    addTearDown(() => folder.deleteSync(recursive: true));
    final file = '${folder.path}/a.dart';
    File(file).writeAsStringSync('');

    await show(tester, 'old line\nerror at $file:3\n');
    final link = links(tester)['$file:3'];

    await show(tester, 'error at $file:3\nnew line\n');

    // The same place keeps its recognizer at its new offset
    expect(identical(links(tester)['$file:3'], link), isTrue);
  });
}
