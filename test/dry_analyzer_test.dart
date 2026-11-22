import 'dart:io';

import 'package:fide/models/dry_review.dart';
import 'package:fide/services/dry_analyzer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// A stand-in for the Flutter classes the analyzer recognizes by name.
const String _framework = '''
class Widget { const Widget(); }
class BuildContext {}
abstract class StatelessWidget extends Widget {
  const StatelessWidget();
  Widget build(BuildContext context);
}
class Color { const Color(this.value); final int value; }
class IconData { const IconData(this.codePoint); final int codePoint; }
enum TextOverflow { clip, ellipsis }
class TextStyle { const TextStyle(); }
class Text extends Widget {
  const Text(this.data, {this.maxLines, this.overflow, this.style});
  final String data;
  final int? maxLines;
  final TextOverflow? overflow;
  final TextStyle? style;
}
class Icon extends Widget {
  const Icon(this.icon, {this.size, this.color});
  final IconData icon;
  final double? size;
  final Color? color;
}
class Padding extends Widget {
  const Padding({this.left, this.right});
  final double? left;
  final double? right;
}
''';

/// The project's design tokens and shared widgets.
const String _tokens = '''
import '../framework.dart';

abstract final class AppIconSize {
  static const double medium = 24;
  static const double large = 32;
}

abstract final class AppStyle {
  static const TextStyle label = TextStyle();
}

enum Tone { info, warning }

class Badge extends Widget {
  const Badge(this.label, {this.tone = Tone.info, this.size});
  final String label;
  final Tone tone;
  final double? size;
}

class Truncated extends StatelessWidget {
  const Truncated(this.text, {this.style});
  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: style, maxLines: 1, overflow: TextOverflow.ellipsis);
  }
}

Color readable(Color color) => color;
''';

/// The package configuration naming the project `demo`.
const String _packageConfig = '''
{
  "configVersion": 2,
  "packages": [
    {"name": "demo", "rootUri": "../", "packageUri": "lib/"}
  ]
}
''';

void main() {
  late String project;

  setUp(() {
    project = Directory.systemTemp
        .createTempSync('fide_dry_')
        .resolveSymbolicLinksSync();
    // A package, so the project's libraries have `package:` URIs
    File(p.join(project, 'pubspec.yaml')).writeAsStringSync('name: demo\n');
    File(p.join(project, '.dart_tool', 'package_config.json'))
      ..createSync(recursive: true)
      ..writeAsStringSync(_packageConfig);
  });
  tearDown(() => Directory(project).deleteSync(recursive: true));

  void write(String path, String content) {
    File(p.join(project, 'lib', path))
      ..createSync(recursive: true)
      ..writeAsStringSync(content);
  }

  Future<DryReview> review() => const DryAnalyzer().review(
    project,
    p.join(Platform.environment['FLUTTER_ROOT']!, 'bin', 'cache', 'dart-sdk'),
  );

  test('finds clones, drifts, shared values and numbers', () async {
    write('framework.dart', _framework);
    write('widgets/tokens.dart', _tokens);
    write('a.dart', '''
import 'framework.dart';
import 'widgets/tokens.dart';

List<Widget> a(IconData icon, Color? color, Color primary) => [
  Text('a', maxLines: 1, overflow: TextOverflow.ellipsis),
  Icon(icon, size: AppIconSize.medium, color: color ?? primary),
  const Padding(left: 4, right: 4),
  const Badge('a', tone: Tone.warning),
  const Badge('b', tone: Tone.warning),
];
''');
    write('b.dart', '''
import 'framework.dart';
import 'widgets/tokens.dart';

List<Widget> b(IconData icon, Color color) => [
  Icon(icon, size: AppIconSize.medium, color: readable(color)),
  Icon(icon, size: 32),
  const Padding(left: 4, right: 4),
  const Badge('c', tone: Tone.warning),
];
''');
    for (final name in ['d', 'e']) {
      write('$name.dart', '''
import 'framework.dart';
import 'widgets/tokens.dart';

const Widget $name = Text(
  '$name',
  style: AppStyle.label,
  maxLines: 1,
  overflow: TextOverflow.ellipsis,
);
''');
    }
    write('c.dart', '''
import 'framework.dart';

const Widget c = Text('c', maxLines: 1, overflow: TextOverflow.ellipsis);
''');

    final found = await review();

    final clones = found.of(DryFindingKind.clone);
    expect(clones, hasLength(2));
    final clone = clones.firstWhere((finding) => finding.locationCount == 3);
    expect(clone.title, 'Text');
    expect(clone.locationCount, 3);
    expect(clone.suggestion, 'Use Truncated (lib/widgets/tokens.dart)');
    // The shared widget's own Text stays; the copies call it
    final useTruncated = clone.fixes.single;
    expect(useTruncated.label, 'Use Truncated');
    expect(useTruncated.edits.map((edit) => edit.replacement), [
      "Truncated('a')",
      "Truncated('c')",
    ]);
    expect(useTruncated.edits.first.importUri, isNull);
    expect(useTruncated.edits.last.importUri, endsWith('widgets/tokens.dart'));

    // A clone fixing a style too passes it to the shared widget
    final styled = clones.firstWhere((finding) => finding.locationCount == 2);
    expect(styled.suggestion, 'Use Truncated (lib/widgets/tokens.dart)');
    expect(styled.fixes.single.edits.map((edit) => edit.replacement), [
      "Truncated('d', style: AppStyle.label)",
      "Truncated('e', style: AppStyle.label)",
    ]);

    final drift = found.of(DryFindingKind.drift).single;
    expect(drift.title, 'Icon · color');
    expect(
      drift.variants.map((variant) => variant.source),
      unorderedEquals(['color ?? primary', 'readable(color)']),
    );

    final shared = found.of(DryFindingKind.sameEverywhere);
    expect(
      shared.map((finding) => finding.title),
      unorderedEquals(['Badge · tone', 'Text · maxLines', 'Text · overflow']),
    );
    expect(
      shared.firstWhere((finding) => finding.widget == 'Badge').suggestion,
      'Make it the default of `tone` in Badge',
    );

    final number = found.of(DryFindingKind.literal).single;
    expect(number.title, 'Number 32');
    expect(number.suggestion, 'Use AppIconSize.large');
    final fixed = number.fixes.single.applyTo({
      'lib/b.dart': File(p.join(project, 'lib', 'b.dart')).readAsStringSync(),
    });
    expect(fixed.count, 1);
    expect(
      fixed.contents['lib/b.dart'],
      contains('Icon(icon, size: AppIconSize.large)'),
    );

    // Layout widgets are never reported, however alike
    expect(
      found.findings.map((finding) => finding.widget),
      isNot(contains('Padding')),
    );
  });

  test('extracts the widget clones build when no shared widget does', () async {
    write('framework.dart', _framework);
    write('widgets/tokens.dart', _tokens);
    for (final name in ['x', 'y']) {
      write('$name.dart', '''
import 'framework.dart';
import 'widgets/tokens.dart';

List<Widget> $name(IconData icon, Color color) => [
  Icon(icon, size: AppIconSize.large, color: readable(color)),
];
''');
    }

    final found = await review();

    final extract = found.of(DryFindingKind.clone).single.fixes.single;
    expect(extract.nameHint, 'LargeIcon');
    final named = extract.named('BigIcon');
    expect(named.created.keys, ['lib/widgets/big_icon.dart']);
    // The shared settings stay; the state each place reads is passed in
    final code = named.created.values.single;
    expect(code, contains("import 'package:demo/framework.dart';"));
    expect(code, contains("import 'package:demo/widgets/tokens.dart';"));
    expect(
      code,
      contains('const BigIcon(this.icon, {super.key, required this.color});'),
    );
    expect(code, contains('final Color? color;'));
    expect(
      code,
      contains('return Icon(icon, size: AppIconSize.large, color: color);'),
    );
    expect(named.edits.map((edit) => edit.replacement), [
      'BigIcon(icon, color: readable(color))',
      'BigIcon(icon, color: readable(color))',
    ]);
    expect(named.edits.first.importUri, 'package:demo/widgets/big_icon.dart');
    expect(found.takenNames, containsAll(['Icon', 'AppIconSize']));
  });

  test('says whether each place is in a view or a widget', () async {
    write('framework.dart', _framework);
    for (final (file, name) in [
      ('home_screen.dart', 'HomeScreen'),
      ('widgets/score_card.dart', 'ScoreCard'),
    ]) {
      write(file, '''
import '${file.contains('/') ? '../' : ''}framework.dart';

class $name extends StatelessWidget {
  const $name();

  @override
  Widget build(BuildContext context) =>
      const Text('$name', maxLines: 1, overflow: TextOverflow.ellipsis);
}
''');
    }

    final found = await review();

    final places = found.of(DryFindingKind.clone).single.variants.single;
    expect(
      {
        for (final location in places.locations)
          location.path: location.isInView,
      },
      {'lib/home_screen.dart': true, 'lib/widgets/score_card.dart': false},
    );
  });

  test('a project without repetition has no finding', () async {
    write('framework.dart', _framework);
    write('a.dart', '''
import 'framework.dart';

const Widget a = Text('a', maxLines: 2);
''');

    final found = await review();

    expect(found.findings, isEmpty);
    expect(found.widgetCount, 1);
  });
}
