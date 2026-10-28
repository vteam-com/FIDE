// ignore_for_file: avoid_print
// ignore: fcheck_dead_code
import 'dart:convert';
import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

import 'package:fide/constants/constants.dart';
import 'package:fide/models/localization_checks.dart';
import 'package:fide/models/localization_data.dart';
import 'package:fide/providers/process_runner.dart';
import 'package:logging/logging.dart';
import 'package:yaml_edit/yaml_edit.dart';

part 'localization_service.arb_service.dart';
part 'localization_service.material_app_title_visitor.dart';

/// Represents `LocalizationService`.
class LocalizationService {
  static final Logger _logger = Logger('LocalizationService');

  final ProcessRunner _runner;

  /// Creates a localization service that launches commands through [_runner].
  LocalizationService([this._runner = const ProcessRunner()]);

  /// Runs `flutter gen-l10n`, throwing with the tool's stderr on failure.
  Future<void> generateClasses(String projectPath) {
    return _runFlutter(projectPath, [
      'gen-l10n',
    ], 'Failed to generate localization classes');
  }

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
    Future<void> runTool(List<String> arguments, String failure) async {
      try {
        await _runFlutter(projectPath, arguments, failure);
      } catch (e) {
        if (!tolerateToolFailures) rethrow;
        _logger.warning('$e');
      }
    }

    onStep?.call('Adding flutter_localizations and intl packages...');
    await runTool([
      'pub',
      'add',
      'flutter_localizations',
      '--sdk=flutter',
    ], 'Failed to add flutter_localizations');
    await runTool(['pub', 'add', 'intl'], 'Failed to add intl');

    onStep?.call('Configuring pubspec.yaml...');
    await _enableGenerate(projectPath);

    onStep?.call('Creating template ARB files...');
    await _createTemplateArbFiles(projectPath);

    onStep?.call('Generating localization classes...');
    await runTool(['gen-l10n'], 'Failed to generate localization classes');
  }

  /// Reads which localization pieces the project at [projectPath] has.
  Future<LocalizationChecks> inspect(String projectPath) async {
    final pubspec = await _readIfExists('$projectPath/pubspec.yaml');
    final mainDart = await _readIfExists('$projectPath/lib/main.dart');
    final l10nDir = Directory('$projectPath/lib/l10n');
    final hasArbFiles =
        await l10nDir.exists() &&
        await l10nDir.list().any((entity) => entity.path.endsWith('.arb'));

    return LocalizationChecks(
      hasPubspec: pubspec != null,
      isFlutterProject:
          pubspec != null &&
          pubspec.contains('flutter:') &&
          pubspec.contains('sdk: flutter'),
      hasArbFiles: hasArbFiles,
      hasGeneratedClasses: await File(
        '$projectPath/lib/l10n/app_localizations.dart',
      ).exists(),
      hasAppIntegration:
          mainDart != null &&
          mainDart.contains('AppLocalizations') &&
          mainDart.contains('localizationsDelegates') &&
          mainDart.contains('supportedLocales'),
      hasDependencies:
          pubspec != null &&
          pubspec.contains('flutter_localizations:') &&
          pubspec.contains('intl:'),
      hasGenerateFlag: pubspec != null && pubspec.contains('generate: true'),
    );
  }

  /// Updates `main.dart` to wire generated localization delegates and title lookup.
  Future<void> updateMainDartForLocalization(String projectPath) async {
    final mainFile = File('$projectPath/lib/main.dart');
    if (!await mainFile.exists()) {
      throw Exception('main.dart not found in project');
    }

    String content = await mainFile.readAsString();

    // Extract package name from pubspec.yaml
    String packageName = 'my_app'; // default fallback
    final pubspecFile = File('$projectPath/pubspec.yaml');
    if (await pubspecFile.exists()) {
      final pubspecContent = await pubspecFile.readAsString();
      final nameMatch = RegExp(
        r'^name:\s*([^\s]+)',
        multiLine: true,
      ).firstMatch(pubspecContent);
      if (nameMatch != null) {
        packageName = nameMatch.group(1)!;
      }
    }

    // Add import if missing
    final importPath =
        "import 'package:$packageName/l10n/app_localizations.dart';";
    if (!content.contains(importPath)) {
      // Find the first import statement and add after it
      final importMatch = RegExp(r'import .+;').firstMatch(content);
      if (importMatch != null) {
        final insertPos = importMatch.end;
        content =
            '${content.substring(0, insertPos)}\n$importPath\n${content.substring(insertPos)}';
      }
    }

    // Extract original title for fallback
    String originalTitle = 'My App';
    final titleRegex = RegExp(r"title\s*:\s*'([^']*)'");
    final titleMatch = titleRegex.firstMatch(content);
    if (titleMatch != null) {
      originalTitle = titleMatch.group(1)!;
    }

    // Replace title with onGenerateTitle
    if (!content.contains('onGenerateTitle')) {
      content = content.replaceAllMapped(titleRegex, (match) {
        return "onGenerateTitle: (BuildContext context) =>\n      AppLocalizations.of(context)?.appTitle ?? '$originalTitle'";
      });
    }

    // Update MaterialApp to include localizationsDelegates and supportedLocales
    if (!content.contains(
      'localizationsDelegates: AppLocalizations.localizationsDelegates',
    )) {
      // Find MaterialApp and add localizationsDelegates
      final materialAppMatch = RegExp(r'MaterialApp\s*\(').firstMatch(content);
      if (materialAppMatch != null) {
        final insertPos = materialAppMatch.end;
        // Check if there are already properties
        final nextClosingParen = content.indexOf(')', insertPos);
        final existingContent = content.substring(insertPos, nextClosingParen);

        if (existingContent.trim().isNotEmpty &&
            !existingContent.trim().startsWith(',')) {
          // Add comma and new property
          content =
              '${content.substring(0, insertPos)}\n  localizationsDelegates: AppLocalizations.localizationsDelegates,\n  supportedLocales: AppLocalizations.supportedLocales,\n${content.substring(insertPos)}';
        } else {
          // Add new properties
          content =
              '${content.substring(0, insertPos)}\n  localizationsDelegates: AppLocalizations.localizationsDelegates,\n  supportedLocales: AppLocalizations.supportedLocales,\n${content.substring(insertPos)}';
        }
      }
    }

    await mainFile.writeAsString(content);
  }

  /// Writes English and French template ARB files into `lib/l10n`, using
  /// the app title from `main.dart` when one is set.
  Future<void> _createTemplateArbFiles(String projectPath) async {
    final l10nDir = Directory('$projectPath/lib/l10n');
    await l10nDir.create(recursive: true);

    final mainDart = await _readIfExists('$projectPath/lib/main.dart');
    final extractedTitle = mainDart == null
        ? null
        : _extractAppTitleFromMainDart(mainDart);
    final appTitle = extractedTitle == null || extractedTitle.isEmpty
        ? 'My App'
        : extractedTitle;

    final englishArbContent = {
      '@@locale': 'en',
      'appTitle': appTitle,
      '@appTitle': {'description': 'The title of the application'},
      'helloWorld': 'Hello World',
      '@helloWorld': {'description': 'A greeting message'},
    };
    final frenchArbContent = {
      '@@locale': 'fr',
      'appTitle': 'Mon Application',
      '@appTitle': {'description': 'The title of the application'},
      'helloWorld': 'Bonjour le monde',
      '@helloWorld': {'description': 'A greeting message'},
    };

    await File('${l10nDir.path}/app_en.arb')
        .writeAsString(jsonEncode(englishArbContent));
    await File('${l10nDir.path}/app_fr.arb')
        .writeAsString(jsonEncode(frenchArbContent));
  }

  /// Turns on `flutter: generate: true` in the project's pubspec.
  Future<void> _enableGenerate(String projectPath) async {
    final pubspecFile = File('$projectPath/pubspec.yaml');
    if (!await pubspecFile.exists()) return;

    final editor = YamlEditor(await pubspecFile.readAsString());
    editor.update(['flutter', 'generate'], true);
    await pubspecFile.writeAsString(editor.toString());
  }

  /// Returns the string literal passed as `MaterialApp(title:)`, if any.
  String? _extractAppTitleFromMainDart(String content) {
    try {
      final visitor = _MaterialAppTitleVisitor();
      parseString(content: content).unit.accept(visitor);
      return visitor.title;
    } catch (e) {
      _logger.severe('Error parsing main.dart: $e');
      return null;
    }
  }

  /// Returns the file's contents, or null when it doesn't exist.
  Future<String?> _readIfExists(String filePath) async {
    final file = File(filePath);
    return await file.exists() ? file.readAsString() : null;
  }

  /// Runs a `flutter` subcommand in the project, throwing [failure] with the
  /// tool's stderr when it exits non-zero.
  Future<void> _runFlutter(
    String projectPath,
    List<String> arguments,
    String failure,
  ) async {
    final result = await _runner.run(
      'flutter',
      arguments,
      workingDirectory: projectPath,
    );
    if (result.exitCode != 0) {
      throw Exception('$failure: ${result.stderr}');
    }
  }
}
