// ignore_for_file: avoid_print
// ignore: fcheck_dead_code
import 'dart:convert';
import 'dart:io';

import 'package:fide/constants.dart';
import 'package:fide/models/localization_data.dart';
import 'package:logging/logging.dart';
import 'package:yaml_edit/yaml_edit.dart';

part 'localization_service.arb_service.dart';

/// Represents `LocalizationService`.
class LocalizationService {
  static final Logger _logger = Logger('LocalizationService');

  /// Sets up localization dependencies, config, ARB files, and generated classes.
  Future<void> initializeLocalization(String projectPath) async {
    try {
      // Add required packages using flutter pub add
      try {
        final addFlutterLocalizationsResult = await Process.run('flutter', [
          'pub',
          'add',
          'flutter_localizations',
          '--sdk=flutter',
        ], workingDirectory: projectPath);
        if (addFlutterLocalizationsResult.exitCode != 0) {
          _logger.warning(
            'Failed to add flutter_localizations: ${addFlutterLocalizationsResult.stderr}',
          );
        }
      } catch (e) {
        _logger.severe('Could not add flutter_localizations: $e');
      }

      try {
        final addIntlResult = await Process.run('flutter', [
          'pub',
          'add',
          'intl',
        ], workingDirectory: projectPath);
        if (addIntlResult.exitCode != 0) {
          _logger.warning('Failed to add intl: ${addIntlResult.stderr}');
        }
      } catch (e) {
        _logger.severe('Could not add intl: $e');
      }

      // Add required configurations to pubspec.yaml
      final pubspecFile = File('$projectPath/pubspec.yaml');
      if (await pubspecFile.exists()) {
        final pubspecContent = await pubspecFile.readAsString();
        final editor = YamlEditor(pubspecContent);

        // Add generate: true to flutter section
        editor.update(['flutter', 'generate'], true);

        await pubspecFile.writeAsString(editor.toString());
      }

      // Create l10n directory if it doesn't exist
      final l10nDir = Directory('$projectPath/lib/l10n');
      if (!await l10nDir.exists()) {
        await l10nDir.create(recursive: true);
      }

      // Create basic ARB files
      final englishArbPath = '${l10nDir.path}/app_en.arb';
      final frenchArbPath = '${l10nDir.path}/app_fr.arb';

      // Try to extract app title from main.dart
      String appTitle = 'My App';
      final mainFile = File('$projectPath/lib/main.dart');
      if (await mainFile.exists()) {
        final mainContent = await mainFile.readAsString();
        final extractedTitle = _extractAppTitleFromMainDart(mainContent);
        if (extractedTitle != null && extractedTitle.isNotEmpty) {
          appTitle = extractedTitle;
        }
      }

      // Create English ARB file with basic structure
      final englishArbContent = {
        '@@locale': 'en',
        'appTitle': appTitle,
        '@appTitle': {'description': 'The title of the application'},
        'helloWorld': 'Hello World',
        '@helloWorld': {'description': 'A greeting message'},
      };

      // Create French ARB file with translations
      final frenchArbContent = {
        '@@locale': 'fr',
        'appTitle': 'Mon Application',
        '@appTitle': {'description': 'The title of the application'},
        'helloWorld': 'Bonjour le monde',
        '@helloWorld': {'description': 'A greeting message'},
      };

      // Write the ARB files
      await File(englishArbPath).writeAsString(jsonEncode(englishArbContent));
      await File(frenchArbPath).writeAsString(jsonEncode(frenchArbContent));

      // Generate localization classes
      try {
        final result = await Process.run('flutter', [
          'gen-l10n',
        ], workingDirectory: projectPath);

        if (result.exitCode != 0) {
          _logger.warning(
            'Failed to generate localization classes: ${result.stderr}',
          );
        }
      } catch (e) {
        _logger.severe('Could not run flutter gen-l10n: $e');
      }
    } catch (e) {
      throw Exception('Error initializing localization: $e');
    }
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

  String? _extractAppTitleFromMainDart(String content) {
    // Use regex to find title: 'something' in MaterialApp
    final titleRegex = RegExp(r"title\s*:\s*'([^']*)'");
    final match = titleRegex.firstMatch(content);
    return match?.group(1);
  }
}
