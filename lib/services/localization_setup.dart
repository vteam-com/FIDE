import 'dart:io';

import 'package:fide/models/arb_keys.dart';
import 'package:fide/models/arb_message.dart';
import 'package:fide/models/localization_checks.dart';
import 'package:fide/models/project_files.dart';
import 'package:fide/models/project_paths.dart';
import 'package:fide/models/pubspec.dart';
import 'package:fide/services/app_widget_localizer.dart';
import 'package:fide/services/arb_service.dart';
import 'package:fide/services/flutter_sdk.dart';
import 'package:fide/services/l10n_generator.dart';
import 'package:fide/services/process_runner.dart';
import 'package:fide/services/project_config_reader.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';
import 'package:yaml_edit/yaml_edit.dart';

/// A Dart file of a project and its text.
typedef DartSource = ({String path, String content});

/// Sets a project's localization up: adds the packages, enables code
/// generation, writes template ARB files, wires the app widget (rewritten
/// by [AppWidgetLocalizer]) and reports which of those pieces a project
/// already has.
class LocalizationSetup {
  static final Logger _logger = Logger('LocalizationSetup');

  /// Package name assumed when the pubspec has none.
  static const String _fallbackPackageName = 'my_app';

  /// The Flutter SDK package with the localization delegates.
  static const String _localizationsPackage = 'flutter_localizations';

  /// The package formatting localized messages.
  static const String _intlPackage = 'intl';

  /// ARB key of the greeting the template files start with.
  static const String _greetingKey = 'helloWorld';

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

    onStep?.call('Adding flutter_localizations and intl packages…');
    await runTool(
      () => _addPackage(
        projectPath,
        _localizationsPackage,
        sdk: Pubspec.flutterKey,
      ),
    );
    await runTool(() => _addPackage(projectPath, _intlPackage));

    onStep?.call('Configuring pubspec.yaml…');
    await _enableGenerate(projectPath);

    onStep?.call('Creating template ARB files…');
    await _createTemplateArbFiles(projectPath);

    onStep?.call('Generating localization classes…');
    await runTool(() => _generator.generateClasses(projectPath));
  }

  /// Reads which localization pieces the project at [projectPath] has.
  Future<LocalizationChecks> inspect(String projectPath) async {
    final pubspec = await _config.pubspec(projectPath);
    final config = await _config.l10nConfig(projectPath);
    final hasArbFiles = (await ArbService.arbFilesIn(
      config.arbDirIn(projectPath),
    )).isNotEmpty;

    return LocalizationChecks(
      hasPubspec: pubspec != null,
      isFlutterProject: pubspec?.isFlutter ?? false,
      hasArbFiles: hasArbFiles,
      hasGeneratedClasses: await File(config.generatedPathIn(projectPath))
          .exists(),
      hasAppIntegration: await _libSources(projectPath)
          .any((source) => AppWidgetLocalizer.isLocalized(source.content)),
      hasDependencies:
          pubspec != null &&
          pubspec.dependsOn(_localizationsPackage) &&
          pubspec.dependsOn(_intlPackage),
      hasGenerateFlag: pubspec?.generatesLocalizations ?? false,
    );
  }

  /// Gives the app widget of the project at [projectPath] the generated
  /// localization delegates and locales, and looks its title up when the
  /// template ARB file has one; returns the path of the file building it,
  /// relative to the project. Throws when no file of `lib` builds an app
  /// widget.
  Future<String> wireApp(String projectPath) async {
    final app = await _appSource(projectPath);
    if (app == null) {
      throw Exception(
        'No MaterialApp, CupertinoApp or WidgetsApp found in lib',
      );
    }
    final packageName =
        await _config.packageName(projectPath) ?? _fallbackPackageName;
    final config = await _config.l10nConfig(projectPath);
    final template = await ArbService.read(config.templatePathIn(projectPath));
    final localized = AppWidgetLocalizer.localize(
      app.content,
      config: config,
      importUri: config.importUri(packageName),
      hasTitleKey: template?.containsKey(AppWidgetLocalizer.titleKey) ?? false,
    );
    if (localized != app.content) {
      await File(app.path).writeAsString(localized);
    }
    return p.relative(app.path, from: projectPath);
  }

  /// The Dart file of the project at [projectPath] building its app
  /// widget: the first of [_libSources] that builds one; null when none
  /// does.
  Future<DartSource?> _appSource(String projectPath) async {
    await for (final source in _libSources(projectPath)) {
      if (AppWidgetLocalizer.buildsApp(source.content)) return source;
    }
    return null;
  }

  /// The Dart files of `lib` in the project at [projectPath], read as
  /// they are listened to: `main.dart` first, where the app is usually
  /// built, then the others by path.
  Stream<DartSource> _libSources(String projectPath) async* {
    final paths = ProjectPaths(projectPath);
    final mainDart = await ProjectConfigReader.readIfExists(paths.mainDart);
    if (mainDart != null) yield (path: paths.mainDart, content: mainDart);
    if (!await Directory(paths.libDir).exists()) return;
    final others = [
      await for (final file in ProjectFiles.walk(
        paths.libDir,
        extension: ProjectFiles.dartExtension,
      ))
        if (!p.equals(file.path, paths.mainDart)) file.path,
    ]..sort();
    for (final path in others) {
      yield (path: path, content: await File(path).readAsString());
    }
  }

  /// Writes English and French template ARB files into the project's ARB
  /// folder, using the app widget's title when one is set.
  Future<void> _createTemplateArbFiles(String projectPath) async {
    final config = await _config.l10nConfig(projectPath);
    await Directory(config.arbDirIn(projectPath)).create(recursive: true);

    final app = await _appSource(projectPath);
    final extractedTitle = app == null
        ? null
        : AppWidgetLocalizer.appTitle(app.content);
    final appTitle = extractedTitle == null || extractedTitle.isEmpty
        ? AppWidgetLocalizer.defaultTitle
        : extractedTitle;

    for (final (locale, title, greeting) in [
      ('en', appTitle, 'Hello World'),
      ('fr', 'Mon Application', 'Bonjour le monde'),
    ]) {
      await ArbService.write(config.arbPathFor(projectPath, locale), {
        ArbService.localeKey: locale,
        AppWidgetLocalizer.titleKey: title,
        ArbKeys.metadataKeyOf(AppWidgetLocalizer.titleKey): {
          ArbMessage.descriptionKey: 'The title of the application',
        },
        _greetingKey: greeting,
        ArbKeys.metadataKeyOf(_greetingKey): {
          ArbMessage.descriptionKey: 'A greeting message',
        },
      });
    }
  }

  /// Turns on `flutter: generate: true` in the project's pubspec, creating
  /// the `flutter:` section when it is missing or empty.
  Future<void> _enableGenerate(String projectPath) =>
      ProjectConfigReader.updatePubspec(projectPath, (yaml) {
        final editor = YamlEditor(yaml);
        final flutterSection = editor.parseAt([
          Pubspec.flutterKey,
        ], orElse: () => wrapAsYamlNode(null));
        if (flutterSection is YamlMap) {
          editor.update([Pubspec.flutterKey, Pubspec.generateKey], true);
        } else {
          editor.update([Pubspec.flutterKey], {Pubspec.generateKey: true});
        }
        return editor.toString();
      });

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
