import 'package:fide/services/file_mover.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_file_content_reader.dart';

void main() {
  /// [contents] rewritten for moving `lib/screens/card.dart` to
  /// `lib/widgets/card.dart`, or [moves] when given, in package `demo`.
  Map<String, String> rewrite(
    Map<String, String> contents, {
    Map<String, String> moves = const {
      'lib/screens/card.dart': 'lib/widgets/card.dart',
    },
  }) => FileMover.rewrite(contents, moves, packageName: 'demo');

  test('a package import of the moved file points at its new place', () {
    final rewritten = rewrite({
      'lib/screens/card.dart': 'class Card {}\n',
      'test/card_test.dart':
          "import 'package:demo/screens/card.dart';\n\nvoid main() {}\n",
    });

    expect(rewritten.keys, {'lib/widgets/card.dart', 'test/card_test.dart'});
    expect(rewritten['lib/widgets/card.dart'], 'class Card {}\n');
    expect(
      rewritten['test/card_test.dart'],
      "import 'package:demo/widgets/card.dart';\n\nvoid main() {}\n",
    );
  });

  test('a relative import of the moved file follows it, from any folder', () {
    final rewritten = rewrite({
      'lib/screens/card.dart': 'class Card {}\n',
      'lib/screens/home.dart': "import 'card.dart';\n\nclass Home {}\n",
      'test/card_test.dart': "import '../lib/screens/card.dart';\n",
    });

    expect(
      rewritten['lib/screens/home.dart'],
      "import '../widgets/card.dart';\n\nclass Home {}\n",
    );
    expect(
      rewritten['test/card_test.dart'],
      "import '../lib/widgets/card.dart';\n",
    );
  });

  test('the moved file points its own relative imports from its new '
      'folder, its package ones unchanged', () {
    final rewritten = rewrite({
      'lib/screens/card.dart':
          "import 'package:demo/models/score.dart';\n"
          "import '../theme/colors.dart';\n"
          "import 'card_style.dart';\n\n"
          'class Card {}\n',
    });

    expect(
      rewritten['lib/widgets/card.dart'],
      "import 'package:demo/models/score.dart';\n"
      "import '../screens/card_style.dart';\n"
      "import '../theme/colors.dart';\n\n"
      'class Card {}\n',
    );
  });

  test('a rewritten import takes its place in URI order, keeping its '
      'quotes, prefix and combinators', () {
    final rewritten = rewrite({
      'lib/screens/card.dart': 'class Card {}\n',
      'lib/main.dart':
          "import 'package:demo/models/score.dart';\n"
          'import "package:demo/screens/card.dart" as c show Card;\n'
          "import 'package:demo/services/api.dart';\n\n"
          'void main() {}\n',
    });

    expect(
      rewritten['lib/main.dart'],
      "import 'package:demo/models/score.dart';\n"
      "import 'package:demo/services/api.dart';\n"
      'import "package:demo/widgets/card.dart" as c show Card;\n\n'
      'void main() {}\n',
    );
  });

  test('cutting the only import of a group leaves one blank line', () {
    final rewritten = rewrite({
      'lib/screens/card.dart': 'class Card {}\n',
      'lib/main.dart':
          "import 'package:flutter/material.dart';\n\n"
          "import 'screens/card.dart';\n\n"
          'void main() {}\n',
    });

    expect(
      rewritten['lib/main.dart'],
      "import 'package:flutter/material.dart';\n"
      "import 'widgets/card.dart';\n\n"
      'void main() {}\n',
    );
  });

  test('parts move along, their directives unchanged', () {
    final rewritten = rewrite(
      {
        'lib/screens/card.dart':
            "part 'card.g.dart';\n\nclass Card with _\$Card {}\n",
        'lib/screens/card.g.dart': "part of 'card.dart';\n\nmixin _\$Card {}\n",
      },
      moves: {
        'lib/screens/card.dart': 'lib/widgets/card.dart',
        'lib/screens/card.g.dart': 'lib/widgets/card.g.dart',
      },
    );

    expect(
      rewritten['lib/widgets/card.dart'],
      "part 'card.g.dart';\n\nclass Card with _\$Card {}\n",
    );
    expect(
      rewritten['lib/widgets/card.g.dart'],
      "part of 'card.dart';\n\nmixin _\$Card {}\n",
    );
  });

  test('a conditional import is pointed in place, configurations too', () {
    final rewritten = rewrite(
      {
        'lib/screens/card.dart': 'class Card {}\n',
        'lib/screens/card_io.dart': 'class Card {}\n',
        'lib/main.dart':
            "import 'screens/card.dart'\n"
            "    if (dart.library.io) 'screens/card_io.dart';\n",
      },
      moves: {
        'lib/screens/card.dart': 'lib/widgets/card.dart',
        'lib/screens/card_io.dart': 'lib/widgets/card_io.dart',
      },
    );

    expect(
      rewritten['lib/main.dart'],
      "import 'widgets/card.dart'\n"
      "    if (dart.library.io) 'widgets/card_io.dart';\n",
    );
  });

  test('a file naming no moved file is left out', () {
    final rewritten = rewrite({
      'lib/screens/card.dart': 'class Card {}\n',
      'lib/main.dart': "import 'package:demo/screens/home.dart';\n",
    });

    expect(rewritten.keys, ['lib/widgets/card.dart']);
  });

  group('plan', () {
    /// A mover over [reader]'s files, listing them all.
    FileMover moverOf(FakeFileContentReader reader) => FileMover(
      reader: reader,
      listDartFiles: (_) async => reader.files.keys.toList(),
    );

    test('writes the moved file and its importers, by absolute path', () async {
      final reader = FakeFileContentReader()
        ..files['/p/lib/screens/card.dart'] = 'class Card {}\n'
        ..files['/p/lib/main.dart'] = "import 'screens/card.dart';\n"
        ..files['/p/lib/other.dart'] = 'class Other {}\n';

      final files = await moverOf(reader).plan('/p', {
        'lib/screens/card.dart': 'lib/widgets/card.dart',
      }, packageName: 'demo');

      expect(files, {
        '/p/lib/widgets/card.dart': 'class Card {}\n',
        '/p/lib/main.dart': "import 'widgets/card.dart';\n",
      });
    });

    test('refuses a move onto a file already there', () async {
      final reader = FakeFileContentReader()
        ..files['/p/lib/screens/card.dart'] = 'class Card {}\n'
        ..files['/p/lib/widgets/card.dart'] = 'class Other {}\n';

      expect(
        moverOf(reader)
            .plan('/p', {'lib/screens/card.dart': 'lib/widgets/card.dart'}),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            'lib/widgets/card.dart already exists',
          ),
        ),
      );
    });
  });
}
