import 'dart:io';

import 'package:fide/providers/app_providers.dart';
import 'package:fide/providers/project_rename.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory project;
  late ProviderContainer container;

  setUp(() {
    project = Directory(
      Directory.systemTemp
          .createTempSync('fide_rename_')
          .resolveSymbolicLinksSync(),
    );
    container = ProviderContainer();
    container.read(currentProjectPathProvider.notifier).state = project.path;
    File(p.join(project.path, 'pubspec.yaml'))
        .writeAsStringSync('name: demo\n');
  });
  tearDown(() {
    container.dispose();
    project.deleteSync(recursive: true);
  });

  /// Writes [content] at the project-relative [path]; returns its
  /// absolute path.
  String write(String path, String content) {
    final file = File(p.join(project.path, path))
      ..createSync(recursive: true)
      ..writeAsStringSync(content);
    return file.path;
  }

  /// The text of the project-relative [path].
  String read(String path) =>
      File(p.join(project.path, path)).readAsStringSync();

  /// Renames the project-relative [from] to [to], as the project tree
  /// does, through a widget's ref.
  Future<void> rename(
    WidgetTester tester,
    String from,
    String to, {
    bool isDirectory = false,
  }) async {
    late WidgetRef widgetRef;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: Consumer(
          builder: (_, ref, _) {
            widgetRef = ref;
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    await tester.runAsync(
      () => renameInProject(
        widgetRef.read,
        p.join(project.path, from),
        p.join(project.path, to),
        isDirectory: isDirectory,
      ),
    );
  }

  testWidgets('renaming a Dart file points every import of it at its new '
      'name, and its tab follows it', (tester) async {
    final score = write('lib/score.dart', 'class Score {}\n');
    write('lib/card.dart', "import 'score.dart';\n\nclass Card {}\n");
    write('test/score_test.dart', "import 'package:demo/score.dart';\n");
    await tester.runAsync(
      () => container.read(openDocumentsProvider.notifier).open(score),
    );

    await rename(tester, 'lib/score.dart', 'lib/points.dart');

    expect(File(score).existsSync(), isFalse);
    expect(read('lib/points.dart'), 'class Score {}\n');
    expect(read('lib/card.dart'), startsWith("import 'points.dart';"));
    expect(
      read('test/score_test.dart'),
      "import 'package:demo/points.dart';\n",
    );
    expect(
      container.read(openDocumentsProvider).active?.filePath,
      p.join(project.path, 'lib/points.dart'),
    );
  });

  testWidgets('renaming a folder moves everything in it and points every '
      'import of its Dart files at their new place', (tester) async {
    write('lib/ui/home.dart', 'class Home {}\n');
    write('lib/ui/notes.txt', 'notes\n');
    write('lib/main.dart', "import 'package:demo/ui/home.dart';\n");

    await rename(tester, 'lib/ui', 'lib/views', isDirectory: true);

    expect(Directory(p.join(project.path, 'lib/ui')).existsSync(), isFalse);
    expect(read('lib/views/home.dart'), 'class Home {}\n');
    expect(read('lib/views/notes.txt'), 'notes\n');
    expect(read('lib/main.dart'), "import 'package:demo/views/home.dart';\n");
  });

  test('renaming onto an existing file refuses, changing nothing', () async {
    final score = write('lib/score.dart', 'class Score {}\n');
    final points = write('lib/points.dart', 'class Points {}\n');

    await expectLater(
      renameInProject(container.read, score, points, isDirectory: false),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          'lib/points.dart already exists',
        ),
      ),
    );
    expect(read('lib/score.dart'), 'class Score {}\n');
    expect(read('lib/points.dart'), 'class Points {}\n');
  });

  test('moving a Dart file into a new folder creates it, and lists the '
      'files written', () async {
    final score = write('lib/score.dart', 'class Score {}\n');
    final main = write('lib/main.dart', "import 'score.dart';\n");
    final moved = p.join(project.path, 'lib/models/score.dart');

    final written = await renameInProject(
      container.read,
      score,
      moved,
      isDirectory: false,
    );

    expect(read('lib/models/score.dart'), 'class Score {}\n');
    expect(read('lib/main.dart'), "import 'models/score.dart';\n");
    expect(written.keys, unorderedEquals([moved, main]));
  });
}
