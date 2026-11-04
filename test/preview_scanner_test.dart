import 'package:fide/services/preview_scanner.dart';
import 'package:flutter_test/flutter_test.dart';

const String _source = '''
import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart' as wp;
import 'src/model.dart' if (dart.library.io) 'src/model_io.dart';

enum Mood { happy, sad }

class Greeting extends StatelessWidget {
  const Greeting({super.key, required this.title, this.subtitle, required this.mood});

  final String title;
  final String? subtitle;
  final Mood mood;

  @wp.Preview(name: 'Constructor')
  const Greeting.preview({super.key}) : title = 'Hi', subtitle = null, mood = Mood.happy;

  @wp.Preview(name: 'Static')
  static Widget staticPreview() => const Greeting.preview();

  @override
  Widget build(BuildContext context) => Text(title);
}

class Plain extends StatelessWidget {
  const Plain({super.key});
  @override
  Widget build(BuildContext context) => const SizedBox();
}

class _Private extends StatelessWidget {
  const _Private();
  @override
  Widget build(BuildContext context) => const SizedBox();
}

@BrightnessPreview()
@wp.Preview(group: 'Brightness')
@override
Widget greetingPreview() => const Greeting.preview();

@wp.Preview()
Widget needsArgument(String text) => Text(text);

@wp.Preview()
Widget _hidden() => const SizedBox();

@wp.Preview(wrapper: _wrap)
Widget privateWrapper() => const SizedBox();
''';

void main() {
  final scan = const PreviewScanner().scan(_source);

  test('finds the callable preview declarations in file order', () {
    expect(scan.previews.map((d) => d.label), [
      'Greeting.preview',
      'Greeting.staticPreview',
      'greetingPreview',
    ]);
    expect(scan.previews.map((d) => d.invocation), [
      'Greeting.preview()',
      'Greeting.staticPreview()',
      'greetingPreview()',
    ]);
  });

  test('keeps only preview annotations, as constant expressions', () {
    expect(scan.previews.last.annotations.map((a) => a.constant), [
      'const BrightnessPreview()',
      "const wp.Preview(group: 'Brightness')",
    ]);
  });

  test(
    'records the 1-based line of each declaration, from its annotations',
    () {
      expect(scan.previews.first.line, 14);
    },
  );

  test('lists public widget classes with their constructor', () {
    expect(scan.widgets.map((w) => w.name), ['Greeting', 'Plain']);
    final greeting = scan.widgets.first;
    expect(greeting.constructorName, isEmpty);
    expect(greeting.isConstConstructor, isTrue);
    expect(greeting.requiredParameters.map((p) => '${p.name}: ${p.type}'), [
      'title: String',
      'mood: Mood',
    ]);
    expect(greeting.parameters[2].isNullable, isTrue);
  });

  test('tells the widgets no preview builds', () {
    expect(scan.widgetsWithoutPreview.map((w) => w.name), ['Plain']);
  });

  test('keeps imports with the offsets of each URI', () {
    expect(scan.imports.map((i) => i.uri), [
      'package:flutter/material.dart',
      'package:flutter/widget_previews.dart',
      'src/model.dart',
    ]);
    final conditional = scan.imports.last;
    expect(
      conditional.rewritten((uri) => 'package:app/$uri'),
      "import 'package:app/src/model.dart' "
      "if (dart.library.io) 'package:app/src/model_io.dart';",
    );
  });

  test('records enums and top-level names', () {
    expect(scan.enumFirstValues, {'Mood': 'Mood.happy'});
    expect(scan.topLevelNames, containsAll(['Greeting', 'greetingPreview']));
  });

  test('tells a part file', () {
    expect(const PreviewScanner().scan("part of 'a.dart';").isPart, isTrue);
    expect(scan.isPart, isFalse);
  });
}
