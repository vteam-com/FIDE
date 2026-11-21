import 'package:fide/models/localization_checks.dart';
import 'package:fide/models/localization_data.dart';
import 'package:fide/models/localization_state.dart';
import 'package:fide/models/project_node.dart';
import 'package:fide/panels/right/localization/localization_entry_widget.dart';
import 'package:fide/panels/right/localization/localization_panel.dart';
import 'package:fide/providers/app_providers.dart';
import 'package:fide/providers/localization_controller.dart';
import 'package:fide/services/arb_service.dart';
import 'package:fide/services/l10n_generator.dart';
import 'package:fide/services/localization_setup.dart';
import 'package:fide/services/process_runner.dart';
import 'package:fide/services/project_config_reader.dart';
import 'package:fide/widgets/locale_badges.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

/// How many ARB keys the project has.
const int _keyCount = 500;

/// How far each step scrolls to a heading of the checklist.
const double _scrollStep = 200;

/// A controller showing [shown] without inspecting any project.
class _FixedController extends LocalizationController {
  _FixedController(LocalizationState shown)
    : super(
        null,
        setup: const LocalizationSetup(
          ProcessRunner(),
          ProjectConfigReader(),
          L10nGenerator(ProcessRunner()),
        ),
        generator: const L10nGenerator(ProcessRunner()),
        arb: const ArbService(),
        reloadWritten: (_) async {},
      ) {
    state = shown;
  }
}

/// A state of [checks] with [_keyCount] keys in English and French.
LocalizationState _state(LocalizationChecks checks) => LocalizationState(
  checks: checks,
  templateLocale: 'en',
  arbFiles: [
    for (final locale in ['fr', 'en'])
      ArbFile(
        path: '/p/lib/l10n/app_$locale.arb',
        languageCode: locale,
        entries: {},
      ),
  ],
  comparisons: [
    for (var i = 0; i < _keyCount; i++)
      ArbComparison(
        key: 'key$i',
        englishValue: 'Value $i',
        otherValues: {'fr': 'Valeur $i'},
      ),
  ],
);

void main() {
  /// Shows the Localization panel of [state].
  Future<void> pumpPanel(WidgetTester tester, LocalizationState state) async {
    final container = ProviderContainer(
      overrides: [
        localizationControllerProvider.overrideWith(
          (_) => _FixedController(state),
        ),
      ],
    );
    addTearDown(container.dispose);
    container.read(currentProjectRootProvider.notifier).state = ProjectNode(
      name: 'p',
      path: '/p',
      type: ProjectNodeType.directory,
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: LocalizationPanel())),
      ),
    );
  }

  /// Checks of a fully set up project.
  const complete = LocalizationChecks(
    hasPubspec: true,
    isFlutterProject: true,
    hasArbFiles: true,
    hasGeneratedClasses: true,
    hasAppIntegration: true,
    hasDependencies: true,
    hasGenerateFlag: true,
  );

  testWidgets('lists the locales, each but the template removable', (
    tester,
  ) async {
    await pumpPanel(tester, _state(complete));

    final badges = find.byType(LocaleBadges);
    expect(badges, findsOneWidget);
    expect(
      find.descendant(of: badges, matching: find.text('EN')),
      findsOneWidget,
    );
    expect(find.byTooltip('Remove French'), findsOneWidget);
    expect(find.byTooltip('Remove English'), findsNothing);
    expect(find.text(LocaleBadges.addLabel), findsOneWidget);
  });

  for (final (name, generated) in [('partial', false), ('complete', true)]) {
    testWidgets('the $name view builds only the keys in view', (tester) async {
      await pumpPanel(
        tester,
        _state(
          LocalizationChecks(
            hasPubspec: true,
            isFlutterProject: true,
            hasArbFiles: true,
            hasGeneratedClasses: generated,
            hasAppIntegration: generated,
            hasDependencies: true,
            hasGenerateFlag: true,
          ),
        ),
      );

      final built = find.byType(LocalizationEntryWidget).evaluate().length;
      expect(built, lessThan(_keyCount));
      if (!generated) {
        // Below the locales, past the checklist
        await tester.scrollUntilVisible(
          find.text('ARB File Management'),
          _scrollStep,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text('Generate localization classes'), findsOneWidget);
      }

      await tester.scrollUntilVisible(
        find.text('key${_keyCount - 1}'),
        2000,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('key${_keyCount - 1}'), findsOneWidget);
    });
  }
}
