import 'package:fide/models/preview_item.dart';
import 'package:fide/models/preview_scan.dart';
import 'package:fide/models/preview_scope.dart';
import 'package:fide/panels/right/preview_panel.dart';
import 'package:fide/providers/app_providers.dart';
import 'package:fide/providers/preview_controller.dart';
import 'package:fide/services/preview_scanner.dart';
import 'package:fide/widgets/inline_spinner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A controller showing [shown] without scanning or running a host.
class _FakeController extends PreviewController {
  _FakeController(this.shown);

  final PreviewState shown;
  final List<String> toggled = [];

  @override
  PreviewState build() => shown;

  @override
  void toggle(String path, String label) => toggled.add(label);

  @override
  void configure({
    required double width,
    required double devicePixelRatio,
    required double zoom,
    required Brightness appBrightness,
  }) {}
}

/// Width of a narrow right panel, where the toolbar must wrap.
const double _narrowPanel = 234;

const String _project = '/work/app';

PreviewScan _scan(String source) => const PreviewScanner().scan(source);

Future<_FakeController> _pump(WidgetTester tester, PreviewState state) async {
  SharedPreferences.setMockInitialValues({});
  final controller = _FakeController(state);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        previewControllerProvider.overrideWith(() => controller),
        currentProjectPathProvider.overrideWith((_) => _project),
      ],
      child: const MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(width: _narrowPanel, child: PreviewPanel()),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  return controller;
}

void main() {
  final cards = _scan('''
@Preview(name: 'Light')
Widget lightPreview() => const SizedBox();

@Preview()
Widget darkPreview() => const SizedBox();
''');
  final badge = _scan("@Preview()\nWidget badgePreview() => const SizedBox();");

  final project = PreviewState(
    scope: PreviewScope.project,
    status: PreviewStatus.ready,
    projectFiles: [
      (path: '$_project/lib/cards.dart', scan: cards),
      (path: '$_project/lib/badge.dart', scan: badge),
    ],
    expanded: (path: '$_project/lib/cards.dart', label: 'darkPreview'),
    items: const [PreviewItem(function: 'darkPreview', line: 4, group: 'G')],
  );

  testWidgets('lists the project previews, only the expanded one open', (
    tester,
  ) async {
    final controller = await _pump(tester, project);
    expect(tester.takeException(), isNull);
    // The path as everywhere: its folders dimmed, its name bold
    expect(find.text('lib/'), findsWidgets);
    expect(find.text('cards.dart'), findsOneWidget);
    expect(find.text('lightPreview'), findsOneWidget);
    expect(find.text('badgePreview'), findsOneWidget);
    // The expanded preview waits for its first frame; the others render
    // nothing
    expect(find.byIcon(Icons.expand_more), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right), findsNWidgets(2));
    expect(find.byType(InlineSpinner), findsOneWidget);

    await tester.tap(find.text('badgePreview'));
    expect(controller.toggled, ['badgePreview']);
  });

  testWidgets('filters the project previews', (tester) async {
    await _pump(tester, project);
    await tester.enterText(find.byType(TextField), 'badge');
    await tester.pump();
    expect(find.text('lightPreview'), findsNothing);
    expect(find.text('badgePreview'), findsOneWidget);
  });

  testWidgets('offers to generate previews for a file without', (tester) async {
    await _pump(
      tester,
      PreviewState(
        filePath: '$_project/lib/plain.dart',
        status: PreviewStatus.noPreviews,
        scan: _scan('''
class Plain extends StatelessWidget {
  const Plain({super.key});
}
'''),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('Generate Previews'), findsOneWidget);
  });
}
