import 'dart:io';

import 'package:fcheck/fcheck.dart' as fcheck;
import 'package:fide/models/arb_keys.dart';
import 'package:fide/models/hardcoded_string.dart';
import 'package:fide/models/l10n_config.dart';
import 'package:fide/models/lookup_rewrite.dart';
import 'package:fide/models/search_result.dart';
import 'package:fide/services/reference_finder.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// The Dart SDK the tests run on, found without launching flutter.
Future<String> _testSdkPath() async =>
    p.join(Platform.environment['FLUTTER_ROOT']!, 'bin', 'cache', 'dart-sdk');

void main() {
  late String project;
  late ReferenceFinder finder;

  setUp(() {
    project = Directory.systemTemp
        .createTempSync('fide_refs_')
        .resolveSymbolicLinksSync();
    finder = ReferenceFinder(projectPath: project, dartSdkPath: _testSdkPath);
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

  test('fails its lookups when the analysis can\'t start', () async {
    // The analyzer refuses a path with a trailing slash; the lookup must
    // say so rather than wait forever on a worker that died
    final broken = ReferenceFinder(
      projectPath: '$project/',
      dartSdkPath: _testSdkPath,
    );
    addTearDown(broken.dispose);
    final path = write('lib/a.dart', 'class A {}');

    await expectLater(
      broken
          .find(filePath: path, line: 1, column: 1)
          .timeout(const Duration(seconds: 30)),
      throwsA(
        isA<Exception>().having(
          (e) => '$e',
          'message',
          contains("Can't analyze"),
        ),
      ),
    );
  });

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

    // A file already read is read again once changed
    write('lib/b.dart', 'final b = 1;\n');
    expect(await finder.find(filePath: a, line: 1, column: 1), isEmpty);
  });

  test('a newer find replaces the ones still waiting', () async {
    final a = write('lib/a.dart', 'class A {}\n\nclass B {}\n');
    write('lib/b.dart', "import 'a.dart';\n\nfinal a = A();\nfinal b = B();\n");

    final first = finder.find(filePath: a, line: 1, column: 1);
    final waiting = finder.find(filePath: a, line: 3, column: 1);
    final latest = finder.find(filePath: a, line: 3, column: 1);

    expect(await first, hasLength(1));
    await expectLater(
      waiting,
      throwsA(predicate((e) => '$e'.contains(ReferenceFinder.superseded))),
    );
    expect(await latest, hasLength(1));
  });

  group('callees', () {
    /// The names [calls] mark, in order.
    List<String> names(List<SearchResult> calls) => [
      for (final call in calls)
        call.lineContent.substring(call.matchStart, call.matchEnd),
    ];

    test('lists what a method calls, once each, in the order first '
        'called', () async {
      final shapes = write('lib/shapes.dart', '''
class Circle {
  int get area => 3;
  int radius = 1;
  void draw() {
    _outline();
    print(area + radius);
    final origin = Point.origin();
    _outline();
    Label();
    void local() {}
    local();
  }
  void _outline() {}
}

class Point {
  Point.origin();
}

class Label {}
''');

      final calls = await finder.callees(filePath: shapes, line: 4, column: 3);

      // A field and a local function are no calls; an implicit
      // constructor is its class
      expect(names(calls), ['_outline', 'area', 'origin', 'Label']);
      expect(calls.first.lineNumber, 13);
    });

    test('lists calls into other project files, not the SDK or '
        'itself', () async {
      write('lib/util.dart', 'int twice(int x) => x * 2;\n');
      final main = write('lib/main.dart', '''
import 'util.dart';

int count(int n) => n == 0 ? 0 : count(n - 1) + twice(n).abs();
''');

      final calls = await finder.callees(filePath: main, line: 3, column: 1);

      expect(calls.map((call) => p.basename(call.filePath)), ['util.dart']);
      expect(names(calls), ['twice']);
    });
  });

  group('definition', () {
    /// The name [place] marks, its file and its line.
    (String, String, int) named(SearchResult place) => (
      p.basename(place.filePath),
      place.lineContent.substring(place.matchStart, place.matchEnd),
      place.lineNumber,
    );

    /// Where [finder] says the name at the [nth] occurrence of [text] in
    /// [path], whose editor text is [content], is declared; [skip] moves
    /// the caret that many characters into the occurrence.
    Future<(String, String, int)> definitionAt(
      String path,
      String content,
      String text, {
      int nth = 0,
      int skip = 0,
    }) async {
      var offset = -1;
      for (var i = 0; i <= nth; i++) {
        offset = content.indexOf(text, offset + 1);
      }
      expect(offset, isNonNegative, reason: '"$text" #$nth not in the code');
      return named(
        await finder.definition(
          filePath: path,
          offset: offset + skip,
          content: content,
        ),
      );
    }

    const shapes = '''
class Circle {
  Circle(this.radius);
  Circle.unit() : this(1);
  int radius;
  int get area => radius * radius;
  void draw() {}
}

class Square {
  void draw() {}
}

class Label {}

int count = 0;
''';

    test('goes to classes, constructors and methods in other files', () async {
      write('lib/shapes.dart', shapes);
      const content = '''
import 'shapes.dart' as s;

void paint(s.Circle c, s.Square q) {
  c.draw();
  q.draw();
  s.Circle(2);
  s.Circle.unit();
  s.Label();
}
''';
      final paint = write('lib/paint.dart', content);

      expect(await definitionAt(paint, content, 'Circle c'), (
        'shapes.dart',
        'Circle',
        1,
      ));
      // That class's method, not a same-named one
      expect(await definitionAt(paint, content, 'draw'), (
        'shapes.dart',
        'draw',
        6,
      ));
      expect(await definitionAt(paint, content, 'draw', nth: 1), (
        'shapes.dart',
        'draw',
        10,
      ));
      // A constructor call's class name is the constructor, where it
      // starts, as an unnamed one has no name to mark; an implicit
      // constructor is its class
      final constructor = await finder.definition(
        filePath: paint,
        offset: content.indexOf('Circle(2)'),
        content: content,
      );
      expect((constructor.lineNumber, constructor.matchStart), (2, 2));
      expect(await definitionAt(paint, content, 'unit'), (
        'shapes.dart',
        'unit',
        3,
      ));
      expect(await definitionAt(paint, content, 'Label'), (
        'shapes.dart',
        'Label',
        13,
      ));
      // An import prefix is its import
      expect(await definitionAt(paint, content, 's.Square'), (
        'paint.dart',
        's',
        1,
      ));
    });

    test('goes to the field an implicit getter or setter, a write or a '
        'this. parameter names', () async {
      final shapesPath = write('lib/shapes.dart', shapes);
      const content = '''
import 'shapes.dart';

void grow(Circle c) {
  c.radius = c.area;
  count++;
  c.radius += 1;
}
''';
      final grow = write('lib/grow.dart', content);

      expect(await definitionAt(grow, content, 'radius ='), (
        'shapes.dart',
        'radius',
        4,
      ));
      expect(await definitionAt(grow, content, 'area'), (
        'shapes.dart',
        'area',
        5,
      ));
      expect(await definitionAt(grow, content, 'count'), (
        'shapes.dart',
        'count',
        15,
      ));
      expect(await definitionAt(grow, content, 'radius +='), (
        'shapes.dart',
        'radius',
        4,
      ));
      expect(await definitionAt(shapesPath, shapes, 'radius', skip: 1), (
        'shapes.dart',
        'radius',
        4,
      ));
    });

    test('goes to locals, parameters and named arguments, with the caret '
        'just past a name', () async {
      const content = '''
class Base {
  Base({required this.id});
  final int id;
}

class Child extends Base {
  Child({required super.id});
}

int twice(int value) {
  final doubled = value * 2;
  return doubled;
}

final child = Child(id: twice(1));
''';
      final code = write('lib/code.dart', content);

      expect(await definitionAt(code, content, 'doubled;', skip: 7), (
        'code.dart',
        'doubled',
        11,
      ));
      expect(await definitionAt(code, content, 'value *'), (
        'code.dart',
        'value',
        10,
      ));
      expect(await definitionAt(code, content, 'id: '), ('code.dart', 'id', 7));
      // A super. parameter is the parameter it fills
      expect(await definitionAt(code, content, 'id});', nth: 1), (
        'code.dart',
        'id',
        2,
      ));
    });

    test('reads unsaved edits, then the file on disk again', () async {
      const saved = 'int answer() => 42;\n\nfinal value = answer();\n';
      final code = write('lib/code.dart', saved);
      // Edits the editor hasn't saved yet move the declaration down
      const edited = '\n\nint answer() => 42;\n\nfinal value = answer();\n';

      expect(await definitionAt(code, edited, 'answer', nth: 1), (
        'code.dart',
        'answer',
        3,
      ));
      expect(await definitionAt(code, saved, 'answer', nth: 1), (
        'code.dart',
        'answer',
        1,
      ));
    });

    test('says why when the project doesn\'t declare the name', () async {
      const content = 'void main() {\n  print(1);\n}\n';
      final main = write('lib/main.dart', content);

      Future<void> expectError(int offset, String message) => expectLater(
        finder.definition(filePath: main, offset: offset, content: content),
        throwsA(predicate((e) => '$e'.contains(message))),
      );

      await expectError(
        content.indexOf('print'),
        'print is declared outside the project, in dart:core',
      );
      await expectError(
        content.indexOf('  print'),
        'No name to go to at the caret',
      );
    });
  });

  group('FileTexts', () {
    final first = DateTime(2024);
    final later = DateTime(2025);

    test('reads a file again only once it changed', () {
      final reads = <String>[];
      final texts = FileTexts((path) {
        reads.add(path);
        return 'uses $path';
      });
      expect(texts.update('a', first), isFalse);
      expect(texts.update('b', first), isFalse);

      expect(texts.mentioning('a'), ['a']);
      expect(texts.mentioning('b'), ['b']);
      expect(reads, ['a', 'b']);

      expect(texts.update('a', first), isFalse);
      expect(texts.mentioning('a'), ['a']);
      expect(reads, ['a', 'b']);

      expect(texts.update('a', later), isTrue);
      expect(texts.mentioning('a'), ['a']);
      expect(reads, ['a', 'b', 'a']);

      texts.remove('b');
      expect(texts.paths, ['a']);
    });
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

  group('lookupField', () {
    const hint = "'Search performers...'";

    /// The localizations class, with [getters] such as `String get a => '';`.
    void localizations([String getters = '']) =>
        write('lib/app_localizations.dart', '''
class BuildContext {}

class AppLocalizations {
  static AppLocalizations? of(BuildContext context) => AppLocalizations();
  $getters
}
''');

    test('finds the field, its values and reads, and rewrites them', () async {
      localizations();
      final content =
          '''
import 'app_localizations.dart';

class Field {
  const Field({required this.hint});
  final String hint;
}

class Tab {
  const Tab._({required this.searchHint});
  static Tab performers() => Tab._(searchHint: $hint);
  static Tab other(String text) => Tab._(searchHint: text);
  final String searchHint;
  Field build(BuildContext context) => Field(hint: searchHint);
}
''';
      final tab = write('lib/tab.dart', content);

      final field = await finder.lookupField(
        filePath: tab,
        offset: content.indexOf(hint),
      );

      expect(field.id, 'Tab.searchHint');
      expect(field.arguments.map((a) => a.source), [hint, 'text']);
      expect(field.reads.single.contextName, 'context');

      final string = HardcodedString(
        path: tab,
        line: 10,
        site: fcheck.HardcodedStringSite(
          offset: content.indexOf(hint),
          length: hint.length,
          textParts: const ['Search performers...'],
          interpolations: const [],
          isWidgetOutput: false,
        ),
      );
      final keys = ArbKeys({});
      final result = LookupRewrite(
        fields: [field],
        contents: {tab: content},
        config: const L10nConfig(),
        importUri: 'app_localizations.dart',
      ).apply([string], keys);
      final key = keys.added.keys.single;
      final rewritten = result.contents[tab]!;

      expect(result.localized, 1);
      expect(
        rewritten,
        contains('final String Function(AppLocalizations l10n) searchHint;'),
      );
      expect(rewritten, contains('searchHint: (l10n) => l10n.$key)'));
      expect(rewritten, contains('searchHint: (_) => text)'));
      expect(
        rewritten,
        contains('Field(hint: searchHint(AppLocalizations.of(context)!))'),
      );
      // Compiles once the key is generated
      localizations("String get $key => '';");
      await finder.checkCompiles(result.contents, 'Passing lookups');
    });

    test('refuses a field read without a BuildContext', () async {
      localizations();
      final content =
          '''
import 'app_localizations.dart';

class Tab {
  const Tab({required this.searchHint});
  static Tab performers() => Tab(searchHint: $hint);
  static String peek(Tab tab) => tab.searchHint;
  final String searchHint;
}
''';
      final tab = write('lib/tab.dart', content);

      expect(
        finder.lookupField(filePath: tab, offset: content.indexOf(hint)),
        throwsA(predicate((e) => '$e'.contains('read without a BuildContext'))),
      );
    });

    test('looks up many arguments in one request', () async {
      localizations();
      const other = "'Search artists...'";
      final content =
          '''
import 'app_localizations.dart';

class Tab {
  const Tab({required this.searchHint, this.count = 0});
  static Tab performers() => Tab(searchHint: $hint);
  static Tab artists() => Tab(searchHint: $other);
  static Tab counted() => Tab(searchHint: 'x', count: 1);
  final String searchHint;
  final int count;
  String build(BuildContext context) => searchHint;
}
''';
      final tab = write('lib/tab.dart', content);

      final found = await finder.lookupFields([
        (filePath: tab, offset: content.indexOf(hint)),
        (filePath: tab, offset: content.indexOf(other)),
        (filePath: tab, offset: content.indexOf('1)')),
      ]);

      expect(found, hasLength(3));
      expect(found[0].field?.id, 'Tab.searchHint');
      expect(found[0].field?.arguments, hasLength(3));
      // The same field, looked up once
      expect(identical(found[0].field, found[1].field), isTrue);
      expect(found[2].field, isNull);
      expect(found[2].error, contains('count is not a String'));
    });
  });
}
