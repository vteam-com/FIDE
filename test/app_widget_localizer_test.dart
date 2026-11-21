import 'package:fide/models/l10n_config.dart';
import 'package:fide/services/app_widget_localizer.dart';
import 'package:flutter_test/flutter_test.dart';

/// A starter app widget before localization.
const String _app = '''
import 'package:flutter/material.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Demo',
      home: const Placeholder(),
    );
  }
}
''';

/// A `main.dart` running an app built in another file.
const String _mainRunningApp = '''
import 'package:demo/app.dart';
import 'package:flutter/material.dart';

void main() => runApp(const App());
''';

/// Where the generated localizations are imported from.
const String _importUri = 'package:demo/l10n/app_localizations.dart';

/// [content] localized with [config], the ARB files having the title key
/// when [hasTitleKey].
String _localize(
  String content, {
  L10nConfig config = const L10nConfig(),
  bool hasTitleKey = true,
}) => AppWidgetLocalizer.localize(
  content,
  config: config,
  importUri: _importUri,
  hasTitleKey: hasTitleKey,
);

void main() {
  test('reads the app widget title', () {
    expect(AppWidgetLocalizer.appTitle(_app), 'Demo');
    expect(AppWidgetLocalizer.appTitle('void main() {}'), isNull);
  });

  test('wires the localizations once, looking the title up', () {
    final localized = _localize(_app);

    expect(localized, contains("import '$_importUri';"));
    expect(localized, contains('AppLocalizations.of(context)!.appTitle'));
    expect(localized, isNot(contains("title: 'Demo'")));
    // Added before the first argument, at its indent
    expect(
      localized,
      contains(
        'MaterialApp(\n'
        '      localizationsDelegates: AppLocalizations.localizationsDelegates,\n'
        '      supportedLocales: AppLocalizations.supportedLocales,\n'
        '      onGenerateTitle:',
      ),
    );
    expect(AppWidgetLocalizer.isLocalized(localized), isTrue);
    expect(AppWidgetLocalizer.isLocalized(_app), isFalse);
    expect(_localize(localized), localized);
  });

  test('wires the output class l10n.yaml names', () {
    final localized = _localize(
      _app,
      config: const L10nConfig(outputClass: 'L10n', nullableGetter: false),
    );

    expect(localized, contains('L10n.of(context).appTitle'));
    expect(localized, contains('L10n.localizationsDelegates'));
    expect(localized, isNot(contains('AppLocalizations')));
    expect(AppWidgetLocalizer.isLocalized(localized), isTrue);
  });

  test('leaves a file building no app widget alone', () {
    expect(AppWidgetLocalizer.buildsApp(_mainRunningApp), isFalse);
    // No import left unused
    expect(_localize(_mainRunningApp), _mainRunningApp);
  });

  test('keeps the fixed title when the ARB files have no title key', () {
    final localized = _localize(_app, hasTitleKey: false);

    expect(localized, contains("title: 'Demo'"));
    expect(localized, isNot(contains('onGenerateTitle')));
    expect(AppWidgetLocalizer.isLocalized(localized), isTrue);
  });

  test('wires router, Cupertino and constant apps', () {
    for (final app in [
      'MaterialApp.router(routerConfig: router)',
      'CupertinoApp(home: Home())',
      'const WidgetsApp(color: Color(0))',
    ]) {
      final content = 'Widget build() => $app;';
      final localized = _localize(content);

      expect(AppWidgetLocalizer.buildsApp(content), isTrue, reason: app);
      expect(AppWidgetLocalizer.isLocalized(localized), isTrue, reason: app);
    }
    expect(
      _localize('Widget build() => MaterialApp();'),
      contains(
        'MaterialApp(localizationsDelegates: AppLocalizations.localizationsDelegates, '
        'supportedLocales: AppLocalizations.supportedLocales)',
      ),
    );
    // A constant can't take the title lookup's closure
    expect(
      _localize("Widget build() => const MaterialApp(title: 'Demo');"),
      contains("title: 'Demo'"),
    );
  });

  test('counts delegates computed elsewhere, keeping the import', () {
    const wired = '''
import 'package:demo/l10n/l10n.dart';

Widget build() => MaterialApp(
  localizationsDelegates: appDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
);
''';
    expect(AppWidgetLocalizer.isLocalized(wired), isTrue);
    expect(_localize(wired, hasTitleKey: false), wired);
  });

  test('adds only the missing argument, importing the class once', () {
    const imported = '''
import 'package:demo/l10n/app_localizations.dart';

Widget build() => MaterialApp(
  supportedLocales: AppLocalizations.supportedLocales,
);
''';
    final localized = _localize(imported, hasTitleKey: false);

    expect('supportedLocales:'.allMatches(localized), hasLength(1));
    expect('import '.allMatches(localized), hasLength(1));
    expect(AppWidgetLocalizer.isLocalized(localized), isTrue);
  });
}
