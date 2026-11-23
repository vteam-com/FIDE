import 'dart:io';

import 'package:fcheck/fcheck.dart';
import 'package:fide/models/class_split_result.dart';
import 'package:fide/services/class_split_service.dart';
import 'package:fide/services/class_splitter.dart';
import 'package:fide/services/file_content_reader.dart';
import 'package:fide/services/quick_fix_handler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// A splitter moving `Circle` out of `shapes.dart` and refusing any other
/// file, recording each file it plans.
class _FakeSplitter implements ClassSplitService {
  final List<String> planned = [];

  @override
  Future<ClassSplitResult> plan({
    required String projectPath,
    required String filePath,
  }) async {
    planned.add(p.basename(filePath));
    if (p.basename(filePath) != 'shapes.dart') {
      throw const ClassSplitException('it is tangled');
    }
    final circle = p.join(p.dirname(filePath), 'circle.dart');
    return ClassSplitResult(
      files: {filePath: 'class Shapes {}\n', circle: 'class Circle {}\n'},
      createdFiles: [circle],
    );
  }
}

void main() {
  late Directory project;

  setUp(() {
    project = Directory.systemTemp.createTempSync('fide_split_classes_');
    for (final MapEntry(key: path, value: content) in {
      'pubspec.yaml': 'name: sample\n',
      'lib/shapes.dart': 'class Shapes {}\n\nclass Circle {}\n',
      'lib/menu.dart': 'class Menu {}\n\nclass Item {}\n',
      'lib/single.dart': 'class Single {}\n',
      'lib/legacy.dart':
          '// ignore: fcheck_one_class_per_file\n'
          'class Legacy {}\n\nclass Old {}\n',
    }.entries) {
      File(p.join(project.path, path))
        ..createSync(recursive: true)
        ..writeAsStringSync(content);
    }
  });
  tearDown(() => project.deleteSync(recursive: true));

  test('splits each file breaking the rule, not one opting out, writing '
      'it, and says which it left and why', () async {
    final splitter = _FakeSplitter();
    String? asked;

    final outcome =
        await SplitClassesHandler(splitter, const FileContentReader()).run(
          QuickFixRequest(
            projectPath: project.path,
            metrics: AnalyzeFolder(project).analyze(),
            confirm: (message) async {
              asked = message;
              return true;
            },
          ),
        );

    expect(splitter.planned, unorderedEquals(['shapes.dart', 'menu.dart']));
    expect(asked, startsWith('Split 2 files declaring more than one public'));
    expect(outcome!.summary, 'Split 1 file; left menu.dart: it is tangled');
    expect(
      File(p.join(project.path, 'lib', 'circle.dart')).readAsStringSync(),
      'class Circle {}\n',
    );
    expect(
      outcome.changedFiles.map(p.basename),
      unorderedEquals(['shapes.dart', 'circle.dart']),
    );
  });
}
