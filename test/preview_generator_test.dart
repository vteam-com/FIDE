import 'package:fide/models/dart_package_config.dart';
import 'package:fide/services/preview_generator.dart';
import 'package:fide/services/preview_type_resolver.dart';
import 'package:flutter_test/flutter_test.dart';

/// The project's `lib` folder.
const String _lib = '/work/app/lib';

/// The file the previews are generated in.
const String _path = '$_lib/widget.dart';

/// The project's packages: its own, a package of widgets, and Flutter's.
const DartPackageConfig _packages = DartPackageConfig(
  libFolders: {
    'app': _lib,
    'kit': '/cache/kit/lib',
    'flutter': '/sdk/packages/flutter/lib',
  },
  flutterRoot: '/sdk',
);

/// Generates the previews of [content], the project's other files being
/// [files], by path.
PreviewGeneration _generate(
  String content, {
  Map<String, String> files = const {},
}) {
  final resolver = PreviewTypeResolver(
    packages: _packages,
    projectFiles: [
      for (final path in files.keys)
        if (path.startsWith(_lib)) path,
    ]..sort(),
    contents: {...files, _path: content},
  );
  return const PreviewGenerator().generate(_path, resolver);
}

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

  test("builds the project's classes, importing the ones it needs", () {
    const content = '''
import 'package:app/practice/controller.dart';
import 'package:flutter/widgets.dart';

class PracticeScreen extends StatelessWidget {
  const PracticeScreen({super.key, required this.controller});
  final PracticeController controller;
  @override
  Widget build(BuildContext context) => const SizedBox();
}
''';
    final generation = _generate(
      content,
      files: {
        '$_lib/practice/controller.dart': '''
import 'package:flutter/foundation.dart';
import '../audio/voice.dart';

class PracticeController extends ChangeNotifier {
  PracticeController({required this.voice, this.speed = 1});
  final Voice voice;
  final double speed;
}
''',
        '$_lib/audio/voice.dart': '''
part 'voice.mode.dart';

class Voice {
  const Voice(this.name, {required this.mode});
  final String name;
  final VoiceMode mode;
}
''',
        '$_lib/audio/voice.mode.dart': '''
part of 'voice.dart';

enum VoiceMode { calm, fast }
''',
      },
    );
    expect(generation.skipped, isEmpty);
    expect(
      generation.content,
      contains(
        'Widget practiceScreenPreview() => PracticeScreen(controller: '
        "PracticeController(voice: const Voice('Name', mode: "
        'VoiceMode.calm)));',
      ),
    );
    expect(
      generation.content,
      contains(
        "import 'package:app/audio/voice.dart';\n"
        "import 'package:app/practice/controller.dart';",
      ),
    );
  });

  test('builds a class of the project for an abstract one', () {
    const content = '''
import 'package:flutter/widgets.dart';
import 'package:app/data/repository.dart';

class ItemList extends StatelessWidget {
  const ItemList({super.key, required this.repository, required this.onPick, required this.label});
  final Repository repository;
  final OnPick onPick;
  final String Function(int index) label;
  @override
  Widget build(BuildContext context) => const SizedBox();
}
''';
    final generation = _generate(
      content,
      files: {
        '$_lib/data/repository.dart': '''
abstract class Repository {
  List<String> load();
}

typedef OnPick = void Function(String id, int index);
''',
        '$_lib/data/memory_repository.dart': '''
import 'repository.dart';

class MemoryRepository implements Repository {
  @override
  List<String> load() => const [];
}
''',
      },
    );
    expect(
      generation.content,
      contains(
        'Widget itemListPreview() => ItemList(repository: '
        "MemoryRepository(), onPick: (_, __) {}, label: (_) => 'Label');",
      ),
    );
    expect(
      generation.content,
      contains("import 'package:app/data/memory_repository.dart';"),
    );
  });

  test('uses the colors and icons a package exports, and fills lists', () {
    const content = '''
import 'package:kit/kit.dart';

class Tile extends StatelessWidget {
  const Tile({super.key, required this.color, required this.icon, required this.tags, required this.children});
  final Color color;
  final IconData icon;
  final List<String> tags;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => const SizedBox();
}
''';
    final generation = _generate(
      content,
      files: {
        '/cache/kit/lib/kit.dart': '''
export 'package:flutter/widgets.dart';
export 'src/colors.dart' show Colors, Icons;
''',
        '/cache/kit/lib/src/colors.dart': '''
class Colors {}
class Icons {}
''',
      },
    );
    expect(
      generation.content,
      contains(
        'Widget tilePreview() => const Tile(color: Colors.blue, '
        "icon: Icons.star, tags: ['Tags'], children: [Placeholder()]);",
      ),
    );
    expect(generation.content, isNot(contains('material.dart')));
  });

  test("names the type it can't build, and skips previewed widgets", () {
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
    expect(generation.skipped, [(widget: 'UserCard', type: 'User')]);
    expect(generation.content, content);
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
