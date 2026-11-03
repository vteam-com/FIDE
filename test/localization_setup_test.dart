import 'dart:convert';
import 'dart:io';

import 'package:fide/services/l10n_generator.dart';
import 'package:fide/services/localization_setup.dart';
import 'package:fide/services/process_runner.dart';
import 'package:fide/services/project_config_reader.dart';
import 'package:flutter_test/flutter_test.dart';

// Fails the commands whose joined text is in [failing]; succeeds otherwise
class FakeFlutterRunner extends ProcessRunner {
  final Set<String> failing;
  final List<String> commands = [];

  FakeFlutterRunner({this.failing = const {}});

  @override
  Future<ProcessResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    bool runInShell = false,
  }) async {
    final command = [executable, ...arguments].join(' ');
    commands.add(command);
    return failing.contains(command)
        ? ProcessResult(0, 1, '', 'offline')
        : ProcessResult(0, 0, '', '');
  }
}

void main() {
  late Directory project;

  setUp(() {
    project = Directory.systemTemp.createTempSync('fide_l10n_');
    File('${project.path}/pubspec.yaml').writeAsStringSync(
      'name: demo\ndependencies:\n  flutter:\n    sdk: flutter\nflutter:\n  uses-material-design: true\n',
    );
    Directory('${project.path}/lib').createSync();
    File('${project.path}/lib/main.dart').writeAsStringSync(
      'void main() => runApp(MaterialApp(title: "Demo \\"App\\""));\n',
    );
  });

  tearDown(() => project.deleteSync(recursive: true));

  /// A setup running every tool through [runner].
  LocalizationSetup setupWith(FakeFlutterRunner runner) => LocalizationSetup(
    runner,
    const ProjectConfigReader(),
    L10nGenerator(runner),
  );

  test('generateClasses runs gen-l10n and throws with its stderr', () async {
    final runner = FakeFlutterRunner();
    await L10nGenerator(runner).generateClasses(project.path);
    expect(runner.commands, ['flutter gen-l10n']);

    await expectLater(
      L10nGenerator(FakeFlutterRunner(failing: {'flutter gen-l10n'}))
          .generateClasses(project.path),
      throwsA(
        isA<Exception>().having((e) => '$e', 'message', contains('offline')),
      ),
    );
  });

  test(
    'initializeLocalization reports each step and writes templates',
    () async {
      final runner = FakeFlutterRunner();
      final steps = <String>[];

      await setupWith(runner)
          .initializeLocalization(project.path, onStep: steps.add);

      expect(steps, hasLength(4));
      expect(runner.commands, [
        'flutter pub add flutter_localizations --sdk=flutter',
        'flutter pub add intl',
        'flutter gen-l10n',
      ]);
      final english = jsonDecode(
        File('${project.path}/lib/l10n/app_en.arb').readAsStringSync(),
      ) as Map<String, dynamic>;
      // AST extraction handles double quotes and escapes, unlike a regex
      expect(english['appTitle'], 'Demo "App"');
      expect(
        File('${project.path}/pubspec.yaml').readAsStringSync(),
        contains('generate: true'),
      );
    },
  );

  test('strict mode stops at the first failing tool', () async {
    final runner = FakeFlutterRunner(failing: {'flutter pub add intl'});

    await expectLater(
      setupWith(runner).initializeLocalization(project.path),
      throwsA(isA<Exception>()),
    );
    expect(Directory('${project.path}/lib/l10n').existsSync(), false);
  });

  test('tolerant mode logs tool failures and finishes setup', () async {
    final runner = FakeFlutterRunner(
      failing: {'flutter pub add intl', 'flutter gen-l10n'},
    );

    await setupWith(runner)
        .initializeLocalization(project.path, tolerateToolFailures: true);

    expect(File('${project.path}/lib/l10n/app_fr.arb').existsSync(), true);
  });

  for (final (label, pubspec) in [
    ('empty', 'name: demo\nflutter:\n'),
    ('missing', 'name: demo\n'),
  ]) {
    test('enables generate when the flutter section is $label', () async {
      File('${project.path}/pubspec.yaml').writeAsStringSync(pubspec);

      await setupWith(FakeFlutterRunner()).initializeLocalization(project.path);

      final service = setupWith(FakeFlutterRunner());
      expect((await service.inspect(project.path)).hasGenerateFlag, true);
    });
  }

  test('inspect reports what the project already has', () async {
    final service = setupWith(FakeFlutterRunner());

    final before = await service.inspect(project.path);
    expect(before.isFlutterProject, true);
    expect(before.hasArbFiles, false);
    expect(before.hasGenerateFlag, false);

    await service.initializeLocalization(project.path);
    final after = await service.inspect(project.path);
    expect(after.hasArbFiles, true);
    expect(after.hasGenerateFlag, true);
  });
}
