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

void main() {
  test('reads the MaterialApp title', () {
    expect(MainDartLocalizer.appTitle(_main), 'Demo');
    expect(MainDartLocalizer.appTitle('void main() {}'), isNull);
  });

  test('wires the localizations once, keeping the title as fallback', () {
    final localized = MainDartLocalizer.localize(_main, importUri: _importUri);

    expect(localized, contains("import '$_importUri';"));
    expect(
      localized,
      contains("AppLocalizations.of(context)?.appTitle ?? 'Demo'"),
    );
    expect(localized, isNot(contains("title: 'Demo'")));
    expect(MainDartLocalizer.isLocalized(localized), isTrue);
    expect(MainDartLocalizer.isLocalized(_main), isFalse);
    expect(
      MainDartLocalizer.localize(localized, importUri: _importUri),
      localized,
    );
  });
}
