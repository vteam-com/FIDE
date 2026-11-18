import 'package:fide/providers/side_panel.dart';
import 'package:fide/widget_services/panel_island.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

/// Width of the left island, kept as the gap before it changes.
const double _leftWidth = 200;

/// Width of the right island.
const double _rightWidth = 300;

/// Lays out, in the 800 by 600 test window, a gap [gap] wide, then the left
/// island, the editor island and the right island.
Widget _layout(ProviderContainer container, double gap) =>
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(width: gap),
            const SizedBox(
              width: _leftWidth,
              child: PanelIsland(panel: SidePanel.left, child: SizedBox()),
            ),
            const Expanded(child: PanelIsland(child: SizedBox())),
            const SizedBox(
              width: _rightWidth,
              child: PanelIsland(panel: SidePanel.right, child: SizedBox()),
            ),
          ],
        ),
      ),
    );

void main() {
  testWidgets('islands report where the layout puts them in the window', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    Rect? rect(SidePanel? panel) =>
        container.read(islandWindowRectProvider(panel));

    await tester.pumpWidget(_layout(container, 0));
    // The left island from 0 to 200 of 800, the editor from 200 to 500
    expect(rect(SidePanel.left), const Rect.fromLTRB(0, 0, 0.25, 1));
    expect(rect(null), const Rect.fromLTRB(0.25, 0, 0.625, 1));
    expect(rect(SidePanel.right), const Rect.fromLTRB(0.625, 0, 1, 1));

    // The left island moves without resizing, the editor narrows to 300 to
    // 500
    await tester.pumpWidget(_layout(container, 100));
    expect(rect(SidePanel.left), const Rect.fromLTRB(0.125, 0, 0.375, 1));
    expect(rect(null), const Rect.fromLTRB(0.375, 0, 0.625, 1));
    expect(rect(SidePanel.right), const Rect.fromLTRB(0.625, 0, 1, 1));
  });
}
