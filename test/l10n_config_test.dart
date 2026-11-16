import 'package:fide/models/l10n_config.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  const root = '/src/app';

  test('localeOf reads the whole locale of an ARB or Dart file name', () {
    expect(L10nConfig.localeOf('app_en.arb'), 'en');
    expect(L10nConfig.localeOf('app_pt_BR.arb'), 'pt_BR');
    expect(L10nConfig.localeOf('intl_zh_Hant_TW.arb'), 'zh_Hant_TW');
    expect(L10nConfig.localeOf('app_es_419.arb'), 'es_419');
    expect(L10nConfig.localeOf('app_localizations_fr.dart'), 'fr');
    expect(L10nConfig.localeOf('strings.arb'), isNull);
    expect(L10nConfig.localeParts('app_localizations_fr.dart'), (
      prefix: 'app_localizations_',
      locale: 'fr',
    ));
  });

  test('locates the ARB files in the folder l10n.yaml names', () {
    const config = L10nConfig(
      arbDir: 'lib/i18n',
      templateArbFile: 'intl_pt_BR.arb',
    );

    expect(config.arbDirIn(root), p.join(root, 'lib', 'i18n'));
    expect(
      config.templatePathIn(root),
      p.join(root, 'lib', 'i18n', 'intl_pt_BR.arb'),
    );
    expect(config.arbFileName('fr'), 'intl_fr.arb');
    expect(
      config.arbPathFor(root, 'fr'),
      p.join(root, 'lib', 'i18n', 'intl_fr.arb'),
    );
  });

  test('locates the generated class in the output folder', () {
    expect(
      const L10nConfig().generatedPathIn(root),
      p.join(root, 'lib', 'l10n', 'app_localizations.dart'),
    );
    expect(
      const L10nConfig(outputDir: 'lib/gen').generatedPathIn(root),
      p.join(root, 'lib', 'gen', 'app_localizations.dart'),
    );
  });

  test('isOutputImport matches the generated file by name', () {
    const config = L10nConfig();

    expect(
      config.isOutputImport('package:app/l10n/app_localizations.dart'),
      true,
    );
    expect(config.isOutputImport('package:app/main.dart'), false);
  });
}
