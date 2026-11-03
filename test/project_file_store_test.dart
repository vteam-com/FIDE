import 'dart:io';

import 'package:fide/services/project_file_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory project;
  late ProjectFileStore store;

  setUp(() {
    project = Directory.systemTemp.createTempSync('fide_store_');
    File(p.join(project.path, 'lib', 'main.dart'))
      ..createSync(recursive: true)
      ..writeAsStringSync('void main() {}');
    File(p.join(project.path, 'build', 'out.txt'))
      ..createSync(recursive: true)
      ..writeAsStringSync('');
    store = ProjectFileStore(project.path);
  });
  tearDown(() => project.deleteSync(recursive: true));

  test('lists project files without build output, up to a limit', () async {
    await store.write('lib/b.dart', '');

    expect(await store.list('.', limit: 10), [
      p.join('lib', 'b.dart'),
      p.join('lib', 'main.dart'),
    ]);
    expect(await store.list('lib', limit: 1), hasLength(1));
  });

  test('reads and writes files inside the project, creating folders', () async {
    expect(await store.read('lib/main.dart'), 'void main() {}');

    await store.write('lib/src/a.dart', 'class A {}');

    expect(
      File(p.join(project.path, 'lib', 'src', 'a.dart')).readAsStringSync(),
      'class A {}',
    );
    expect(
      store.resolve('lib/main.dart'),
      p.join(project.path, 'lib', 'main.dart'),
    );
    expect(store.resolve('.'), p.normalize(project.path));
  });

  test('refuses paths outside the project', () {
    expect(() => store.resolve('../escape.dart'), throwsFormatException);
    expect(store.read('../escape.dart'), throwsFormatException);
    expect(store.write('../escape.dart', ''), throwsFormatException);
    expect(store.list('..', limit: 1), throwsFormatException);
  });
}
