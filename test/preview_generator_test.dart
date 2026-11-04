import 'package:fide/services/preview_generator.dart';
import 'package:fide/services/preview_scanner.dart';
import 'package:flutter_test/flutter_test.dart';

PreviewGeneration _generate(String content) => const PreviewGenerator()
    .generate(content, const PreviewScanner().scan(content));

void main() {
  test('previews a widget with sample arguments, as a constant', () {
    const content = '''
import 'package:flutter/material.dart';

enum Size { small, large }

class Badge extends StatelessWidget {
  const Badge({super.key, required this.label, required this.size, required this.child, this.tooltip, required this.color});
  final String label;
  final Size size;
  final Widget child;
  final String? tooltip;
  final Color color;
  @override
  Widget build(BuildContext context) => child;
}
''';
    final generation = _generate(content);
    expect(generation.added, ['badgePreview']);
    expect(generation.skipped, isEmpty);
    expect(
      generation.content,
      contains(
        "@Preview(name: 'Badge')\n"
        "Widget badgePreview() => const Badge(label: 'Label', "
        'size: Size.small, child: Placeholder(), color: Colors.blue);',
      ),
    );
    expect(
      generation.content,
      contains(
        "import 'package:flutter/material.dart';\n"
        "import 'package:flutter/widget_previews.dart';",
      ),
    );
  });

  test('drops const when an argument is a callback', () {
    const content = '''
import 'package:flutter/widgets.dart';

class Toggle extends StatelessWidget {
  const Toggle(this.value, {super.key, required this.onChanged, required this.onTap});
  final bool value;
  final ValueChanged<bool> onChanged;
  final void Function() onTap;
  @override
  Widget build(BuildContext context) => const SizedBox();
}
''';
    expect(
      _generate(content).content,
      contains(
        'Widget togglePreview() => '
        'Toggle(true, onChanged: (_) {}, onTap: () {});',
      ),
    );
  });

  test('skips widgets whose arguments need a model, and existing ones', () {
    const content = '''
import 'package:flutter/widgets.dart';
import 'package:flutter/widget_previews.dart';

class UserCard extends StatelessWidget {
  const UserCard({super.key, required this.user});
  final User user;
  @override
  Widget build(BuildContext context) => const SizedBox();
}

class Done extends StatelessWidget {
  const Done({super.key});
  @override
  Widget build(BuildContext context) => const SizedBox();
}

@Preview()
Widget donePreview() => const Done();
''';
    final generation = _generate(content);
    expect(generation.added, isEmpty);
    expect(generation.skipped.map((w) => w.name), ['UserCard']);
    expect(generation.content, content);
    expect(
      const PreviewGenerator()
          .skippedIn(const PreviewScanner().scan(content))
          .map((w) => w.name),
      ['UserCard'],
    );
  });

  test('names a preview apart from existing declarations', () {
    const content = '''
class Plain extends StatelessWidget {
  const Plain({super.key});
}

void plainPreview() {}
''';
    final generation = _generate(content);
    expect(generation.added, ['plainPreview2']);
    expect(
      generation.content,
      startsWith("import 'package:flutter/widget_previews.dart';\n\nclass"),
    );
  });
}
