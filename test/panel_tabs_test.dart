import 'package:fide/widgets/panel_tabs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('reports a tap on the selected tab as a reselect', (
    tester,
  ) async {
    final controller = TabController(length: 2, vsync: const TestVSync());
    addTearDown(controller.dispose);
    var reselects = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PanelTabs(
            controller: controller,
            onReselect: () => reselects++,
            tabs: const [
              Tab(text: 'A'),
              Tab(text: 'B'),
            ],
            children: const [Text('a'), Text('b')],
          ),
        ),
      ),
    );

    await tester.tap(find.text('B'));
    await tester.pumpAndSettle();
    expect(controller.index, 1);
    expect(reselects, 0);

    await tester.tap(find.text('B'));
    await tester.pumpAndSettle();
    expect(reselects, 1);
  });
}
