import 'dart:convert';
import 'dart:io';

import 'package:fide/models/quick_fix.dart';
import 'package:fide/services/code_review.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory project;

  setUp(() {
    project = Directory.systemTemp.createTempSync('fide_untranslated_');
    File(p.join(project.path, 'pubspec.yaml')).writeAsStringSync(
      'name: demo\ndependencies:\n  flutter:\n    sdk: flutter\n'
      'flutter:\n  generate: true\n',
    );
    void arb(String locale, Map<String, Object> content) =>
        File(p.join(project.path, 'lib', 'l10n', 'app_$locale.arb'))
          ..createSync(recursive: true)
          ..writeAsStringSync(jsonEncode(content));
    arb('en', {
      '@@locale': 'en',
      'appTitle': 'Fala',
      '@appTitle': {'description': 'App name. DO NOT TRANSLATE.'},
      'hello': 'Hello',
      'stop': 'Stop',
    });
    // Missing appTitle and stop, hello still in English
    arb('es', {'@@locale': 'es', 'hello': 'Hello'});
  });

  tearDown(() => project.deleteSync(recursive: true));

  test('fCheck leaves out the keys marked not to translate', () async {
    final metrics = await const CodeReview().analyze(project.path);

    expect(QuickFix.translateKeys.localesByKey(metrics), {
      'hello': {'es'},
      'stop': {'es'},
    });
  });
}
