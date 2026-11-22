import 'dart:convert';
import 'dart:io';

import 'package:fide/services/arb_service.dart';
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
    Map<String, String> environment = const {},
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

  test('wires the app widget built outside main.dart', () async {
    final main = File('${project.path}/lib/main.dart')
      ..writeAsStringSync(
        "import 'package:demo/app.dart';\n\nvoid main() => runApp(App());\n",
      );
    final app = File('${project.path}/lib/app.dart')
      ..writeAsStringSync(
        "Widget build() => MaterialApp.router(title: 'Demo');\n",
      );
    final service = setupWith(FakeFlutterRunner());

    expect((await service.inspect(project.path)).hasAppIntegration, false);
    expect(await service.wireApp(project.path), 'lib/app.dart');
    expect((await service.inspect(project.path)).hasAppIntegration, true);
    expect(main.readAsStringSync(), isNot(contains('l10n')));
    // No template ARB file with a title to look up
    expect(app.readAsStringSync(), contains("title: 'Demo'"));
    expect(
      app.readAsStringSync(),
      contains("import 'package:demo/l10n/app_localizations.dart';"),
    );
  });

  test('wiring fails without an app widget', () async {
    File('${project.path}/lib/main.dart').writeAsStringSync('void main() {}\n');

    await expectLater(
      setupWith(FakeFlutterRunner()).wireApp(project.path),
      throwsA(isA<Exception>()),
    );
  });

  test('initializeLocalization writes only the locales asked for', () async {
    await setupWith(FakeFlutterRunner())
        .initializeLocalization(project.path, locales: {'en', 'de'});

    final l10n = '${project.path}/lib/l10n';
    expect(File('$l10n/app_en.arb').existsSync(), true);
    expect(File('$l10n/app_fr.arb').existsSync(), false);
    final german = ArbService.decode(
      File('$l10n/app_de.arb').readAsStringSync(),
    );
    expect(german, {ArbService.localeKey: 'de'});
  });

  group('locales', () {
    late String l10n;

    /// Writes the ARB file of [locale], with one message.
    void arb(String locale) =>
        File('$l10n/app_$locale.arb').writeAsStringSync('{"hi": "Hi"}');

    setUp(() {
      l10n = '${project.path}/lib/l10n';
      Directory(l10n).createSync(recursive: true);
      arb('en');
    });

    test('adding one writes its ARB file without regenerating yet', () async {
      final runner = FakeFlutterRunner();

      final path = await setupWith(runner).addLocale(project.path, 'de');

      expect(path, '$l10n/app_de.arb');
      expect(ArbService.decode(File(path).readAsStringSync()), {
        ArbService.localeKey: 'de',
      });
      // No generated classes yet: the next build generates them
      expect(runner.commands, isEmpty);
      await expectLater(
        setupWith(runner).addLocale(project.path, 'de'),
        throwsA(isA<Exception>()),
      );
    });

    test('adding one regenerates the generated classes', () async {
      File('$l10n/app_localizations.dart').writeAsStringSync('');
      final runner = FakeFlutterRunner();

      await setupWith(runner).addLocale(project.path, 'de');

      expect(runner.commands, ['flutter gen-l10n']);
    });

    test('removing one deletes its ARB and leftover generated files', () async {
      arb('de');
      arb('pt');
      arb('pt_BR');
      File('$l10n/app_localizations.dart').writeAsStringSync('');
      final german = File('$l10n/app_localizations_de.dart')
        ..writeAsStringSync('');
      final portuguese = File('$l10n/app_localizations_pt.dart')
        ..writeAsStringSync('');
      final runner = FakeFlutterRunner();
      final setup = setupWith(runner);

      expect(await setup.removeLocale(project.path, 'de'), '$l10n/app_de.arb');
      expect(File('$l10n/app_de.arb').existsSync(), false);
      expect(german.existsSync(), false);
      expect(runner.commands, ['flutter gen-l10n']);

      // pt_BR falls back to pt, whose generated file pt_BR's class shares
      await expectLater(
        setup.removeLocale(project.path, 'pt'),
        throwsA(
          isA<Exception>().having((e) => '$e', 'message', contains('pt_BR')),
        ),
      );
      await setup.removeLocale(project.path, 'pt_BR');
      expect(portuguese.existsSync(), true);
    });

    test('the template locale cannot be removed', () async {
      await expectLater(
        setupWith(FakeFlutterRunner()).removeLocale(project.path, 'en'),
        throwsA(isA<Exception>()),
      );
      expect(File('$l10n/app_en.arb').existsSync(), true);
    });
  });

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
