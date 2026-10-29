import 'dart:io';

import 'package:fide/providers/flutter_sdk.dart';
import 'package:fide/providers/reference_finder.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

// Reports the Dart SDK the tests run on, without launching flutter
class _TestSdk extends FlutterSdk {
  const _TestSdk();

  @override
  Future<String?> dartSdkPath() async =>
      p.join(Platform.environment['FLUTTER_ROOT']!, 'bin', 'cache', 'dart-sdk');
}

void main() {
  late String project;
  late ReferenceFinder finder;

  setUp(() {
    project = Directory.systemTemp
        .createTempSync('fide_refs_')
        .resolveSymbolicLinksSync();
    finder = ReferenceFinder(
      projectPath: project,
      flutterSdk: const _TestSdk(),
    );
  });
  tearDown(() {
    finder.dispose();
    Directory(project).deleteSync(recursive: true);
  });

  String write(String relativePath, String content) {
    final path = p.join(project, relativePath);
    File(path)
      ..createSync(recursive: true)
      ..writeAsStringSync(content);
    return path;
  }

  test('finds uses of a class across files, not its own', () async {
    final gallery = write('lib/gallery.dart', '''
class Gallery {
  Gallery copy() => Gallery();
}
''');
    write('lib/home.dart', '''
import 'gallery.dart';

class Home {
  final Gallery gallery = Gallery();
}
''');

    final uses = await finder.find(filePath: gallery, line: 1, column: 1);

    expect(uses.map((u) => p.basename(u.filePath)), ['home.dart', 'home.dart']);
    expect(uses.first.lineNumber, 4);
    expect(
      uses.first.lineContent.substring(
        uses.first.matchStart,
        uses.first.matchEnd,
      ),
      'Gallery',
    );
  });

  test('finds calls of that method only, not same-named ones', () async {
    final shapes = write('lib/shapes.dart', '''
class Circle {
  void draw() {}
}

class Square {
  void draw() {}
}

void paint(Circle c, Square s) {
  c.draw();
  s.draw();
  c.draw();
}
''');

    final uses = await finder.find(filePath: shapes, line: 2, column: 3);

    expect(uses.map((u) => u.lineNumber), [10, 12]);
  });

  test('fails rather than count zero when no declaration is there', () {
    final a = write('lib/a.dart', 'class A {}\n');

    expect(finder.find(filePath: a, line: 1, column: 4), throwsException);
  });

  test('sees files changed since the last lookup', () async {
    final a = write('lib/a.dart', 'class A {}\n');
    expect(await finder.find(filePath: a, line: 1, column: 1), isEmpty);

    write('lib/b.dart', "import 'a.dart';\n\nfinal a = A();\n");

    expect(await finder.find(filePath: a, line: 1, column: 1), hasLength(1));
  });

  test('renames a class, its constructors and uses across files', () async {
    final gallery = write('lib/gallery.dart', '''
class Gallery {
  const Gallery();
  const Gallery.empty();
  Gallery copy() => Gallery();
}
''');
    final home = write('lib/home.dart', '''
import 'gallery.dart';

final gallery = Gallery.empty();
''');

    final files = await finder.rename(
      filePath: gallery,
      line: 1,
      column: 1,
      newName: 'Album',
    );

    expect(files[gallery], '''
class Album {
  const Album();
  const Album.empty();
  Album copy() => Album();
}
''');
    expect(files[home], contains('final gallery = Album.empty();'));
  });

  test(
    'renames a field with its this. parameters and named arguments',
    () async {
      final card = write('lib/card.dart', '''
class Card {
  const Card({required this.title});
  final String title;
  String get label => title;
}

final card = Card(title: 'x');
''');

      final files = await finder.rename(
        filePath: card,
        line: 3,
        column: 16,
        newName: 'heading',
      );

      expect(files[card], '''
class Card {
  const Card({required this.heading});
  final String heading;
  String get label => heading;
}

final card = Card(heading: 'x');
''');
    },
  );

  test('refuses a rename that would break the build', () async {
    final a = write('lib/a.dart', 'class A {}\n\nclass B {}\n');

    expect(
      finder.rename(filePath: a, line: 1, column: 1, newName: 'B'),
      throwsException,
    );
    expect(
      finder.rename(filePath: a, line: 1, column: 1, newName: '1A'),
      throwsException,
    );
  });
}
