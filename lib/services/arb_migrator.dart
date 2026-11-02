import 'dart:io';

import 'package:fcheck/fcheck.dart' as fcheck;
import 'package:fide/models/arb_migration.dart';
import 'package:fide/models/dart_imports.dart';
import 'package:fide/models/dart_translations.dart';
import 'package:fide/models/hand_written_l10n.dart';
import 'package:fide/models/project_paths.dart';
import 'package:fide/services/code_formatter.dart';
import 'package:fide/services/localization_service.dart';
import 'package:fide/services/process_runner.dart';
import 'package:path/path.dart' as p;

/// Moves translations written as Dart localizations classes into ARB
/// files, once, so `flutter gen-l10n` can own the classes again.
///
/// fCheck's [fcheck.LocalizationSync] says which keys and hand-written code
/// the ARB files lack. The migration writes every locale's messages to its
/// ARB file, moves the hand-written code to its own file and imports it
/// where it is used, then regenerates the classes. When the project ends
/// up with more analyzer errors than before, every file is restored.
class ArbMigrator {
  /// Creates a migrator running tools through [_runner].
  const ArbMigrator(this._runner, this._localization, this._formatter);

  /// Suffix of the file the hand-written code moves to.
  static const String _movedSuffix = '_extensions.dart';

  /// An analyzer error line of `flutter analyze`.
  static final RegExp _analyzerError = RegExp(r'^\s*error •', multiLine: true);

  final CodeFormatter _formatter;

  final LocalizationService _localization;

  final ProcessRunner _runner;

  /// Migrates the project at [projectPath], whose generated class [sync]
  /// compared with its ARB files.
  Future<ArbMigration> migrate(
    String projectPath,
    fcheck.LocalizationSync sync,
  ) async {
    final config = await _localization.l10nConfig(projectPath);
    final packageName = await _localization.packageName(projectPath);
    if (packageName == null) throw Exception('pubspec.yaml has no name');
    final outputDir = p.dirname(sync.generatedFilePath);
    final stem = p.basenameWithoutExtension(sync.generatedFilePath);
    final template = config.templateParts;
    if (template == null) {
      throw Exception('Unexpected template ARB name ${config.templateArbFile}');
    }
    final (prefix: arbPrefix, locale: templateLocale) = template;

    // Read everything first: nothing is written if a key cannot move
    final translations = await _readLocales(outputDir, stem, sync.outputClass);
    final templateTranslations = translations[templateLocale];
    if (templateTranslations == null) {
      throw Exception('No ${stem}_$templateLocale.dart to migrate from');
    }
    final unsupported = {
      for (final dart in translations.values) ...dart.unsupported,
    };
    if (unsupported.isNotEmpty) {
      throw Exception(
        'These keys are not plain strings and need a manual move: '
        '${unsupported.join(', ')}',
      );
    }
    final generated = await File(sync.generatedFilePath).readAsString();
    final moved = HandWrittenL10n.extract(
      generated,
      sync.outputClass,
      sync.handWrittenMembers,
    );

    final arbDir = p.join(projectPath, config.arbDir);
    final movedPath = p.join(outputDir, '$stem$_movedSuffix');
    final callers = await _callers(
      projectPath,
      outputDir,
      stem,
      sync.outputClass,
      moved,
    );
    final snapshot = await _snapshot([
      ...await _filesIn(arbDir, '.arb'),
      ...await _filesIn(outputDir, '.dart'),
      ...callers.keys,
      movedPath,
    ]);
    final errorsBefore = await _analyzerErrors(projectPath);
    try {
      for (final MapEntry(key: locale, value: dart) in translations.entries) {
        final path = p.join(arbDir, '$arbPrefix$locale.arb');
        await _writeArb(
          path,
          locale,
          dart,
          withPlaceholders: locale == templateLocale,
        );
      }
      if (moved.source.isNotEmpty) {
        await _writeFormatted(
          movedPath,
          "import 'package:flutter/widgets.dart';\n\n"
          "import '$stem.dart';\n\n${moved.source}\n",
        );
        final movedUri =
            'package:$packageName/'
            '${p.posix.relative(p.relative(movedPath, from: projectPath), from: 'lib')}';
        for (final MapEntry(key: path, value: content) in callers.entries) {
          await _writeFormatted(
            path,
            withImport(
              content,
              movedUri,
              isImported: (uri) => p.url.basename(uri) == '$stem$_movedSuffix',
            ),
          );
        }
      }
      await _localization.generateClasses(projectPath);
      final errorsAfter = await _analyzerErrors(projectPath);
      if (errorsAfter > errorsBefore) {
        throw Exception(
          'the project would have ${errorsAfter - errorsBefore} more '
          'analyzer errors',
        );
      }
    } catch (e) {
      await _restore(snapshot, outputDir);
      throw Exception('Migration undone: $e');
    }
    return ArbMigration(
      keys: templateTranslations.messages.length,
      locales: translations.keys.toList(),
      movedCode: sync.handWrittenMembers,
      changedFiles: [...callers.keys, if (moved.source.isNotEmpty) movedPath],
    );
  }

  /// Number of errors `flutter analyze` reports in the project.
  Future<int> _analyzerErrors(String projectPath) async {
    final result = await _runner.run('flutter', [
      'analyze',
      '--no-pub',
    ], workingDirectory: projectPath);
    return _analyzerError.allMatches('${result.stdout}').length;
  }

  /// Dart files under `lib` that use [moved] code, with their content
  /// after `outputClass.name` calls of moved statics drop the class and,
  /// when nothing else uses the class, its import goes; the generated
  /// files in [outputDir] excluded.
  Future<Map<String, String>> _callers(
    String projectPath,
    String outputDir,
    String stem,
    String outputClass,
    HandWrittenL10n moved,
  ) async {
    final callers = <String, String>{};
    final usage = [
      if (moved.extensionMembers.isNotEmpty)
        '\\.(?:${moved.extensionMembers.join('|')})\\b',
      if (moved.topLevelNames.isNotEmpty)
        '\\b(?:${moved.topLevelNames.join('|')})\\b',
    ];
    final statics = moved.staticNames.isEmpty
        ? null
        : RegExp('\\b$outputClass\\.(${moved.staticNames.join('|')})\\b');
    if (usage.isEmpty && statics == null) return callers;
    final imports = RegExp(
      '''^import\\s+['"][^'"]*\\b$stem\\.dart['"][^;]*;[^\\n]*\\n?''',
      multiLine: true,
    );
    final classUse = RegExp('\\b$outputClass\\b');
    for (final path in await _filesIn(
      ProjectPaths(projectPath).libDir,
      '.dart',
      recursive: true,
    )) {
      if (p.isWithin(outputDir, path) || p.equals(p.dirname(path), outputDir)) {
        continue;
      }
      final content = await File(path).readAsString();
      if (!imports.hasMatch(content)) continue;
      var updated = statics?.hasMatch(content) == true
          ? content.replaceAllMapped(statics!, (match) => match[1]!)
          : content;
      if (updated == content &&
          !usage.any((pattern) => RegExp(pattern).hasMatch(content))) {
        continue;
      }
      // Imported only for the moved code
      if (!classUse.hasMatch(updated)) {
        updated = updated.replaceAll(imports, '');
      }
      callers[path] = updated;
    }
    return callers;
  }

  /// Files directly in (or, when [recursive], under) [directory] ending
  /// with [extension]; none when it does not exist.
  Future<List<String>> _filesIn(
    String directory,
    String extension, {
    bool recursive = false,
  }) async {
    final folder = Directory(directory);
    if (!await folder.exists()) return [];
    return [
      await for (final entity in folder.list(recursive: recursive))
        if (entity is File && entity.path.endsWith(extension)) entity.path,
    ];
  }

  /// Each locale's translations from the `<stem>_<locale>.dart` files in
  /// [outputDir].
  Future<Map<String, DartTranslations>> _readLocales(
    String outputDir,
    String stem,
    String outputClass,
  ) async {
    final pattern = RegExp('^${stem}_([a-z]{2,3}(?:_[A-Za-z0-9]+)?)\\.dart\$');
    return {
      for (final path in await _filesIn(outputDir, '.dart'))
        if (pattern.firstMatch(p.basename(path)) case final match?)
          match[1]!: DartTranslations.parse(
            await File(path).readAsString(),
            outputClass,
          ),
    };
  }

  /// Puts back every file of [snapshot] and deletes the Dart files
  /// generated in [outputDir] since.
  Future<void> _restore(Map<String, String?> snapshot, String outputDir) async {
    for (final path in await _filesIn(outputDir, '.dart')) {
      if (!snapshot.containsKey(path)) await File(path).delete();
    }
    for (final MapEntry(key: path, value: content) in snapshot.entries) {
      final file = File(path);
      if (content == null) {
        if (await file.exists()) await file.delete();
      } else {
        await file.writeAsString(content);
      }
    }
  }

  /// The content of each of [paths], null for files that do not exist.
  Future<Map<String, String?>> _snapshot(Iterable<String> paths) async => {
    for (final path in paths)
      path: await File(path).exists() ? await File(path).readAsString() : null,
  };

  /// Writes [dart]'s messages into the ARB file at [path], keeping its
  /// other entries; [withPlaceholders] adds the `@key` placeholder types
  /// the template file declares.
  Future<void> _writeArb(
    String path,
    String locale,
    DartTranslations dart, {
    required bool withPlaceholders,
  }) async {
    final file = File(path);
    final arb =
        (await file.exists()
            ? ArbService.decode(await file.readAsString())
            : null) ??
        <String, dynamic>{'@@locale': locale};
    arb.addAll(dart.messages);
    if (withPlaceholders) {
      for (final MapEntry(:key, value: types) in dart.placeholders.entries) {
        final metadata = {...?(arb['@$key'] as Map<String, dynamic>?)};
        metadata['placeholders'] = {
          for (final MapEntry(key: name, value: type) in types.entries)
            name: {'type': type},
        };
        arb['@$key'] = metadata;
      }
    }
    await file.writeAsString(ArbService.encode(arb));
  }

  /// Writes Dart [content] to [path], formatted when the formatter can.
  Future<void> _writeFormatted(String path, String content) async {
    await File(path)
        .writeAsString(await _formatter.formatOrKeep(path, content));
  }
}
