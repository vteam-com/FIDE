import 'dart:async';

import 'package:fide/models/dependency_version.dart';
import 'package:fide/models/project_metrics.dart';
import 'package:fide/models/quick_fix.dart';
import 'package:fide/panels/left/packages_section.dart';
import 'package:fide/providers/app_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Metrics showing [metrics], with no project to cache them for.
class _Metrics extends ProjectMetricsNotifier {
  _Metrics(ProjectMetrics metrics)
    : super(Completer<SharedPreferences>().future, null) {
    state = metrics;
  }
}

void main() {
  testWidgets('lists the dependencies with the pub actions and pubspec', (
    tester,
  ) async {
    final metrics = ProjectMetrics(
      dependencies: {'http': DependencyVersion.fromPubspec('^1.2.0')},
      devDependencies: {'lints': DependencyVersion.fromPubspec('^6.0.0')},
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          projectMetricsProvider.overrideWith((_) => _Metrics(metrics)),
        ],
        child: const MaterialApp(
          home: Scaffold(body: SingleChildScrollView(child: PackagesSection())),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Dependencies'), findsOneWidget);
    expect(find.text('Direct'), findsOneWidget);
    expect(find.text('Developer'), findsOneWidget);
    expect(find.text('Outdated'), findsOneWidget);
    expect(find.text(QuickFix.upgradePackages.label), findsOneWidget);
    // The header's actions are built full and compact, for a narrow panel
    expect(find.byTooltip('Open pubspec.yaml'), findsWidgets);
  });
}
