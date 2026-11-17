import 'package:fide/constants/constants.dart';
import 'package:fide/models/project_quality.dart';
import 'package:fide/models/quality_issue.dart';
import 'package:fide/providers/app_providers.dart';
import 'package:fide/providers/center_view.dart';
import 'package:fide/providers/right_panel_tab.dart';
import 'package:fide/providers/side_panel.dart';
import 'package:fide/providers/ui_state_providers.dart';
import 'package:fide/widget_services/app_title_bar.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

/// The title bar's light bulb.
const Key _bulb = Key('keyQualityBulb');

/// A container with a project open whose quality is [quality].
ProviderContainer _container(ProjectQuality quality) => ProviderContainer(
  overrides: [
    projectLoadedProvider.overrideWith((_) => true),
    currentProjectPathProvider.overrideWith((_) => '/demo'),
    projectQualityProvider.overrideWithValue(quality),
  ],
);

/// Pumps the title bar under [container].
Future<void> _pumpTitleBar(
  WidgetTester tester,
  ProviderContainer container,
) async {
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        home: Scaffold(body: AppTitleBar(menus: [])),
      ),
    ),
  );
}

void main() {
  testWidgets('the bulb opens the overview and the Info tab', (tester) async {
    final container = _container(
      const ProjectQuality(
        score: AppMetric.warningScoreThreshold,
        issues: [QualityIssue(label: 'Dart analyzer: 1 error')],
      ),
    );
    await _pumpTitleBar(tester, container);

    final bulb = find.byKey(_bulb);
    expect(bulb, findsOneWidget);
    expect(
      tester
          .widget<Tooltip>(
            find.descendant(of: bulb, matching: find.byType(Tooltip)).first,
          )
          .message,
      'Quality ${AppMetric.warningScoreThreshold}%\nDart analyzer: 1 error',
    );

    await tester.tap(bulb);
    // The title bar's double click to zoom holds a tap until it times out
    await tester.pump(kDoubleTapTimeout);

    expect(container.read(centerViewProvider), CenterView.overview);
    expect(container.read(activeRightPanelTabProvider), RightPanelTab.info);
    expect(container.read(SidePanel.right.visibleProvider), true);
  });

  testWidgets('no bulb while the quality needs no attention', (tester) async {
    await _pumpTitleBar(
      tester,
      _container(const ProjectQuality(score: AppMetric.maxScore, issues: [])),
    );

    expect(find.byKey(_bulb), findsNothing);
  });
}
