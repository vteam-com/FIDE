import 'package:fide/models/l10n_config.dart';
import 'package:fide/services/main_dart_localizer.dart';
import 'package:flutter_test/flutter_test.dart';

/// A starter `main.dart` before localization.
const String _main = '''
import 'package:flutter/material.dart';

void main() => runApp(const App());

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

/// Where the generated localizations are imported from.
const String _importUri = 'package:demo/l10n/app_localizations.dart';

/// The generated localizations class, `flutter gen-l10n`'s default.
final String _class = const L10nConfig().outputClass;

void main() {
  test('reads the MaterialApp title', () {
    expect(MainDartLocalizer.appTitle(_main), 'Demo');
    expect(MainDartLocalizer.appTitle('void main() {}'), isNull);
  });

  test('wires the localizations once, keeping the title as fallback', () {
    final localized = MainDartLocalizer.localize(
      _main,
      importUri: _importUri,
      outputClass: _class,
    );

    expect(localized, contains("import '$_importUri';"));
    expect(
      localized,
      contains("AppLocalizations.of(context)?.appTitle ?? 'Demo'"),
    );
    expect(localized, isNot(contains("title: 'Demo'")));
    expect(
      MainDartLocalizer.isLocalized(localized, outputClass: _class),
      isTrue,
    );
    expect(MainDartLocalizer.isLocalized(_main, outputClass: _class), isFalse);
    expect(
      MainDartLocalizer.localize(
        localized,
        importUri: _importUri,
        outputClass: _class,
      ),
      localized,
    );
  });

  test('wires the output class l10n.yaml names', () {
    final localized = MainDartLocalizer.localize(
      _main,
      importUri: _importUri,
      outputClass: 'L10n',
    );

    expect(localized, contains('L10n.of(context)?.appTitle'));
    expect(localized, contains('L10n.localizationsDelegates'));
    expect(localized, isNot(contains('AppLocalizations')));
    expect(
      MainDartLocalizer.isLocalized(localized, outputClass: 'L10n'),
      isTrue,
    );
  });
}
