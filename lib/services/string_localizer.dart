import 'dart:io';

import 'package:fcheck/fcheck.dart' as fcheck;
import 'package:fide/models/arb_keys.dart';
import 'package:fide/models/dart_imports.dart';
import 'package:fide/models/hardcoded_string.dart';
import 'package:fide/models/l10n_config.dart';
import 'package:fide/models/localization_plan.dart';
import 'package:fide/models/string_rewrite.dart';
import 'package:fide/services/arb_service.dart';
import 'package:fide/services/code_formatter.dart';
import 'package:fide/services/hardcoded_string_finder.dart';
import 'package:fide/services/l10n_generator.dart';
import 'package:fide/services/project_config_reader.dart';
import 'package:path/path.dart' as p;

/// Localizes hardcoded strings without AI: [plan] lists the strings
/// fCheck located that can become lookups, and [apply] moves the ones the
/// user picked into the template ARB file, replaces them with lookups of
/// the generated localizations class, then regenerates the class.
///
/// fCheck says where each string is and which `BuildContext` and `const`
/// keywords surround it; this class only edits the text.
class StringLocalizer {
  /// Creates a localizer reading project settings with [_config],
  /// regenerating through [_generator] and formatting through
  /// [_formatter].
  const StringLocalizer(this._config, this._generator, this._formatter);

  /// Reason for strings with no `BuildContext` to look them up with.
  static const String noContext = 'without a BuildContext';

  /// Reason for strings with braces, read as ARB placeholders.
  static const String braces = 'with braces';

  final CodeFormatter _formatter;

  final ProjectConfigReader _config;

  final L10nGenerator _generator;

  /// The strings [metrics] found in the project at [projectPath] that can
  /// become lookups, for the user to pick from; throws when the project
  /// has no valid template ARB file or its translations are not in ARB.
  Future<LocalizationPlan> plan(
    String projectPath,
    fcheck.ProjectMetrics metrics,
  ) async {
    final config = await _config.l10nConfig(projectPath);
    // Throws without a valid template ARB file
    await readTemplate(projectPath, config);
    final packageName = await _config.packageName(projectPath);
    if (packageName == null) throw Exception('pubspec.yaml has no name');
    final sync = metrics.localizationSync;
    if (sync != null && !sync.isInSync) {
      throw Exception(
        'Translations live in ${p.basename(sync.generatedFilePath)}, '
        'not in the ARB files: migrate them to ARB first',
      );
    }

    final found = await HardcodedStringFinder.find(
      metrics,
      reject: (string) => string.site.buildContextName == null
          ? noContext
          : string.message.isExpressible
          ? null
          : braces,
    );
    return LocalizationPlan(
      projectPath: projectPath,
      config: config,
      importUri: config.importUri(packageName),
      candidates: found.candidates,
      rejected: found.rejected,
      skipped: found.skipped,
    );
  }

  /// Replaces the [selected] strings of [plan] with lookups, adds their
  /// messages to the template ARB file and regenerates the localizations
  /// class.
  Future<StringRewrite> apply(
    LocalizationPlan plan,
    Iterable<HardcodedString> selected,
  ) async {
    final config = plan.config;
    final arb = await readTemplate(plan.projectPath, config);
    final keys = ArbKeys(arb);
    final skipped = {...plan.skipped};
    final chosen = selected.toSet();
    final uncheckedCount = plan.candidates.length - chosen.length;
    if (uncheckedCount > 0) {
      HardcodedStringFinder.count(
        skipped,
        HardcodedStringFinder.unchecked,
        uncheckedCount,
      );
    }

    final byFile = <String, List<HardcodedString>>{};
    for (final string in chosen) {
      (byFile[string.path] ??= []).add(string);
    }
    var localized = 0;
    final changedFiles = <String>[];
    for (final MapEntry(key: path, value: strings) in byFile.entries) {
      final file = File(path);
      final rewrite = rewriteSource(
        await file.readAsString(),
        strings,
        config: config,
        keys: keys,
        importUri: plan.importUri,
      );
      if (rewrite.changed > 0) {
        HardcodedStringFinder.count(
          skipped,
          HardcodedStringFinder.changedFile,
          rewrite.changed,
        );
      }
      if (rewrite.localized == 0) continue;
      await file.writeAsString(
        await _formatter.formatOrKeep(path, rewrite.content),
      );
      changedFiles.add(path);
      localized += rewrite.localized;
    }

    if (keys.added.isNotEmpty) {
      arb.addAll(keys.added);
      await File(templatePath(plan.projectPath, config))
          .writeAsString(ArbService.encode(arb));
      await _generator.generateClasses(plan.projectPath);
    }
    return StringRewrite(
      action: 'Localized',
      rewritten: localized,
      changedFiles: changedFiles,
      skipped: skipped,
    );
  }

  /// [content] with each of [strings] replaced by its lookup under a key
  /// from [keys], the `const` keywords around them removed, and
  /// [importUri] imported; with how many strings were replaced and how
  /// many were not because the file changed since the analysis.
  static ({String content, int localized, int changed}) rewriteSource(
    String content,
    Iterable<HardcodedString> strings, {
    required L10nConfig config,
    required ArbKeys keys,
    required String importUri,
  }) {
    // Offset → (length, replacement), applied from the end of the file
    final edits = <int, (int, String)>{};
    var changed = 0;
    for (final HardcodedString(:site, :message) in strings) {
      final contextName = site.buildContextName;
      if (contextName == null ||
          !HardcodedStringFinder.isStringAt(content, site)) {
        changed++;
        continue;
      }
      final key = keys.keyFor(message);
      edits[site.offset] = (
        site.length,
        message.lookup(config.lookup(contextName), key),
      );
      for (final offset in site.constKeywordOffsets) {
        edits[offset] = (_constLength(content, offset), '');
      }
    }
    final localized = strings.length - changed;
    if (localized == 0) {
      return (content: content, localized: 0, changed: changed);
    }

    var result = content;
    for (final offset in edits.keys.toList()..sort((a, b) => b - a)) {
      final (length, text) = edits[offset]!;
      result = result.replaceRange(offset, offset + length, text);
    }
    return (
      content: withImport(
        result,
        importUri,
        isImported: (uri) => p.url.basename(uri) == config.outputFile,
      ),
      localized: localized,
      changed: changed,
    );
  }

  /// Length of the `const` keyword at [offset] with the spaces after it;
  /// 0 when there is none.
  static int _constLength(String content, int offset) {
    final match = RegExp(r'const\s+').matchAsPrefix(content, offset);
    return match == null ? 0 : match.end - offset;
  }

  /// The entries of the project's template ARB file; throws when it is
  /// missing or invalid.
  static Future<Map<String, dynamic>> readTemplate(
    String projectPath,
    L10nConfig config,
  ) async {
    final template = File(templatePath(projectPath, config));
    final arb = await template.exists()
        ? ArbService.decode(await template.readAsString())
        : null;
    if (arb == null) {
      throw Exception(
        'No valid ${p.relative(template.path, from: projectPath)}: '
        'set up localization first',
      );
    }
    return arb;
  }

  /// Path of the template ARB file of the project at [projectPath].
  static String templatePath(String projectPath, L10nConfig config) =>
      p.join(projectPath, config.arbDir, config.templateArbFile);
}
