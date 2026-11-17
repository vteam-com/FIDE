import 'dart:io';

import 'package:fide/models/localization_checks.dart';
import 'package:fide/models/project_paths.dart';
import 'package:fide/services/arb_service.dart';
import 'package:fide/services/flutter_sdk.dart';
import 'package:fide/services/l10n_generator.dart';
import 'package:fide/services/main_dart_localizer.dart';
import 'package:fide/services/process_runner.dart';
import 'package:fide/services/project_config_reader.dart';
import 'package:logging/logging.dart';
import 'package:yaml/yaml.dart';
import 'package:yaml_edit/yaml_edit.dart';

/// Sets a project's localization up: adds the packages, enables code
/// generation, writes template ARB files, wires `main.dart` (rewritten by
/// [MainDartLocalizer]) and reports which of those pieces a project
/// already has.
class LocalizationSetup {
  static final Logger _logger = Logger('LocalizationSetup');

  /// Package name assumed when the pubspec has none.
  static const String _fallbackPackageName = 'my_app';

  final ProcessRunner _runner;

  final ProjectConfigReader _config;

  final L10nGenerator _generator;

  /// Creates a setup that launches `flutter pub` through [_runner], reads
  /// project settings with [_config] and generates classes with
  /// [_generator].
  const LocalizationSetup(this._runner, this._config, this._generator);

  /// Sets up localization: adds `flutter_localizations` and `intl`, enables
  /// code generation, writes template ARB files and generates classes.
  ///
  /// [onStep] is told about each step before it runs. Tool failures throw
  /// unless [tolerateToolFailures] is set, in which case they are logged and
  /// setup continues, so creating a project doesn't fail when pub is offline.
  Future<void> initializeLocalization(
    String projectPath, {
    ProcessOutputCallback? onStep,
    bool tolerateToolFailures = false,
  }) async {
    Future<void> runTool(Future<void> Function() tool) async {
      try {
        await tool();
      } catch (e) {
        if (!tolerateToolFailures) rethrow;
        _logger.warning('$e');
      }
    }

    onStep?.call('Adding flutter_localizations and intl packages...');
    await runTool(
      () => _addPackage(projectPath, 'flutter_localizations', sdk: 'flutter'),
    );
    await runTool(() => _addPackage(projectPath, 'intl'));

    onStep?.call('Configuring pubspec.yaml...');
    await _enableGenerate(projectPath);

    onStep?.call('Creating template ARB files...');
    await _createTemplateArbFiles(projectPath);

    onStep?.call('Generating localization classes...');
    await runTool(() => _generator.generateClasses(projectPath));
  }

  /// Reads which localization pieces the project at [projectPath] has.
  Future<LocalizationChecks> inspect(String projectPath) async {
    final pubspec = await _config.pubspec(projectPath);
    final config = await _config.l10nConfig(projectPath);
    final mainDart = await ProjectConfigReader.readIfExists(
      ProjectPaths(projectPath).mainDart,
    );
    final hasArbFiles = (await ArbService.arbFilesIn(
      config.arbDirIn(projectPath),
    )).isNotEmpty;

    return LocalizationChecks(
      hasPubspec: pubspec != null,
      isFlutterProject: pubspec?.isFlutter ?? false,
      hasArbFiles: hasArbFiles,
      hasGeneratedClasses: await File(config.generatedPathIn(projectPath))
          .exists(),
      hasAppIntegration:
          mainDart != null && MainDartLocalizer.isLocalized(mainDart),
      hasDependencies:
          pubspec != null &&
          pubspec.dependsOn('flutter_localizations') &&
          pubspec.dependsOn('intl'),
      hasGenerateFlag: pubspec?.generatesLocalizations ?? false,
    );
  }

  /// Updates `main.dart` to wire generated localization delegates and title lookup.
  Future<void> updateMainDartForLocalization(String projectPath) async {
    final paths = ProjectPaths(projectPath);
    final mainFile = File(paths.mainDart);
    if (!await mainFile.exists()) {
      throw Exception('main.dart not found in project');
    }

    final packageName =
        await _config.packageName(projectPath) ?? _fallbackPackageName;
    final config = await _config.l10nConfig(projectPath);
    await mainFile.writeAsString(
      MainDartLocalizer.localize(
        await mainFile.readAsString(),
        importUri: config.importUri(packageName),
      ),
    );
  }

  /// Writes English and French template ARB files into the project's ARB
  /// folder, using the app title from `main.dart` when one is set.
  Future<void> _createTemplateArbFiles(String projectPath) async {
    final config = await _config.l10nConfig(projectPath);
    await Directory(config.arbDirIn(projectPath)).create(recursive: true);

    final mainDart = await ProjectConfigReader.readIfExists(
      ProjectPaths(projectPath).mainDart,
    );
    final extractedTitle = mainDart == null
        ? null
        : MainDartLocalizer.appTitle(mainDart);
    final appTitle = extractedTitle == null || extractedTitle.isEmpty
        ? MainDartLocalizer.defaultTitle
        : extractedTitle;

    for (final (locale, title, greeting) in [
      ('en', appTitle, 'Hello World'),
      ('fr', 'Mon Application', 'Bonjour le monde'),
    ]) {
      await ArbService.write(config.arbPathFor(projectPath, locale), {
        ArbService.localeKey: locale,
        'appTitle': title,
        '@appTitle': {'description': 'The title of the application'},
        'helloWorld': greeting,
        '@helloWorld': {'description': 'A greeting message'},
      });
    }
  }

  /// Turns on `flutter: generate: true` in the project's pubspec, creating
  /// the `flutter:` section when it is missing or empty.
  Future<void> _enableGenerate(String projectPath) async {
    final pubspecFile = File(ProjectPaths(projectPath).pubspec);
    if (!await pubspecFile.exists()) return;

    final editor = YamlEditor(await pubspecFile.readAsString());
    final flutterSection = editor.parseAt([
      'flutter',
    ], orElse: () => wrapAsYamlNode(null));
    if (flutterSection is YamlMap) {
      editor.update(['flutter', 'generate'], true);
    } else {
      editor.update(['flutter'], {'generate': true});
    }
    await pubspecFile.writeAsString(editor.toString());
  }

  /// Adds [package] to the project with `flutter pub add`, from [sdk] when
  /// it is an SDK package, throwing with the tool's stderr on failure.
  Future<void> _addPackage(
    String projectPath,
    String package, {
    String? sdk,
  }) async {
    await _runner.runChecked(
      FlutterSdk.executable,
      ['pub', 'add', package, if (sdk != null) '--sdk=$sdk'],
      workingDirectory: projectPath,
      error: (result) => Exception('Failed to add $package: ${result.stderr}'),
    );
  }
}
