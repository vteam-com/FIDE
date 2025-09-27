// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';
import 'package:fide/models/localization_data.dart';
import 'package:yaml_edit/yaml_edit.dart';

class LocalizationService {
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
          print(
            'Warning: Failed to add flutter_localizations: ${addFlutterLocalizationsResult.stderr}',
          );
        }
      } catch (e) {
        print('Warning: Could not add flutter_localizations: $e');
      }

      try {
        final addIntlResult = await Process.run('flutter', [
          'pub',
          'add',
          'intl',
        ], workingDirectory: projectPath);
        if (addIntlResult.exitCode != 0) {
          print('Warning: Failed to add intl: ${addIntlResult.stderr}');
        }
      } catch (e) {
        print('Warning: Could not add intl: $e');
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
          print(
            'Warning: Failed to generate localization classes: ${result.stderr}',
          );
        }
      } catch (e) {
        print('Warning: Could not run flutter gen-l10n: $e');
      }
    } catch (e) {
      throw Exception('Error initializing localization: $e');
    }
  }

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

class ArbService {
  Future<List<ArbFile>> loadArbFiles(String directoryPath) async {
    final directory = Directory(directoryPath);
    final arbFiles = <ArbFile>[];

    if (!await directory.exists()) return arbFiles;

    await for (final entity in directory.list(recursive: true)) {
      if (entity is File && entity.path.endsWith('.arb')) {
        print('Found ARB file: ${entity.path}');
        try {
          final arbFile = await parseArbFile(entity.path);
          if (arbFile != null) {
            arbFiles.add(arbFile);
            print(
              'Successfully parsed ARB file: ${arbFile.path}, language: ${arbFile.languageCode}',
            );
          } else {
            print('Failed to parse ARB file: ${entity.path}');
          }
        } catch (e) {
          // Skip invalid ARB files
          print('Error parsing ARB file ${entity.path}: $e');
        }
      }
    }

    print('Total ARB files found: ${arbFiles.length}');
    return arbFiles;
  }

  Future<ArbFile?> parseArbFile(String path) async {
    final file = File(path);
    final content = await file.readAsString();
    // Remove BOM if present
    final cleanContent = content.startsWith('\uFEFF')
        ? content.substring(1)
        : content;
    final decoded = jsonDecode(cleanContent);
    if (decoded is! Map<String, dynamic>) {
      print(
        'Error: ARB file $path does not contain a valid JSON object. Content length: ${content.length}, Clean content length: ${cleanContent.length}',
      );
      print(
        'Raw content (first 200 chars): ${content.substring(0, content.length > 200 ? 200 : content.length)}',
      );
      return null;
    }
    final json = decoded;

    final entries = <String, ArbEntry>{};
    final metadata = <String, Map<String, dynamic>>{};

    // First pass: collect metadata
    for (final key in json.keys) {
      if (key.startsWith('@')) {
        final originalKey = key.substring(1);
        final meta = json[key];
        if (meta is Map<String, dynamic>) {
          metadata[originalKey] = meta;
        } else {
          print(
            'Warning: metadata for $originalKey is not a valid map, skipping',
          );
        }
      }
    }

    // Second pass: create entries
    for (final key in json.keys) {
      if (!key.startsWith('@')) {
        final value = json[key];
        final entryMetadata = metadata[key];
        entries[key] = ArbEntry.fromJson(key, value, entryMetadata);
      }
    }

    final filename = path.split(Platform.pathSeparator).last;
    final languageCode = ArbFile.extractLanguageCode(filename);

    return ArbFile(path: path, languageCode: languageCode, entries: entries);
  }

  Future<bool> isArbFileValid(String path) async {
    try {
      final file = File(path);
      final content = await file.readAsString();
      final decoded = jsonDecode(content);
      return decoded is Map<String, dynamic>;
    } catch (e) {
      return false;
    }
  }

  List<ArbComparison> compareArbFiles(List<ArbFile> arbFiles) {
    final comparisons = <ArbComparison>[];

    if (arbFiles.isEmpty) {
      return comparisons; // Return empty list when no ARB files exist
    }

    // Find English file
    final englishFile = arbFiles.firstWhere(
      (file) => file.languageCode.toLowerCase() == 'en',
      orElse: () => arbFiles.first, // Use first file as fallback if no English
    );

    final otherFiles = arbFiles.where((file) => file != englishFile).toList();

    // Get all unique keys
    final allKeys = <String>{};
    for (final file in arbFiles) {
      allKeys.addAll(file.entries.keys);
    }

    for (final key in allKeys) {
      final englishValue = englishFile.entries[key]?.value;
      final otherValues = <String, String?>{};

      for (final file in otherFiles) {
        otherValues[file.languageCode] = file.entries[key]?.value;
      }

      final missingInLanguages = otherFiles
          .where((file) => !file.entries.containsKey(key))
          .map((file) => file.languageCode)
          .toList();

      comparisons.add(
        ArbComparison(
          key: key,
          englishValue: englishValue,
          otherValues: otherValues,
          isMissingInEnglish: englishValue == null,
          missingInLanguages: missingInLanguages,
        ),
      );
    }

    return comparisons;
  }

  Future<void> updateArbFile(
    String path,
    String key,
    String value, {
    Map<String, dynamic>? metadata,
  }) async {
    final file = File(path);
    final content = await file.readAsString();
    final decoded = jsonDecode(content);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('ARB file $path does not contain a valid JSON object');
    }
    final json = decoded;

    json[key] = value;
    if (metadata != null) {
      json['@$key'] = metadata;
    }

    final updatedContent = jsonEncode(json);
    await file.writeAsString(updatedContent);
  }
}
