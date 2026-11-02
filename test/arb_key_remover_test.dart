import 'dart:convert';
import 'dart:io';

import 'package:fide/services/arb_key_remover.dart';
import 'package:fide/services/localization_service.dart';
import 'package:fide/services/project_config_reader.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'localization_service_test.dart' show FakeFlutterRunner;

void main() {
  late Directory project;

  setUp(() => project = Directory.systemTemp.createTempSync('fide_unused_'));
  tearDown(() => project.deleteSync(recursive: true));

  /// Writes [arb] as `lib/l10n/[name]`, returning its path.
  String writeArb(String name, Map<String, Object> arb) {
    final file = File(p.join(project.path, 'lib', 'l10n', name))
      ..createSync(recursive: true)
      ..writeAsStringSync(jsonEncode(arb));
    return file.path;
  }

  test('removes the keys and their metadata from every ARB file', () async {
    final english = writeArb('app_en.arb', {
      '@@locale': 'en',
      'hello': 'Hello',
      'noNote': 'No note',
      '@noNote': {'description': 'Empty notes'},
    });
    final french = writeArb('app_fr.arb', {
      '@@locale': 'fr',
      'hello': 'Bonjour',
      'noNote': 'Aucune note',
    });
    final runner = FakeFlutterRunner();

    final result = await ArbKeyRemover(
      LocalizationService(runner, const ProjectConfigReader()),
    ).apply(project.path, ['noNote', 'helloWorld']);

    expect(result.rewritten, 1);
    expect(result.changedFiles, unorderedEquals([english, french]));
    expect(jsonDecode(File(english).readAsStringSync()), {
      '@@locale': 'en',
      'hello': 'Hello',
    });
    expect(jsonDecode(File(french).readAsStringSync()), {
      '@@locale': 'fr',
      'hello': 'Bonjour',
    });
    expect(runner.commands, ['flutter gen-l10n']);
  });
}
