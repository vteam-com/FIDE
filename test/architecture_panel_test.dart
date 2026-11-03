import 'package:fide/models/architecture_graph.dart';
import 'package:fide/models/architecture_layout.dart';
import 'package:fide/panels/center/architecture/architecture_panel.dart';
import 'package:fide/providers/app_providers.dart';
import 'package:fide/providers/architecture_providers.dart';
import 'package:fide/providers/center_view.dart';
import 'package:fide/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// `main` importing `home`, which imports `model`, in layers 1 to 3.
final _layout = ArchitectureLayout(
  ArchitectureGraph(
    rootPath: '/p',
    files: ['/p/lib/main.dart', '/p/lib/ui/home.dart', '/p/lib/model.dart'],
    callees: {
      '/p/lib/main.dart': ['/p/lib/ui/home.dart'],
      '/p/lib/ui/home.dart': ['/p/lib/model.dart'],
    },
    layers: {
      '/p/lib/main.dart': 1,
      '/p/lib/ui/home.dart': 2,
      '/p/lib/model.dart': 3,
    },
  ),
);

void main() {
  /// Shows the Architecture view of [_layout]; returns its provider scope.
  Future<ProviderContainer> pumpPanel(WidgetTester tester) async {
    final container = ProviderContainer(
      overrides: [architectureLayoutProvider.overrideWith((_) => _layout)],
    );
    addTearDown(container.dispose);
    container.read(centerViewProvider.notifier).state = CenterView.architecture;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(body: ArchitecturePanel()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('lists every file under its layer', (tester) async {
    await pumpPanel(tester);

    expect(find.textContaining('Layer 1'), findsOneWidget);
    expect(find.textContaining('Layer 3'), findsOneWidget);
    expect(find.text('home.dart'), findsOneWidget);
    expect(find.textContaining('2 imports'), findsOneWidget);
  });

  testWidgets('selecting a file lists its imports and importers', (
    tester,
  ) async {
    await pumpPanel(tester);

    await tester.tap(find.text('home.dart'));
    await tester.pumpAndSettle();

    expect(find.text('IMPORTS'), findsOneWidget);
    expect(find.text('IMPORTED BY'), findsOneWidget);
    // The graph's box and the details' row of each related file
    expect(find.text('model.dart'), findsNWidgets(2));
    expect(find.text('main.dart'), findsNWidgets(2));
  });

  testWidgets('opening a file leaves the view, remembering it for the close', (
    tester,
  ) async {
    final container = await pumpPanel(tester);

    await tester.tap(find.text('home.dart'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, 'Open').first);
    await tester.pumpAndSettle();

    expect(container.read(selectedFileProvider)?.path, '/p/lib/ui/home.dart');
    expect(container.read(centerViewProvider), isNull);
    expect(container.read(centerViewOpenedFileProvider), (
      view: CenterView.architecture,
      path: '/p/lib/ui/home.dart',
    ));
  });
}
