import 'dart:io';

import 'package:fide/services/spelling_fixer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory project;

  setUp(() {
    project = Directory.systemTemp.createTempSync('fide_fixer_');
    File(p.join(project.path, 'lib', 'a.dart'))
      ..createSync(recursive: true)
      ..writeAsStringSync(
        "// avaiable here, Avaiable too, avaiables stays\n"
        "bool isAvaiable = true;\n"
        "const x = 'AVAIABLE';\n",
      );
  });
  tearDown(() => project.deleteSync(recursive: true));

  test('replaces whole words and camelCase parts, keeping their casing', () {
    final changed = const SpellingFixer().plan(
      project.path,
      'avaiable',
      'available',
    );

    expect(changed, hasLength(1));
    expect(
      changed.values.single,
      "// available here, Available too, avaiables stays\n"
      "bool isAvailable = true;\n"
      "const x = 'AVAILABLE';\n",
    );
  });

  test('a file without the word is left out', () {
    final changed = const SpellingFixer().plan(project.path, 'zzzz', 'x');

    expect(changed, isEmpty);
  });
}
