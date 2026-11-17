import 'dart:io';

import 'package:fcheck/fcheck.dart' as fcheck;
import 'package:fide/models/constants_plan.dart';
import 'package:fide/models/dart_imports.dart';
import 'package:fide/models/dart_string_literal.dart';
import 'package:fide/models/hardcoded_string.dart';
import 'package:fide/models/project_paths.dart';
import 'package:fide/models/string_rewrite.dart';
import 'package:fide/models/text_offsets.dart';
import 'package:fide/models/unique_name.dart';
import 'package:fide/services/code_formatter.dart';
import 'package:fide/services/hardcoded_string_finder.dart';
import 'package:fide/services/project_config_reader.dart';
import 'package:path/path.dart' as p;

/// Makes hardcoded strings that are data, such as Firestore collection and
/// field names, named constants in one class without AI: [plan] lists the
/// strings that can move, and [apply] declares the ones the user picked as
/// `static const String` fields, one per value, and refers to them.
///
/// fCheck does not report strings declared `const`, so the moved strings
/// stop counting as hardcoded.
class StringConstantsExtractor {
  /// Creates an extractor formatting through [_formatter] and reading the
  /// package name with [_config].
  const StringConstantsExtractor(this._formatter, this._config);

  /// Reason for strings with interpolations, which cannot be constant.
  static const String interpolated = 'with interpolations';

  /// The class holding the constants.
  static const String _className = 'DataKeys';

  /// The file declaring [_className], relative to `lib`.
  static const String _fileInLib = 'constants/data_keys.dart';

  /// Names a constant cannot take: members every class inherits.
  static const Set<String> _objectMembers = {
    'hashCode',
    'noSuchMethod',
    'runtimeType',
    'toString',
  };

  /// A constant [_declare] writes, with its `name` and quoted `value`.
  static final RegExp _declaration = RegExp(
    r"static const String (?<name>\w+) = '(?<value>(?:[^'\\]|\\.)*)';",
  );

  final CodeFormatter _formatter;

  final ProjectConfigReader _config;

  /// The strings [metrics] found in the project at [projectPath] that can
  /// become constants, for the user to pick from.
  Future<ConstantsPlan> plan(
    String projectPath,
    fcheck.ProjectMetrics metrics,
  ) async {
    final paths = ProjectPaths(projectPath);
    final packageName = await _config.packageName(projectPath);
    if (packageName == null) throw Exception('pubspec.yaml has no name');
    final found = await HardcodedStringFinder.find(
      metrics,
      reject: (string) =>
          string.site.interpolations.isEmpty ? null : interpolated,
    );
    return ConstantsPlan(
      className: _className,
      constantsPath: p.join(paths.libDir, _fileInLib),
      importUri: 'package:$packageName/$_fileInLib',
      candidates: found.candidates,
      rejected: found.rejected,
      skipped: found.skipped,
    );
  }

  /// Declares a constant for each value of the [selected] strings of
  /// [plan], reusing ones already declared, and replaces the strings with
  /// references to them.
  Future<StringRewrite> apply(
    ConstantsPlan plan,
    Iterable<HardcodedString> selected,
  ) async {
    final constantsFile = File(plan.constantsPath);
    final existing = await constantsFile.exists()
        ? await constantsFile.readAsString()
        : null;
    final nameByValue = {
      for (final match in _declaration.allMatches(existing ?? ''))
        DartStringLiteral.valueOf(match.namedGroup('value')!): match.namedGroup(
          'name',
        )!,
    };
    final names = nameByValue.values.toSet();
    final added = <String, String>{};
    String nameFor(HardcodedString string) {
      final value = string.site.textParts.single;
      final known = nameByValue[value];
      if (known != null) return known;
      final name = uniqueName(
        safeIdentifier(
          string.message.keyBase,
          suffix: 'Key',
          reserved: _objectMembers,
        ),
        names.contains,
      );
      names.add(name);
      return nameByValue[value] = added[value] = name;
    }

    final (:byFile, :skipped) = HardcodedStringFinder.selection(
      plan.candidates,
      plan.skipped,
      selected,
    );

    var rewritten = 0;
    final changedFiles = <String>[];
    for (final MapEntry(key: path, value: strings) in byFile.entries) {
      final file = File(path);
      final original = await file.readAsString();
      final kept = <HardcodedString>[];
      for (final string in strings) {
        if (HardcodedStringFinder.isStringAt(original, string.site)) {
          kept.add(string);
        } else {
          HardcodedStringFinder.count(
            skipped,
            HardcodedStringFinder.changedFile,
          );
        }
      }
      if (kept.isEmpty) continue;
      // Named from the end of the file, so the names are the same each run
      kept.sort((a, b) => b.site.offset - a.site.offset);
      final content = withImport(
        TextOffsets.applyEdits(original, {
          for (final string in kept)
            string.site.offset: (
              string.site.length,
              '${plan.className}.${nameFor(string)}',
            ),
        }),
        plan.importUri,
        isImported: (uri) => p.url.basename(uri) == p.basename(_fileInLib),
      );
      await file.writeAsString(content);
      changedFiles.add(path);
      rewritten += kept.length;
    }

    if (added.isNotEmpty) {
      await constantsFile.parent.create(recursive: true);
      await constantsFile.writeAsString(
        _declare(existing, plan.className, added),
      );
      changedFiles.add(plan.constantsPath);
    }
    // Once for all files, rather than a formatter run per file
    await _formatter.formatFiles(changedFiles);
    return StringRewrite(
      action: 'Made constants of',
      rewritten: rewritten,
      changedFiles: changedFiles,
      skipped: skipped,
    );
  }

  /// The constants file [existing] (a new one declaring [className] when
  /// null) with a field for each value → name of [added], by name.
  static String _declare(
    String? existing,
    String className,
    Map<String, String> added,
  ) {
    final fields = [
      for (final MapEntry(key: value, value: name)
          in added.entries.toList()..sort((a, b) => a.value.compareTo(b.value)))
        "  /// The `${value.replaceAll('`', "'")}` data id.\n"
            '  static const String $name = ${DartStringLiteral.quote(value)};',
    ].join('\n\n');
    if (existing == null) {
      return '/// Identifiers the app uses as data, such as Firestore '
          'collection and\n/// field names: named once here and never '
          'translated.\nclass $className {\n  $className._();\n\n$fields\n}\n';
    }
    final end = existing.lastIndexOf('}');
    return '${existing.substring(0, end).trimRight()}\n\n$fields\n}\n';
  }
}
