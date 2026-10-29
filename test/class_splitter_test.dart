import 'dart:io';

import 'package:fide/providers/class_splitter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late String project;

  final splitter = ClassSplitter(
    dartSdkPath: p.join(
      Platform.environment['FLUTTER_ROOT']!,
      'bin',
      'cache',
      'dart-sdk',
    ),
  );

  setUp(() {
    project = Directory.systemTemp
        .createTempSync('fide_split_')
        .resolveSymbolicLinksSync();
  });
  tearDown(() => Directory(project).deleteSync(recursive: true));

  String path(String relativePath) => p.join(project, relativePath);

  void write(String relativePath, String content) {
    File(path(relativePath))
      ..createSync(recursive: true)
      ..writeAsStringSync(content);
  }

  Future<Map<String, String>> split(String relativePath) async {
    final result = await splitter.plan(
      projectPath: project,
      filePath: path(relativePath),
    );
    return {
      for (final entry in result.files.entries)
        p.relative(entry.key, from: project): entry.value,
    };
  }

  test('moves a class to its own file with only the imports it uses', () async {
    write('lib/shapes.dart', '''
import 'dart:collection';
import 'dart:math';

class Shapes {
  double area(double r) => pi * r * r;
}

/// Names in arrival order.
class Names {
  final Queue<String> items = Queue();
}
''');

    final files = await split('lib/shapes.dart');

    expect(files.keys, unorderedEquals(['lib/shapes.dart', 'lib/names.dart']));
    expect(files['lib/names.dart'], contains("import 'dart:collection';"));
    expect(files['lib/names.dart'], isNot(contains('dart:math')));
    expect(files['lib/names.dart'], contains('/// Names in arrival order.'));
    expect(files['lib/shapes.dart'], isNot(contains('dart:collection')));
    expect(files['lib/shapes.dart'], contains("import 'dart:math';"));
    expect(files['lib/shapes.dart'], isNot(contains('class Names')));
  });

  test(
    'points importers at the moved class and imports back what it uses',
    () async {
      write('lib/a.dart', '''
class A {}

class B {
  A make() => A();
}
''');
      write('lib/main.dart', '''
import 'a.dart';

void main() => B();
''');

      final files = await split('lib/a.dart');

      expect(files['lib/b.dart'], contains("import 'a.dart';"));
      expect(files['lib/main.dart'], contains("import 'b.dart';"));
      expect(files['lib/main.dart'], isNot(contains("import 'a.dart';")));
    },
  );

  test('moves a class with the private helpers only it uses', () async {
    write('lib/stage.dart', '''
class Foo {
  _Bar bar = _Bar();
}

class _Bar {
  int get size => _size;
}

const _size = 3;

class Stage {}
''');

    final files = await split('lib/stage.dart');

    expect(files.keys, unorderedEquals(['lib/stage.dart', 'lib/foo.dart']));
    expect(files['lib/foo.dart'], contains('class _Bar'));
    expect(files['lib/foo.dart'], contains('const _size = 3;'));
    expect(files['lib/foo.dart'], isNot(contains('part of')));
    expect(files['lib/stage.dart'], isNot(contains('_Bar')));
    expect(files['lib/stage.dart'], isNot(contains('_size')));
    expect(files['lib/stage.dart'], contains('class Stage {}'));
  });

  test('moves a class tangled with private code to a part file', () async {
    write('lib/card.dart', '''
class Card {
  int get size => _size;
}

class Badge {
  int get size => _size;
}

const _size = 3;
''');

    final files = await split('lib/card.dart');

    expect(files['lib/card.badge.dart'], startsWith("part of 'card.dart';"));
    expect(files['lib/card.dart'], contains("part 'card.badge.dart';"));
    expect(files['lib/card.dart'], contains('const _size = 3;'));
  });

  test('refuses a file that already has compile errors', () async {
    write('lib/a.dart', 'class A extends Missing {}\n\nclass B {}\n');

    expect(
      split('lib/a.dart'),
      throwsA(
        isA<ClassSplitException>().having(
          (e) => e.message,
          'message',
          contains('a.dart:1:'),
        ),
      ),
    );
  });

  test('refuses to overwrite an existing file', () async {
    write('lib/a.dart', 'class A {}\n\nclass B {}\n');
    write('lib/b.dart', '// taken\n');

    expect(split('lib/a.dart'), throwsA(isA<ClassSplitException>()));
  });
}
