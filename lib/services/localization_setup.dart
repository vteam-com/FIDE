import 'dart:io';

import 'package:fide/models/arb_keys.dart';
import 'package:fide/models/arb_message.dart';
import 'package:fide/models/l10n_config.dart';
import 'package:fide/models/language_catalog.dart';
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
/// by [AppWidgetLocalizer]), adds and removes locales and reports which of
/// those pieces a project already has.
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

  /// Adds [locale] to the project at [projectPath]: writes its ARB file
  /// with [createArbFile] and, once the project has generated its classes,
  /// generates them again so the app supports it; returns the file's path.
  /// Throws when [locale] has an ARB file already.
  Future<String> addLocale(String projectPath, String locale) async {
    final path = await createArbFile(projectPath, locale);
    if (path == null) throw Exception('$locale already has an ARB file');
    await _regenerate(projectPath, await _config.l10nConfig(projectPath));
    return path;
  }

  /// Writes the ARB file of [locale] in the project at [projectPath], named
  /// like the template's and holding only its `@@locale`, so the app shows
  /// the template's messages until it is translated; returns its path, or
  /// null when [locale] has one already.
  Future<String?> createArbFile(String projectPath, String locale) async {
    final config = await _config.l10nConfig(projectPath);
    final path = config.arbPathFor(projectPath, locale);
    if (await File(path).exists()) return null;
    await Directory(config.arbDirIn(projectPath)).create(recursive: true);
    await ArbService.write(path, {ArbService.localeKey: locale});
    return path;
  }

  /// Sets up localization: adds `flutter_localizations` and `intl`, enables
  /// code generation, writes the ARB files of [locales] (the template's
  /// always) and generates classes.
  ///
  /// [onStep] is told about each step before it runs. Tool failures throw
  /// unless [tolerateToolFailures] is set, in which case they are logged and
  /// setup continues, so creating a project doesn't fail when pub is offline.
  Future<void> initializeLocalization(
    String projectPath, {
    ProcessOutputCallback? onStep,
    bool tolerateToolFailures = false,
    Set<String> locales = LanguageCatalog.starterLocales,
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
    await _createTemplateArbFiles(projectPath, locales);

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

  /// Removes [locale] from the project at [projectPath]: deletes its ARB
  /// file and, once the project has generated its classes, generates them
  /// again, then deletes the file generated for its language when no
  /// locale of it remains, which `flutter gen-l10n` leaves behind; returns
  /// the ARB file's path. Throws for the template's locale and for a
  /// language that a regional locale, such as `pt_BR` for `pt`, falls back
  /// to.
  Future<String> removeLocale(String projectPath, String locale) async {
    final config = await _config.l10nConfig(projectPath);
    if (locale == config.templateParts?.locale) {
      throw Exception('$locale is the template the other locales fall back to');
    }
    final files = {
      for (final path in await ArbService.arbFilesIn(
        config.arbDirIn(projectPath),
      ))
        ?L10nConfig.localeOf(p.basename(path)): path,
    };
    final path = files.remove(locale);
    if (path == null) throw Exception('$locale has no ARB file');
    final regional = files.keys.where(
      (other) => LanguageCatalog.languageOf(other) == locale,
    );
    if (regional.isNotEmpty) {
      throw Exception(
        'Remove ${regional.join(', ')} first: it falls back to $locale',
      );
    }
    await File(path).delete();
    final language = LanguageCatalog.languageOf(locale);
    final languageLeft = files.keys.any(
      (other) => LanguageCatalog.languageOf(other) == language,
    );
    if (await _regenerate(projectPath, config) && !languageLeft) {
      final stale = File(config.generatedLanguagePathIn(projectPath, language));
      if (await stale.exists()) await stale.delete();
    }
    return path;
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

  /// Generates the classes of the project at [projectPath], whose gen-l10n
  /// settings are [config], again, unless it has generated none yet: its
  /// next build, or the Localization panel, does; whether it did.
  Future<bool> _regenerate(String projectPath, L10nConfig config) async {
    if (!await File(config.generatedPathIn(projectPath)).exists()) {
      return false;
    }
    await _generator.generateClasses(projectPath);
    return true;
  }

  /// Writes the English template ARB file into the project's ARB folder,
  /// using the app widget's title when one is set, then the file of each
  /// other of [locales]: French with its starter messages, the others
  /// with [createArbFile].
  Future<void> _createTemplateArbFiles(
    String projectPath,
    Set<String> locales,
  ) async {
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
      (LanguageCatalog.english, appTitle, 'Hello World'),
      if (locales.contains(LanguageCatalog.french))
        (LanguageCatalog.french, 'Mon Application', 'Bonjour le monde'),
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
    for (final locale in locales) {
      await createArbFile(projectPath, locale);
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
