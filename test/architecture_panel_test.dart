import 'package:fide/models/architecture_focus.dart';
import 'package:fide/models/architecture_graph.dart';
import 'package:fide/models/architecture_layout.dart';
import 'package:fide/panels/center/architecture/architecture_edge_painter.dart';
import 'package:fide/panels/center/architecture/architecture_edge_paths.dart';
import 'package:fide/panels/center/architecture/architecture_node.dart';
import 'package:fide/panels/center/architecture/architecture_panel.dart';
import 'package:fide/providers/app_providers.dart';
import 'package:fide/providers/architecture_orientation_notifier.dart';
import 'package:fide/providers/architecture_providers.dart';
import 'package:fide/providers/center_view.dart';
import 'package:fide/theme/app_theme.dart';
import 'package:flutter/gestures.dart';
import 'package:material_ui/material_ui.dart';
import 'package:fide/widget_services/project_refresh_button.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'paint_layer_support.dart';

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
  /// Shows the Architecture view of [layout]; returns its provider scope.
  Future<ProviderContainer> pumpPanel(
    WidgetTester tester, {
    ArchitectureLayout? layout,
  }) async {
    final container = ProviderContainer(
      overrides: [
        architectureLayoutProvider.overrideWith((_) => layout ?? _layout),
      ],
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

  testWidgets('its Refresh checks the project again, as the project '
      "header's does", (tester) async {
    await pumpPanel(tester);

    expect(find.byType(ProjectRefreshButton), findsOneWidget);
  });

  testWidgets('selecting a file lists its imports and importers', (
    tester,
  ) async {
    await pumpPanel(tester);

    await tester.tap(find.text('home.dart'));
    await tester.pumpAndSettle();

    expect(find.text('Imports'), findsOneWidget);
    expect(find.text('Imported by'), findsOneWidget);
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
    await tester.tap(find.text('Open in FIDE'));
    await tester.pumpAndSettle();

    expect(container.read(selectedFileProvider)?.path, '/p/lib/ui/home.dart');
    expect(container.read(centerViewProvider), isNull);
    expect(container.read(centerViewOpenedFileProvider), (
      view: CenterView.architecture,
      path: '/p/lib/ui/home.dart',
    ));
  });

  testWidgets('the orientation button stacks the layers the other way', (
    tester,
  ) async {
    final container = await pumpPanel(tester);
    expect(
      container.read(architectureOrientationProvider),
      ArchitectureOrientation.topDown,
    );

    await tester.tap(find.byIcon(Icons.view_agenda_outlined));
    await tester.pumpAndSettle();

    expect(
      container.read(architectureOrientationProvider),
      ArchitectureOrientation.leftToRight,
    );
    expect(find.byIcon(Icons.view_week_outlined), findsOneWidget);
  });

  for (final width in [1600.0, 600.0]) {
    testWidgets('the toolbar ends with Close at the right edge, $width wide', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await pumpPanel(tester);

      final close = tester.getRect(find.byTooltip('Close'));
      expect(close.right, width);
      // Nothing overflows: the counts and the Find File box give way
      expect(tester.takeException(), isNull);
    });
  }

  group('performance', () {
    /// [_layout] with `util`, which nothing imports, beside `model`.
    final layout = ArchitectureLayout(
      ArchitectureGraph(
        rootPath: '/p',
        files: [
          '/p/lib/main.dart',
          '/p/lib/ui/home.dart',
          '/p/lib/model.dart',
          '/p/lib/util.dart',
        ],
        callees: {
          '/p/lib/main.dart': ['/p/lib/ui/home.dart'],
          '/p/lib/ui/home.dart': ['/p/lib/model.dart'],
        },
        layers: {
          '/p/lib/main.dart': 1,
          '/p/lib/ui/home.dart': 2,
          '/p/lib/model.dart': 3,
          '/p/lib/util.dart': 3,
        },
      ),
    );

    /// The box of the file named [name].
    ArchitectureNode node(WidgetTester tester, String name) => tester.widget(
      find.ancestor(
        of: find.text(name),
        matching: find.byType(ArchitectureNode),
      ),
    );

    testWidgets('hovering a file rebuilds neither the toolbar nor the boxes '
        'whose look stays the same', (tester) async {
      await pumpPanel(tester, layout: layout);
      final title = tester.widget(find.text('Architecture'));
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(mouse.removePointer);
      await mouse.addPointer(location: Offset.zero);

      await mouse.moveTo(tester.getCenter(find.text('home.dart')));
      await tester.pump();
      final util = node(tester, 'util.dart');
      final home = node(tester, 'home.dart');
      expect(util.role, ArchitectureRole.dimmed);
      expect(home.role, ArchitectureRole.focused);

      // Straight from one file to the next, through no focus in between
      await mouse.moveTo(tester.getCenter(find.text('model.dart')));
      await tester.pump();

      expect(tester.widget(find.text('Architecture')), same(title));
      expect(node(tester, 'util.dart'), same(util));
      expect(node(tester, 'home.dart'), isNot(same(home)));
      expect(node(tester, 'home.dart').role, ArchitectureRole.caller);
      expect(node(tester, 'model.dart').role, ArchitectureRole.focused);
      // Dimmed under a veil, without a layer per box
      expect(
        find.descendant(
          of: find.byType(ArchitectureNode),
          matching: find.byType(Opacity),
        ),
        findsNothing,
      );
    });

    testWidgets('panning moves the painted imports without painting them', (
      tester,
    ) async {
      await pumpPanel(tester, layout: layout);
      final edges = find.byWidgetPredicate(
        (widget) =>
            widget is CustomPaint && widget.painter is ArchitectureEdgePainter,
      );
      expect(edges, findsNWidgets(2));
      final before = [
        for (final element in edges.evaluate())
          paintedLayers(tester, find.byElementPredicate((e) => e == element)),
      ];
      final paths = ArchitectureEdgePaths.of(layout);
      final home = tester.getCenter(find.text('home.dart'));

      await tester.dragFrom(
        tester.getTopLeft(find.byType(InteractiveViewer)) + const Offset(5, 5),
        const Offset(60, 40),
      );
      await tester.pump();

      expect(tester.getCenter(find.text('home.dart')), isNot(home));
      final after = [
        for (final element in edges.evaluate())
          paintedLayers(tester, find.byElementPredicate((e) => e == element)),
      ];
      for (final (index, layers) in after.indexed) {
        expect(layers, samePaintedLayers(before[index]));
      }
      expect(ArchitectureEdgePaths.of(layout), same(paths));
      expect(paths.all, hasLength(2));
      expect(paths.touching('/p/lib/ui/home.dart'), hasLength(2));
    });
  });
}
