import 'package:fide/models/l10n_config.dart';
import 'package:fide/services/preview_registry.dart';
import 'package:fide/services/preview_scanner.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const registry = PreviewRegistry(
    projectPath: '/work/app',
    packageName: 'app',
  );

  const source = '''
import 'package:flutter/widget_previews.dart';
import '../models/user.dart' as models;

@Preview(name: 'Card')
Widget cardPreview() => const SizedBox();
''';

  test('imports the file and its imports as the host sees them', () {
    final scan = const PreviewScanner().scan(source);
    final registrySource = registry.source(
      '/work/app/lib/widgets/card.dart',
      scan,
    );
    expect(registrySource, contains("import 'package:app/widgets/card.dart';"));
    expect(
      registrySource,
      contains("import 'package:flutter/widget_previews.dart';"),
    );
    expect(
      registrySource,
      contains("import 'package:app/models/user.dart' as models;"),
    );
    expect(
      registrySource,
      contains(
        "(function: 'cardPreview', line: 4, "
        "annotation: () => const Preview(name: 'Card'), "
        'build: () => cardPreview()),',
      ),
    );
  });

  test("gives the project's generated localizations to the host", () {
    final scan = const PreviewScanner().scan(source);
    const path = '/work/app/lib/widgets/card.dart';
    expect(
      registry.source(path, scan),
      contains('PreviewLocalizationsData? fideLocalizations() => null;'),
    );
    const localized = PreviewRegistry(
      projectPath: '/work/app',
      packageName: 'app',
      l10n: L10nConfig(outputClass: 'Strings'),
    );
    final localizedSource = localized.source(path, scan);
    expect(
      localizedSource,
      contains(
        "import 'package:app/l10n/app_localizations.dart' as fide_l10n;",
      ),
    );
    expect(
      localizedSource,
      contains(
        'localizationsDelegates: fide_l10n.Strings.localizationsDelegates,',
      ),
    );
  });

  test('imports a file outside lib by its path from the host', () {
    final scan = const PreviewScanner().scan(source);
    expect(
      registry.source('/work/app/test/card_test.dart', scan),
      contains("import '../../test/card_test.dart';"),
    );
  });
}
