import 'dart:io';

import 'package:fide/models/project_files.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory project;

  setUp(() {
    project = Directory.systemTemp.createTempSync('fide_files_');
    for (final path in [
      'lib/main.dart',
      'lib/src/a.dart',
      'README.md',
      'build/out.dart',
      '.dart_tool/x.dart',
      '.git/HEAD',
      'ios/Pods/p.dart',
    ]) {
      File(p.join(project.path, path)).createSync(recursive: true);
    }
  });

  tearDown(() => project.deleteSync(recursive: true));

  List<String> relative(Iterable<FileSystemEntity> entities) => [
    for (final entity in entities) p.relative(entity.path, from: project.path),
  ]..sort();

  test(
    'walk lists the files, leaving tool output and hidden ones out',
    () async {
      expect(relative(await ProjectFiles.walk(project.path).toList()), [
        'README.md',
        p.join('lib', 'main.dart'),
        p.join('lib', 'src', 'a.dart'),
      ]);
    },
  );

  test('walk keeps only the files with the given extension', () async {
    expect(
      relative(
        await ProjectFiles.walk(project.path, extension: '.dart').toList(),
      ),
      [p.join('lib', 'main.dart'), p.join('lib', 'src', 'a.dart')],
    );
  });

  test('entities lists the folders too', () async {
    expect(
      relative(await ProjectFiles.entities(project.path).toList()),
      containsAll(['ios', 'lib', p.join('lib', 'src')]),
    );
  });

  test('walk throws for a folder that does not exist', () {
    expect(
      ProjectFiles.walk(p.join(project.path, 'missing')).toList(),
      throwsA(isA<FileSystemException>()),
    );
  });
}
