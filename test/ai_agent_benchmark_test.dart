import 'dart:io';

import 'package:fide/models/local_model.dart';
import 'package:fide/models/model_message.dart';
import 'package:fide/models/status_tone.dart';
import 'package:fide/providers/app_providers.dart';
import 'package:fide/providers/project_rename.dart';
import 'package:fide/services/code_edit_agent.dart';
import 'package:fide/services/dart_analyzer.dart';
import 'package:fide/services/ollama_client.dart';
import 'package:fide/services/process_runner.dart';
import 'package:fide/services/project_file_store.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

/// Runs of each task, from `FIDE_AI_BENCH`; null skips the benchmark,
/// which needs the local Ollama model and takes minutes.
final int? _runs = int.tryParse(Platform.environment['FIDE_AI_BENCH'] ?? '');

/// The Ollama model measured, from `FIDE_AI_MODEL`:
/// [LocalModel.defaultModel] when unset, or any downloaded tag, such as
/// `qwen3.8:27b`.
final String _model =
    Platform.environment['FIDE_AI_MODEL'] ?? LocalModel.defaultModel.tag;

/// The tasks run, from `FIDE_AI_BENCH_TASKS` (names separated by commas);
/// all of them when unset.
final Set<String>? _only = Platform.environment['FIDE_AI_BENCH_TASKS']
    ?.split(',')
    .map((name) => name.trim())
    .toSet();

/// Text HomeScreen shows with no products, which a question finds.
const String _emptyText = 'Nothing for sale yet';

/// The small Flutter app every task works on, by path.
const Map<String, String> _app = {
  'pubspec.yaml': '''
name: shop
description: A small shop app.
publish_to: none
environment:
  sdk: ^3.9.0
dependencies:
  flutter:
    sdk: flutter
''',
  'lib/main.dart': '''
import 'package:flutter/material.dart';
import 'package:shop/screens/home_screen.dart';

void main() => runApp(const ShopApp());

/// The shop app.
class ShopApp extends StatelessWidget {
  const ShopApp({super.key});

  @override
  Widget build(BuildContext context) =>
      const MaterialApp(title: 'Shop', home: HomeScreen());
}
''',
  'lib/models/product.dart': '''
/// A product for sale.
class Product {
  const Product({required this.name, required this.price, this.inStock = true});

  final String name;
  final double price;
  final bool inStock;
}
''',
  'lib/services/cart.dart': '''
import 'package:shop/models/product.dart';

/// The products the user is buying.
class Cart {
  final List<Product> _items = [];

  List<Product> get items => List.unmodifiable(_items);

  void add(Product product) => _items.add(product);

  void remove(Product product) => _items.remove(product);

  double get total => _items.fold(0, (sum, p) => sum + p.price);

  String describe() => _items.map((p) => p.name).join(', ');
}
''',
  'lib/widgets/product_tile.dart': r'''
import 'package:flutter/material.dart';
import 'package:shop/models/product.dart';

/// One product in a list, with a button adding it to the cart.
class ProductTile extends StatelessWidget {
  const ProductTile({super.key, required this.product, required this.onAdd});

  final Product product;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) => ListTile(
    title: Text(product.name),
    subtitle: Text('\$${product.price.toStringAsFixed(2)}'),
    trailing: IconButton(
      icon: const Icon(Icons.add_shopping_cart),
      onPressed: product.inStock ? onAdd : null,
    ),
  );
}
''',
  'lib/screens/home_screen.dart':
      '''
import 'package:flutter/material.dart';
import 'package:shop/models/product.dart';
import 'package:shop/services/cart.dart';
import 'package:shop/widgets/product_tile.dart';

/// Lists the products and the cart's total.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final Cart _cart = Cart();
  final List<Product> _products = [];

  void _addSample() {
    setState(() {
      _products.add(Product(name: 'Item \${_products.length + 1}', price: 9.99));
    });
  }

  void _buy(Product product) {
    setState(() => _cart.add(product));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Total: \\\$\${_cart.total.toStringAsFixed(2)}')),
      body: _products.isEmpty
          ? const Center(child: Text('$_emptyText'))
          : ListView(
              children: [
                for (final product in _products)
                  ProductTile(product: product, onAdd: () => _buy(product)),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addSample,
        child: const Icon(Icons.add),
      ),
    );
  }
}
''',
};

/// Edits breaking the app for Fix Build, by path: Product's `name`
/// renamed `title` (breaking its three callers), the cart's total typed
/// `int`, and the tile's import of Product removed.
const Map<String, List<(String, String)>> _breakage = {
  'lib/models/product.dart': [
    ('required this.name', 'required this.title'),
    ('final String name;', 'final String title;'),
  ],
  'lib/services/cart.dart': [('double get total', 'int get total')],
  'lib/widgets/product_tile.dart': [
    ("import 'package:shop/models/product.dart';\n", ''),
  ],
};

/// ProductTile's file, which the renameFile task misspells.
const String _tilePath = 'lib/widgets/product_tile.dart';

/// [_tilePath] misspelled, as the renameFile task names it.
const String _misspeltTilePath = 'lib/widgets/prodcut_tile.dart';

/// What a task's run left: the agent's reply and the project it changed.
typedef _Outcome = ({String reply, String root, List<String> errors});

/// A benchmark task: what it asks the [agent] and whether its [outcome]
/// is right, null when it is, else why not; a question about a large
/// project gives its [project] folder, read in place, instead of the app.
typedef _Task = ({
  String name,
  String? project,
  Future<String> Function(CodeEditAgent agent, String root) run,
  String? Function(_Outcome outcome) check,
});

/// One run of a task: whether it passed, why not, its steps and time.
typedef _Run = ({bool passed, String? failure, int steps, Duration took});

/// The text of the file at [path] in the project at [root].
String _read(String root, String path) =>
    File(p.join(root, path)).readAsStringSync();

/// The benchmark's tasks, after the reference timings in AGENTS.md.
final List<_Task> _tasks = [
  (
    name: 'arithmetic',
    project: null,
    run: (agent, _) => agent.answer('2+2=', const []),
    check: (outcome) =>
        outcome.reply.contains('4') ? null : 'no 4 in: ${outcome.reply}',
  ),
  (
    name: 'question',
    project: null,
    run: (agent, _) => agent.answer(
      'What does HomeScreen show when there are no products?',
      const [],
    ),
    check: (outcome) =>
        outcome.reply.toLowerCase().contains(_emptyText.toLowerCase())
        ? null
        : 'missed "$_emptyText": ${outcome.reply}',
  ),
  (
    name: 'largeQuestion',
    project: Directory.current.path,
    run: (agent, _) => agent.answer(
      'Which class runs dart analyze on a project, and in which file?',
      const [],
    ),
    check: (outcome) =>
        outcome.reply.contains('DartAnalyzer') &&
            outcome.reply.contains('dart_analyzer.dart')
        ? null
        : 'missed DartAnalyzer: ${outcome.reply}',
  ),
  (
    name: 'rename',
    project: null,
    run: (agent, _) => agent.edit(
      'Rename the method _addSample to _addSampleProduct in '
      'lib/screens/home_screen.dart',
      const [],
    ),
    check: (outcome) {
      final code = _read(outcome.root, 'lib/screens/home_screen.dart');
      if (RegExp(r'_addSample\b').hasMatch(code)) return '_addSample left';
      if (!code.contains('_addSampleProduct')) return 'no _addSampleProduct';
      return outcome.errors.isEmpty ? null : outcome.errors.join('; ');
    },
  ),
  (
    name: 'renameFile',
    project: null,
    run: (agent, root) {
      File(p.join(root, _tilePath)).renameSync(p.join(root, _misspeltTilePath));
      final home = File(p.join(root, 'lib/screens/home_screen.dart'));
      home.writeAsStringSync(
        home.readAsStringSync().replaceFirst(
          p.posix.basename(_tilePath),
          p.posix.basename(_misspeltTilePath),
        ),
      );
      // As the user asked after the agent found the typo
      return agent.edit('fix it', [
        ModelMessage.user('find one typo in a file name'),
        ModelMessage.of(
          ModelMessage.assistantRole,
          'The file $_misspeltTilePath is misspelled: it should be '
          '$_tilePath.',
        ),
      ]);
    },
    check: (outcome) {
      if (!File(p.join(outcome.root, _tilePath)).existsSync()) {
        return 'no $_tilePath';
      }
      if (File(p.join(outcome.root, _misspeltTilePath)).existsSync()) {
        return '$_misspeltTilePath left';
      }
      if (!_read(outcome.root, _tilePath).contains('class ProductTile ')) {
        return 'ProductTile changed';
      }
      return outcome.errors.isEmpty ? null : outcome.errors.join('; ');
    },
  ),
  (
    name: 'copyWith',
    project: null,
    run: (agent, _) =>
        agent.edit('Add a copyWith method to the Product class', const []),
    check: (outcome) {
      final code = _read(outcome.root, 'lib/models/product.dart');
      if (!code.contains('copyWith')) return 'no copyWith';
      if (!code.contains('final String name;')) return 'fields changed';
      return outcome.errors.isEmpty ? null : outcome.errors.join('; ');
    },
  ),
  (
    name: 'feature',
    project: null,
    run: (agent, _) => agent.edit(
      'Add a button to ProductTile that removes its product from the cart, '
      'and make HomeScreen remove it when pressed',
      const [],
    ),
    check: (outcome) {
      final tile = _read(outcome.root, 'lib/widgets/product_tile.dart');
      final home = _read(outcome.root, 'lib/screens/home_screen.dart');
      if (!tile.contains('onAdd')) return 'add button removed';
      if (!RegExp(r'VoidCallback\??\s+on\w*Remove').hasMatch(tile)) {
        return 'no remove callback in ProductTile';
      }
      if (!home.contains('_cart.remove(')) return 'HomeScreen never removes';
      return outcome.errors.isEmpty ? null : outcome.errors.join('; ');
    },
  ),
  (
    name: 'fixBuild',
    project: null,
    run: (agent, root) async {
      for (final MapEntry(key: path, value: edits) in _breakage.entries) {
        var code = _read(root, path);
        for (final (from, to) in edits) {
          code = code.replaceFirst(from, to);
        }
        File(p.join(root, path)).writeAsStringSync(code);
      }
      return agent.fixBuild((await _errorsOf(root)).join('\n'), '');
    },
    check: (outcome) {
      final tile = _read(outcome.root, 'lib/widgets/product_tile.dart');
      if (!tile.contains('Text(product.')) return 'tile shows no product';
      if (!_read(outcome.root, 'lib/services/cart.dart').contains('total')) {
        return 'cart total removed';
      }
      return outcome.errors.isEmpty ? null : outcome.errors.join('; ');
    },
  ),
];

/// The compile errors `dart analyze` finds in the project at [root], as
/// the AI panel gives them to the agent.
Future<List<String>> _errorsOf(String root) async {
  final analysis = await const DartAnalyzer(ProcessRunner()).analyze(root);
  return [
    for (final diagnostic in analysis.diagnostics)
      if (diagnostic.tone == StatusTone.error)
        '${p.relative(diagnostic.path, from: root)}:${diagnostic.line}: '
            '${diagnostic.message}',
  ];
}

/// Copies the folder [from] into the new folder [to].
void _copy(String from, String to) {
  for (final entity in Directory(from).listSync(recursive: true)) {
    final target = p.join(to, p.relative(entity.path, from: from));
    if (entity is File) {
      File(target).parent.createSync(recursive: true);
      entity.copySync(target);
    }
  }
}

/// Median of [values], which must not be empty.
Duration _median(List<Duration> values) {
  final sorted = [...values]..sort();
  return sorted[sorted.length ~/ 2];
}

void main() {
  test(
    'the local model carries out the reference tasks',
    () async {
      final base = Directory.systemTemp.createTempSync('fide_bench_app');
      addTearDown(() => base.deleteSync(recursive: true));
      for (final MapEntry(key: path, value: code) in _app.entries) {
        File(p.join(base.path, path))
          ..parent.createSync(recursive: true)
          ..writeAsStringSync(code);
      }
      final pubGet = await Process.run('flutter', [
        'pub',
        'get',
        '--offline',
      ], workingDirectory: base.path);
      expect(pubGet.exitCode, 0, reason: '${pubGet.stderr}');
      expect(await _errorsOf(base.path), isEmpty);

      final client = http.Client();
      addTearDown(client.close);
      final model = OllamaClient(client, preferred: _model);
      expect(await model.resolveModel(), startsWith(_model));
      final load = Stopwatch()..start();
      await model.warmUp();
      print('${model.model}: loaded in ${load.elapsed.inMilliseconds} ms');

      final results = <String, List<_Run>>{};
      for (final task in _tasks) {
        if (_only != null && !_only!.contains(task.name)) continue;
        for (var run = 0; run < _runs!; run++) {
          final root = Directory.systemTemp.createTempSync('fide_bench_run');
          _copy(base.path, root.path);
          var steps = 0;
          // The AI panel's rename, the project tree's
          final container = ProviderContainer();
          container.read(currentProjectPathProvider.notifier).state = root.path;
          final agent = CodeEditAgent(
            model,
            files: ProjectFileStore(task.project ?? root.path),
            hooks: CodeEditHooks(
              onStep: (_) => steps++,
              onFileWritten: (_) async {},
              checkBuild: () async => (await _errorsOf(root.path)).join('\n'),
              renameFile: (from, to) async => (await renameInProject(
                container.read,
                from,
                to,
                isDirectory: FileSystemEntity.isDirectorySync(from),
              )).keys,
            ),
          );
          final watch = Stopwatch()..start();
          String? failure;
          try {
            final reply = await task.run(agent, root.path);
            final took = watch.elapsed;
            failure = task.check((
              reply: reply,
              root: root.path,
              errors: await _errorsOf(root.path),
            ));
            results.putIfAbsent(task.name, () => []).add((
              passed: failure == null,
              failure: failure,
              steps: steps,
              took: took,
            ));
          } on Exception catch (e) {
            failure = '$e';
            results.putIfAbsent(task.name, () => []).add((
              passed: false,
              failure: failure,
              steps: steps,
              took: watch.elapsed,
            ));
          } finally {
            container.dispose();
            root.deleteSync(recursive: true);
          }
          print(
            '  ${task.name} #${run + 1}: ${failure == null ? 'pass' : 'FAIL'}'
            ', $steps steps, ${watch.elapsed.inMilliseconds} ms'
            '${failure == null ? '' : ' — ${failure.split('\n').first}'}',
          );
        }
      }
      print('\n${model.model}, $_runs runs each');
      for (final MapEntry(key: name, value: runs) in results.entries) {
        final passed = runs.where((run) => run.passed).length;
        final steps = runs.map((run) => run.steps).reduce((a, b) => a + b);
        print(
          '  BENCH ${model.model} $name: $passed/${runs.length} passed, '
          '${(steps / runs.length).toStringAsFixed(1)} steps, median '
          '${(_median([for (final run in runs) run.took]).inMilliseconds / Duration.millisecondsPerSecond).toStringAsFixed(1)} s',
        );
      }
    },
    skip: _runs == null
        ? 'set FIDE_AI_BENCH to the runs of each task on the local Ollama '
              'model, FIDE_AI_MODEL to the model'
        : null,
    timeout: Timeout.none,
  );
}
