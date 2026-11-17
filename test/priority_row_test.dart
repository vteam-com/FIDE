import 'package:fide/widgets/compact_text_button.dart';
import 'package:fide/widgets/section_panel.dart';
import 'package:fide/widgets/tree_row.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

/// Indentation deep enough to outgrow [_tinyWidth] on its own.
const _deepDepth = 12;

/// A panel with room for everything.
const double _wideWidth = 800;

/// A panel too narrow for labeled actions, wide enough for icons.
const double _narrowWidth = 300;

/// A panel too narrow for any extra beside the title.
const double _tinyWidth = 100;

/// Pumps [child] in a panel [width] wide.
Future<void> _pumpIn(WidgetTester tester, double width, Widget child) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(width: width, child: child),
        ),
      ),
    ),
  );
}

/// A section with the Git panel's kind of labeled actions.
SectionPanel _section() => SectionPanel(
  title: 'Changes',
  rightWidget: Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      CompactTextButton(icon: Icons.add, label: 'Stage All', onPressed: () {}),
      CompactTextButton(
        icon: Icons.delete_outline,
        label: 'Discard All',
        onPressed: () {},
      ),
    ],
  ),
);

void main() {
  testWidgets('a section header keeps its title on one line as it narrows: '
      'labeled actions, then icons, then none', (tester) async {
    final title = find.text('Changes');
    final label = find.text('Stage All').hitTestable();
    final icon = find.byIcon(Icons.add).hitTestable();

    await _pumpIn(tester, _wideWidth, _section());
    final lineHeight = tester.getSize(title).height;
    expect(label, findsOneWidget);

    await _pumpIn(tester, _narrowWidth, _section());
    expect(label, findsNothing);
    expect(icon, findsOneWidget);
    expect(tester.getSize(title).height, lineHeight);

    await _pumpIn(tester, _tinyWidth, _section());
    expect(tester.takeException(), isNull);
    expect(icon, findsNothing);
    expect(tester.getSize(title).height, lineHeight);
  });

  testWidgets('a tree row hides its details before squeezing its name', (
    tester,
  ) async {
    const row = TreeRow(
      icon: Icon(Icons.commit),
      name: 'fix icons',
      trailing: [Text('d917578 · 2 weeks ago')],
    );
    final details = find.text('d917578 · 2 weeks ago').hitTestable();

    await _pumpIn(tester, _wideWidth, row);
    expect(details, findsOneWidget);

    await _pumpIn(tester, _narrowWidth, row);
    expect(details, findsNothing);
    expect(find.text('fix icons').hitTestable(), findsOneWidget);
  });

  testWidgets('a deep tree row in a tiny panel clips, not overflows', (
    tester,
  ) async {
    await _pumpIn(
      tester,
      _tinyWidth,
      const TreeRow(
        icon: Icon(Icons.folder),
        name: 'lib',
        depth: _deepDepth,
        trailing: [Icon(Icons.lock), Icon(Icons.error)],
      ),
    );
    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(TreeRow)).width, _tinyWidth);
  });
}
