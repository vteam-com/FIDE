import 'dart:io';

import 'package:fide/services/class_splitter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// Reads files from disk, appending each path read to the file [log], so
/// the reads made in the planner's isolate can be counted.
String Function(String path) _loggingReader(String log) => (path) {
  File(log).writeAsStringSync('$path\n', mode: FileMode.append);
  return File(path).readAsStringSync();
};

/// A stand-in for the Flutter classes the splitter recognizes by name.
const String _framework = '''
abstract class StatefulWidget {
  const StatefulWidget();
  State createState();
}

abstract class State<T extends StatefulWidget> {}
''';

/// The import of [_framework], written as `lib/framework.dart`.
const String _importFramework = "import 'framework.dart';\n\n";

/// A stateful widget, `Counter`, whose State is named [state].
String _counterWidget(String state) =>
    '''
/// Counts taps.
class Counter extends StatefulWidget {
  const Counter();

  @override
  State<Counter> createState() => $state();
}
''';

/// The State of [_counterWidget], named [state].
String _counterState(String state) =>
    '''
/// [Counter]'s state.
class $state extends State<Counter> {
  int count = 0;
}
''';

/// [_counterWidget] and its State, named [state], in one file.
String _counter(String state) =>
    '${_counterWidget(state)}\n${_counterState(state)}';

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

  test('reads each project file once, however many classes move', () async {
    write('lib/a.dart', '''
class A {}

class B {}

class C {}

class D {}
''');
    for (final user in ['one', 'two', 'three']) {
      write('lib/$user.dart', '''
import 'a.dart';

final $user = [A(), B(), C(), D()];
''');
    }
    final log = p.join(
      Directory.systemTemp.createTempSync('fide_split_log_').path,
      'reads.log',
    );
    final logging = ClassSplitter(
      dartSdkPath: splitter.dartSdkPath,
      readFile: _loggingReader(log),
    );

    final result = await logging.plan(
      projectPath: project,
      filePath: path('lib/a.dart'),
    );

    expect(result.createdFiles, hasLength(3));
    expect(
      result.files[path('lib/one.dart')],
      allOf(contains("import 'b.dart';"), contains("import 'd.dart';")),
    );
    final reads = File(log).readAsLinesSync();
    expect(reads.toSet(), hasLength(reads.length));
    expect(reads, contains(path('lib/one.dart')));
    Directory(p.dirname(log)).deleteSync(recursive: true);
  });

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

  test('a class and the file it leaves that would import each other share '
      'one library: the class moves to a part file', () async {
    write('lib/shop.dart', '''
class Shop {
  Item first() => Item(this);
}

class Item {
  Item(this.shop);

  final Shop shop;
}
''');

    final files = await split('lib/shop.dart');

    expect(files['lib/shop.item.dart'], startsWith("part of 'shop.dart';"));
    expect(files['lib/shop.dart'], contains("part 'shop.item.dart';"));
    expect(files.keys, isNot(contains('lib/item.dart')));
  });

  test(
    'makes a widget\'s public State private, as part of its widget',
    () async {
      write('lib/framework.dart', _framework);
      write('lib/counter.dart', '$_importFramework${_counter('CounterState')}');

      final result = await splitter.plan(
        projectPath: project,
        filePath: path('lib/counter.dart'),
      );

      expect(result.privatizedStates, ['CounterState']);
      expect(result.createdFiles, isEmpty);
      final counter = result.files[path('lib/counter.dart')]!;
      expect(counter, contains('class _CounterState extends State<Counter>'));
      expect(counter, contains('createState() => _CounterState();'));
      expect(counter, isNot(contains(' CounterState')));
      expect(result.summary, 'Made CounterState private');
    },
  );

  test('keeps a State other files use public, by its widget', () async {
    write('lib/framework.dart', _framework);
    write(
      'lib/counter.dart',
      '$_importFramework${_counter('CounterState')}\nclass Badge {}\n',
    );
    write('lib/panel.dart', '''
import 'counter.dart';

CounterState? counterOf(Object state) => state is CounterState ? state : null;
''');

    final files = await split('lib/counter.dart');

    expect(files.keys, containsAll(['lib/counter.dart', 'lib/badge.dart']));
    expect(files['lib/counter.dart'], contains('class CounterState extends'));
    expect(files['lib/counter.dart'], isNot(contains('class Badge')));
  });

  test('moves a stateful widget with its private State', () async {
    write('lib/framework.dart', _framework);
    write(
      'lib/board.dart',
      '${_importFramework}class Board {}\n\n${_counter('_CounterState')}',
    );

    final files = await split('lib/board.dart');

    expect(files['lib/counter.dart'], contains('class Counter extends'));
    expect(files['lib/counter.dart'], contains('class _CounterState extends'));
    expect(files['lib/board.dart'], isNot(contains('Counter')));
  });

  group('a State in a part file of its widget\'s library', () {
    setUp(() {
      write('lib/framework.dart', _framework);
      write(
        'lib/counter.dart',
        "${_importFramework}part 'counter_state.dart';\n\n"
            '${_counterWidget('CounterState')}',
      );
      write(
        'lib/counter_state.dart',
        "part of 'counter.dart';\n\n${_counterState('CounterState')}",
      );
    });

    test('moves beside its widget, the emptied part file going', () async {
      final result = await splitter.plan(
        projectPath: project,
        filePath: path('lib/counter.dart'),
        statesOnly: true,
      );

      final counter = result.files[path('lib/counter.dart')]!;
      expect(counter, isNot(contains('part ')));
      expect(counter, contains("/// [Counter]'s state.\nclass _CounterState"));
      expect(result.mergedFiles, {
        path('lib/counter_state.dart'): path('lib/counter.dart'),
      });
      expect(
        result.files.keys,
        isNot(contains(path('lib/counter_state.dart'))),
      );
      expect(
        result.summary,
        'Moved CounterState beside its widget; Made CounterState private',
      );
    });

    test('stays public when a test reaches it by name', () async {
      write('test/counter_test.dart', '''
import '../lib/counter.dart';

int countOf(Object state) => (state as CounterState).count;
''');

      final result = await splitter.plan(
        projectPath: project,
        filePath: path('lib/counter.dart'),
        statesOnly: true,
      );

      expect(result.gatheredStates, ['CounterState']);
      expect(result.privatizedStates, isEmpty);
      expect(
        result.files[path('lib/counter.dart')],
        contains('class CounterState extends State<Counter>'),
      );
    });
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
