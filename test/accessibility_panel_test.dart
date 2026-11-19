import 'package:fide/models/color_contrast_report.dart';
import 'package:fide/models/color_roles.dart';
import 'package:fide/models/wcag_color.dart';
import 'package:fide/panels/center/accessibility_panel.dart';
import 'package:fide/providers/app_providers.dart';
import 'package:fide/theme/app_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

/// The open project.
const String _project = '/p';

/// A check of [foreground] text on white at [line] of `lib/a.dart`,
/// failing for low contrast when [fails].
ColorContrastCheck _text(int line, int foreground, {bool fails = false}) =>
    ColorContrastCheck(
      element: ColorContrastElement.text,
      failure: fails ? ColorContrastKind.lowContrast : null,
      path: '$_project/lib/a.dart',
      line: line,
      foreground: 'Colors.grey',
      foregroundColor: WcagColor(foreground),
      background: 'Colors.white',
      backgroundColor: const WcagColor(0xFFFFFFFF),
    );

/// A project with one text that reads and one that doesn't, both themes,
/// and two colors.
final ColorContrastReport _report = ColorContrastReport(
  fileCount: 1,
  unjudged: 3,
  checks: [_text(1, 0xFF000000), _text(2, 0xFF9E9E9E, fails: true)],
  colors: const [
    ColorUsage(
      colors: [WcagColor(0xFF9E9E9E)],
      names: {'Colors.grey': 2, 'Color(0xFF9E9E9E)': 1},
    ),
    ColorUsage(
      colors: [WcagColor(0xFF6750A4), WcagColor(0xFFD0BCFF)],
      names: {'colorScheme.primary': 1},
    ),
  ],
  schemes: [
    ColorSchemeSummary(
      theme: 'light',
      roles: ColorRoles.material3(isDark: false),
      origin: 'Generated from the seed Colors.teal',
      path: '$_project/lib/main.dart',
      line: 7,
    ),
    ColorSchemeSummary(
      theme: 'dark',
      roles: ColorRoles.material3(isDark: true),
      origin: "Material 3's default",
    ),
  ],
);

void main() {
  testWidgets('shows the score, the themes and the colors, most used first', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 2400);
    addTearDown(tester.view.reset);
    final container = ProviderContainer(
      overrides: [colorContrastProvider.overrideWith((_) async => _report)],
    );
    addTearDown(container.dispose);
    container.read(currentProjectPathProvider.notifier).state = _project;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(body: AccessibilityPanel()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('50% of 2 elements read at WCAG AA'), findsOneWidget);
    expect(find.text('1 of 2 read'), findsOneWidget);
    expect(find.text('3 elements'), findsOneWidget);
    expect(find.text('Light theme'), findsOneWidget);
    expect(find.text('Dark theme'), findsOneWidget);
    expect(find.text('Generated from the seed Colors.teal'), findsOneWidget);
    final grey = tester.getTopLeft(
      find.text('Colors.grey ×2, Color(0xFF9E9E9E) ×1'),
    );
    final primary = tester.getTopLeft(find.text('colorScheme.primary ×1'));
    expect(grey.dy, lessThan(primary.dy));
  });
}
