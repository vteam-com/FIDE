import 'dart:io';

import 'package:fide/models/flutter_platform.dart';
import 'package:fide/services/project_config_reader.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  const reader = ProjectConfigReader();
  late Directory project;

  setUp(() {
    project = Directory.systemTemp.createTempSync('fide_config_');
  });

  tearDown(() => project.deleteSync(recursive: true));

  void write(String name, String content) =>
      File(p.join(project.path, name)).writeAsStringSync(content);

  test('platforms lists only platforms with a project folder', () {
    Directory(p.join(project.path, 'android')).createSync();
    Directory(p.join(project.path, 'web')).createSync();

    expect(reader.platforms(project.path), {
      FlutterPlatform.android,
      FlutterPlatform.web,
    });
  });

  test('pubspec and packageName are null without a pubspec', () async {
    expect(await reader.pubspec(project.path), isNull);
    expect(await reader.packageName(project.path), isNull);
  });

  test('pubspec parses the project pubspec', () async {
    write('pubspec.yaml', 'name: demo\nflutter:\n  generate: true\n');

    final pubspec = await reader.pubspec(project.path);

    expect(pubspec?.name, 'demo');
    expect(pubspec?.generatesLocalizations, isTrue);
    expect(await reader.packageName(project.path), 'demo');
  });

  test('l10nConfig is the default without an l10n.yaml', () async {
    final config = await reader.l10nConfig(project.path);

    expect(config.arbDir, 'lib/l10n');
    expect(config.outputClass, 'AppLocalizations');
  });

  test('l10nConfig reads the l10n.yaml settings', () async {
    write('l10n.yaml', 'arb-dir: lib/i18n\noutput-class: Strings\n');

    final config = await reader.l10nConfig(project.path);

    expect(config.arbDir, 'lib/i18n');
    expect(config.outputClass, 'Strings');
    expect(config.templateArbFile, 'app_en.arb');
  });

  test('l10nConfig is the default for an invalid l10n.yaml', () async {
    write('l10n.yaml', 'arb-dir: [unclosed');

    expect((await reader.l10nConfig(project.path)).arbDir, 'lib/l10n');
  });
}
