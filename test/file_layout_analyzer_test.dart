import 'dart:io';

import 'package:fide/models/code_category.dart';
import 'package:fide/models/file_layout_review.dart';
import 'package:fide/services/file_layout_analyzer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// A screen built on a scaffold.
const String _screen = '''
import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) => const Scaffold();
}
''';

/// A widget reading no app state.
const String _pureWidget = '''
import 'package:flutter/material.dart';

class ScoreCard extends StatelessWidget {
  const ScoreCard({super.key, required this.score});

  final int score;

  @override
  Widget build(BuildContext context) => Text('\$score');
}
''';

/// A class holding data.
const String _model = '''
class Score {
  const Score(this.points);

  final int points;
}
''';

void main() {
  late Directory project;

  setUp(() {
    project = Directory.systemTemp.createTempSync('file_layout_');
    File(p.join(project.path, 'pubspec.yaml'))
        .writeAsStringSync('name: demo\n');
  });

  tearDown(() => project.deleteSync(recursive: true));

  /// Writes [files], Dart code by project-relative path, then reviews the
  /// project.
  FileLayoutReview review(Map<String, String> files) {
    for (final MapEntry(key: path, value: content) in files.entries) {
      File(p.join(project.path, path))
        ..createSync(recursive: true)
        ..writeAsStringSync(content);
    }
    return const FileLayoutAnalyzer().analyze(project.path);
  }

  /// [review]'s moves, as `category path -> target`.
  List<String> movesOf(FileLayoutReview review) => [
    for (final move in review.moves)
      '${move.category.name} ${move.path} -> ${move.target}',
  ];

  test('a screen, a pure widget and a model each move to their folder', () {
    final layout = review({
      'lib/ui/home_screen.dart': _screen,
      'lib/screens/score_card.dart': _pureWidget,
      'lib/services/score.dart': _model,
    });

    expect(movesOf(layout), [
      'views lib/ui/home_screen.dart -> lib/views/home_screen.dart',
      'widgets lib/screens/score_card.dart -> lib/widgets/score_card.dart',
      'models lib/services/score.dart -> lib/models/score.dart',
    ]);
    expect(layout.moves.first.name, 'HomeScreen');
    expect(layout.moves.first.line, 3);
    expect(layout.packageName, 'demo');
  });

  test('a file in a folder named for its kind stays, at any depth', () {
    final layout = review({
      'lib/screens/home_screen.dart': _screen,
      'lib/features/scores/widgets/score_card.dart': _pureWidget,
      'lib/data/score.dart': _model,
    });

    expect(layout.moves, isEmpty);
  });

  test('a widget reading app state, even through a project import, is no '
      'pure widget', () {
    final layout = review({
      'lib/state/scores.dart':
          "import 'package:flutter_riverpod/flutter_riverpod.dart';\n"
          'final scores = Provider((_) => 0);\n',
      'lib/ui/score_card.dart':
          "import 'package:demo/state/scores.dart';\n$_pureWidget",
    });

    expect(movesOf(layout), isEmpty);
  });

  test('a type with I/O, async code or Flutter is no model; nor is a class '
      'of static members or an interface of methods', () {
    final layout = review({
      'lib/services/file_score.dart': "import 'dart:io';\n$_model",
      'lib/services/score_api.dart':
          'class ScoreApi {\n'
          '  final String url = "";\n'
          '  Future<int> fetch() async => 0;\n'
          '}\n',
      'lib/services/score_color.dart':
          "import 'package:flutter/material.dart';\n$_model",
      'lib/services/limits.dart':
          'class Limits {\n  static const int max = 3;\n}\n',
      'lib/services/score_sink.dart':
          'abstract class ScoreSink {\n  void add(int score);\n}\n',
    });

    expect(movesOf(layout), isEmpty);
  });

  test('a widget opened as a route is a view, scaffold or not; one taking '
      'a widget to wrap is not', () {
    final layout = review({
      'lib/main.dart': '''
import 'package:flutter/material.dart';
import 'package:demo/ui/shell.dart';
import 'package:demo/ui/details.dart';

void main() => runApp(MaterialApp(
  home: const Shell(child: Text('')),
  routes: {'/details': (context) => const Details()},
));
''',
      'lib/ui/shell.dart': '''
import 'package:flutter/material.dart';

class Shell extends StatelessWidget {
  const Shell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Scaffold(body: child);
}
''',
      'lib/ui/details.dart': '''
import 'package:flutter/material.dart';

class Details extends StatelessWidget {
  const Details({super.key});

  @override
  Widget build(BuildContext context) => const Text('');
}
''',
    });

    expect(movesOf(layout), [
      'views lib/ui/details.dart -> lib/views/details.dart',
      'widgets lib/ui/shell.dart -> lib/widgets/shell.dart',
    ]);
  });

  test('a widget named as a view stays in a views folder', () {
    final layout = review({
      'lib/views/accounts/accounts_view.dart': _pureWidget,
      'lib/views/accounts/score_card.dart': _pureWidget,
    });

    expect(movesOf(layout), [
      'widgets lib/views/accounts/score_card.dart -> '
          'lib/widgets/score_card.dart',
    ]);
  });

  test('the app, its localizations and an ignored file stay', () {
    final layout = review({
      'lib/app.dart':
          "import 'package:flutter/material.dart';\n"
          'class App extends StatelessWidget {\n'
          '  const App({super.key});\n'
          '  @override\n'
          '  Widget build(BuildContext context) => const MaterialApp();\n'
          '}\n',
      'lib/l10n/strings.dart': _model,
      'lib/services/score.dart':
          '// ignore: ${FileLayoutAnalyzer.ignoreName}\n$_model',
    });

    expect(layout.moves, isEmpty);
  });

  test('parts move along; a move onto a file already there is blocked', () {
    final layout = review({
      'lib/services/score.dart': "part 'score.g.dart';\n\n$_model",
      'lib/services/score.g.dart': "part of 'score.dart';\n",
      'lib/services/goal.dart': _model.replaceAll('Score', 'Goal'),
      'lib/models/goal.dart': 'class Other {}\n',
    });

    final [goal, score] = layout.of(CodeCategory.models);
    expect(goal.blocker, 'lib/models/goal.dart already exists');
    expect(score.blocker, isNull);
    expect(score.parts, ['lib/services/score.g.dart']);
    expect(score.paths, {
      'lib/services/score.dart': 'lib/models/score.dart',
      'lib/services/score.g.dart': 'lib/models/score.g.dart',
    });
  });
}
