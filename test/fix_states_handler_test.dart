import 'dart:io';

import 'package:fcheck/fcheck.dart';
import 'package:fide/models/class_split_result.dart';
import 'package:fide/services/class_split_service.dart';
import 'package:fide/services/file_content_reader.dart';
import 'package:fide/services/quick_fix_handler.dart';
import 'package:fide/services/widget_state_analyzer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// A splitter taking `counter_state.dart`'s State into `counter.dart`,
/// recording each file it plans and how.
class _FakeSplitter implements ClassSplitService {
  final List<(String, bool)> planned = [];

  @override
  Future<ClassSplitResult> plan({
    required String projectPath,
    required String filePath,
    bool statesOnly = false,
  }) async {
    planned.add((p.basename(filePath), statesOnly));
    return ClassSplitResult(
      files: {filePath: 'class Counter {}\n\nclass CounterState {}\n'},
      createdFiles: const [],
      gatheredStates: const ['CounterState'],
      mergedFiles: {
        p.join(p.dirname(filePath), 'counter_state.dart'): filePath,
      },
    );
  }
}

void main() {
  late Directory project;

  setUp(() {
    project = Directory.systemTemp.createTempSync('fide_fix_states_');
    for (final MapEntry(key: path, value: content) in {
      'pubspec.yaml': 'name: sample\n',
      'lib/counter.dart':
          "part 'counter_state.dart';\n\n"
          'class Counter extends StatefulWidget {}\n',
      'lib/counter_state.dart':
          "part of 'counter.dart';\n\n"
          'class CounterState extends State<Counter> {}\n',
      'test/counter_test.dart': 'CounterState? state;\n',
      'lib/dial.dart':
          "import 'dial_state.dart';\n\n"
          'class Dial extends StatefulWidget {}\n',
      'lib/dial_state.dart':
          "import 'dial.dart';\n\n"
          'class _DialState extends State<Dial> {}\n',
    }.entries) {
      File(p.join(project.path, path))
        ..createSync(recursive: true)
        ..writeAsStringSync(content);
    }
  });
  tearDown(() => project.deleteSync(recursive: true));

  test('tidies the States of each widget file, deleting the part files it '
      'empties, and says which it left', () async {
    final splitter = _FakeSplitter();

    final outcome =
        await FixStatesHandler(
          const WidgetStateAnalyzer(),
          splitter,
          const FileContentReader(),
        ).run(
          QuickFixRequest(
            projectPath: project.path,
            metrics: AnalyzeFolder(project).analyze(),
            confirm: (_) async => true,
          ),
        );

    expect(splitter.planned, [('counter.dart', true)]);
    expect(
      File(p.join(project.path, 'lib', 'counter_state.dart')).existsSync(),
      isFalse,
    );
    expect(
      outcome!.changedFiles.map(p.basename),
      unorderedEquals(['counter.dart', 'counter_state.dart']),
    );
    expect(
      outcome.summary,
      'Moved CounterState beside its widget; left dial_state.dart: '
      '_DialState is in another library than Dial; move it by hand',
    );
  });
}
