import 'dart:io';

import 'package:fide/models/code_category.dart';
import 'package:fide/models/file_layout_review.dart';
import 'package:fide/models/status_tone.dart';
import 'package:fide/providers/analyzer_fix_controller.dart';
import 'package:fide/services/blocking_task.dart';
import 'package:fide/services/code_formatter.dart';
import 'package:fide/services/file_content_reader.dart';
import 'package:fide/services/file_mover.dart';
import 'package:fide/services/process_runner.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory project;

  setUp(() {
    project = Directory.systemTemp.createTempSync('fide_analyzer_fix_');
    File(p.join(project.path, 'lib', 'card.dart'))
      ..createSync(recursive: true)
      ..writeAsStringSync('class Card {}\n');
  });
  tearDown(() => project.deleteSync(recursive: true));

  test('a move cancelled once planned writes and deletes nothing', () async {
    final written = <String>[];
    final deleted = <String>[];
    // As OpenDocumentsNotifier.applyMoves: deletes once the plan is written
    final controller = AnalyzerFixController(
      applyEdits: (edit) => edit(),
      applyMoves: (moves, edit) async {
        final files = await edit();
        written.addAll(files.keys);
        deleted.addAll(moves.keys);
        return files;
      },
      reader: const FileContentReader(),
      formatter: const CodeFormatter(ProcessRunner()),
      mover: FileMover(
        listDartFiles: (projectPath) async => [
          p.join(projectPath, 'lib', 'card.dart'),
        ],
      ),
    );
    addTearDown(controller.dispose);
    final task = BlockingTask('Moving')..cancel();

    final outcome = await controller.move(
      project.path,
      const [
        FileMove(
          category: CodeCategory.widgets,
          path: 'lib/card.dart',
          target: 'lib/widgets/card.dart',
          name: 'Card',
          line: 1,
        ),
      ],
      key: 'move',
      task: task,
    );

    expect(outcome.message, AnalyzerFixController.cancelledMessage);
    expect(outcome.tone, StatusTone.info);
    expect(written, isEmpty);
    expect(deleted, isEmpty);
  });
}
