import 'dart:io';

import 'package:fcheck/fcheck.dart' as fcheck;
import 'package:fide/models/arb_keys.dart';
import 'package:fide/models/hardcoded_string.dart';
import 'package:fide/models/l10n_config.dart';
import 'package:fide/models/lookup_rewrite.dart';
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
  });
}
