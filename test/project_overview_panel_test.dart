import 'dart:io';

import 'package:fcheck/fcheck.dart';
import 'package:fide/models/cocoa_pods_migration.dart';
import 'package:fide/models/flutter_platform.dart';
import 'package:fide/models/project_overview.dart';
import 'package:fide/panels/center/project_overview_panel.dart';
import 'package:fide/providers/app_icon_review_provider.dart';
import 'package:fide/providers/project_overview_providers.dart';
import 'package:fide/widgets/action_card.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// fCheck's metrics of a one-file project.
late ProjectMetrics _code;

/// Shows the overview of a project on [platforms] whose Apple apps are as
/// [cocoaPods] says.
Future<void> _pump(
  WidgetTester tester, {
  required Set<FlutterPlatform> platforms,
  CocoaPodsMigration cocoaPods = CocoaPodsMigration.none,
}) async {
  SharedPreferences.setMockInitialValues({});
  final overview = ProjectOverview(
    code: _code,
    languages: const [],
    platforms: platforms,
    cocoaPods: cocoaPods,
    translations: const [],
    coverage: null,
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        projectOverviewProvider.overrideWith((_) async => overview),
        colorContrastProvider.overrideWith((_) async => null),
        appIconReviewProvider.overrideWith((_) async => null),
      ],
      child: const MaterialApp(home: Scaffold(body: ProjectOverviewPanel())),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() {
    final project = Directory.systemTemp.createTempSync('overview');
    File('${project.path}/pubspec.yaml').writeAsStringSync('name: demo\n');
    File('${project.path}/lib/main.dart')
      ..createSync(recursive: true)
      ..writeAsStringSync('void main() {}\n');
    _code = AnalyzeFolder(project).analyze();
    project.deleteSync(recursive: true);
  });

  testWidgets('tells CocoaPods in the platforms card, with an Apple app', (
    tester,
  ) async {
    await _pump(
      tester,
      platforms: {FlutterPlatform.android, FlutterPlatform.ios},
    );
    expect(tester.takeException(), isNull);
    expect(find.text('Swift packages'), findsNothing);
    final card = find.ancestor(
      of: find.text('Supported platforms'),
      matching: find.byType(ActionCard),
    );
    expect(
      find.descendant(of: card, matching: find.text('No CocoaPods')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: card,
        matching: find.text('Every plugin uses Swift Package Manager'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('tells which Apple apps still have a Podfile', (tester) async {
    await _pump(
      tester,
      platforms: {FlutterPlatform.ios, FlutterPlatform.macos},
      cocoaPods: const CocoaPodsMigration(
        projectPath: '/work/app',
        podPlatforms: {FlutterPlatform.ios},
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('CocoaPods can go'), findsOneWidget);
    expect(find.text('Podfile in iOS'), findsOneWidget);
  });

  testWidgets('leaves CocoaPods out without an Apple app', (tester) async {
    await _pump(
      tester,
      platforms: {FlutterPlatform.android, FlutterPlatform.web},
    );
    expect(tester.takeException(), isNull);
    expect(find.textContaining('CocoaPods'), findsNothing);
    expect(find.textContaining('Swift Package Manager'), findsNothing);
  });
}
