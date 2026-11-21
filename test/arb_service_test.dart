import 'dart:io';

import 'package:fide/models/localization_data.dart';
import 'package:fide/services/arb_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  const service = ArbService();
  late Directory project;

  setUp(() {
    project = Directory.systemTemp.createTempSync('fide_arb_');
  });

  tearDown(() => project.deleteSync(recursive: true));

  void write(String path, Map<String, dynamic> arb) =>
      File(p.join(project.path, path))
        ..createSync(recursive: true)
        ..writeAsStringSync(ArbService.encode(arb));

  ArbFile arbFile(String languageCode, Map<String, String> messages) => ArbFile(
    path: 'app_$languageCode.arb',
    languageCode: languageCode,
    entries: {
      for (final MapEntry(:key, :value) in messages.entries)
        key: ArbEntry(key: key, value: value),
    },
  );

  test('parseArbFile reads the whole locale of app_pt_BR.arb', () async {
    write('app_pt_BR.arb', {ArbService.localeKey: 'pt_BR', 'hi': 'Oi'});

    final file = await service.parseArbFile(
      p.join(project.path, 'app_pt_BR.arb'),
    );

    expect(file?.languageCode, 'pt_BR');
    expect(file?.entries.keys, ['hi']);
  });

  test('parseArbFile marks a name without a locale unknown', () async {
    write('strings.arb', {'hi': 'Hi'});

    final file = await service.parseArbFile(
      p.join(project.path, 'strings.arb'),
    );

    expect(file?.languageCode, ArbFile.unknownLanguageCode);
  });

  test('compareArbFiles compares against the template locale', () {
    final comparisons = service.compareArbFiles([
      arbFile('en', {'hi': 'Hi', 'bye': 'Bye'}),
      arbFile('fr', {'hi': 'Salut', 'extra': 'En plus'}),
    ], 'fr');

    final byKey = {for (final c in comparisons) c.key: c};
    expect(byKey['hi']?.englishValue, 'Salut');
    expect(byKey['hi']?.otherValues, {'en': 'Hi'});
    expect(byKey['bye']?.englishValue, isNull);
    expect(byKey['extra']?.otherValues, {'en': null});
  });

  test('loadProject reads the ARB folder l10n.yaml names', () async {
    File(
      p.join(project.path, 'l10n.yaml'),
    ).writeAsStringSync('arb-dir: lib/i18n\ntemplate-arb-file: app_fr.arb\n');
    write('lib/i18n/app_fr.arb', {'hi': 'Salut'});
    write('lib/i18n/app_en.arb', {'hi': 'Hi', 'bye': 'Bye'});
    write('lib/l10n/app_de.arb', {'hi': 'Hallo'});

    final loaded = await service.loadProject(project.path);

    expect(loaded.valid.map((file) => file.languageCode).toSet(), {'fr', 'en'});
    expect(loaded.templateLocale, 'fr');
    final bye = loaded.comparisons.singleWhere((c) => c.key == 'bye');
    expect(bye.englishValue, isNull);
  });

  test('isMessageKey and countEntries leave metadata out', () {
    expect(
      ArbService.countEntries(
        ArbService.encode({
          ArbService.localeKey: 'en',
          'hi': 'Hi',
          '@hi': {'description': 'Greeting'},
        }),
      ),
      1,
    );
  });
}
