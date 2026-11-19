import 'dart:io';

import 'package:fcheck/fcheck.dart' as fcheck;
import 'package:fide/models/arb_keys.dart';
import 'package:fide/models/hardcoded_string.dart';
import 'package:fide/models/l10n_config.dart';
import 'package:fide/models/lookup_rewrite.dart';
import 'package:fide/models/search_result.dart';
import 'package:fide/services/flutter_sdk.dart';
import 'package:fide/services/process_runner.dart';
import 'package:fide/services/reference_finder.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

// Reports the Dart SDK the tests run on, without launching flutter
class _TestSdk extends FlutterSdk {
  const _TestSdk() : super(const ProcessRunner());

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
      dartSdkPath: const _TestSdk().dartSdkPath,
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
