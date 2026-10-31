import 'dart:io';

import 'package:fcheck/fcheck.dart' as fcheck;
import 'package:fide/models/constants_plan.dart';
import 'package:fide/models/dart_imports.dart';
import 'package:fide/models/hardcoded_string.dart';
import 'package:fide/models/project_paths.dart';
import 'package:fide/models/pubspec.dart';
import 'package:fide/models/string_rewrite.dart';
import 'package:fide/models/unique_name.dart';
import 'package:fide/providers/code_formatter.dart';
import 'package:fide/providers/hardcoded_string_finder.dart';
import 'package:path/path.dart' as p;

/// Makes hardcoded strings that are data, such as Firestore collection and
/// field names, named constants in one class without AI: [plan] lists the
/// strings that can move, and [apply] declares the ones the user picked as
/// `static const String` fields, one per value, and refers to them.
///
/// fCheck does not report strings declared `const`, so the moved strings
/// stop counting as hardcoded.
class StringConstantsExtractor {
  /// Creates an extractor formatting through [_formatter].
  const StringConstantsExtractor(this._formatter);

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

  /// The strings [metrics] found in the project at [projectPath] that can
  /// become constants, for the user to pick from.
  Future<ConstantsPlan> plan(
    String projectPath,
    fcheck.ProjectMetrics metrics,
  ) async {
    final paths = ProjectPaths(projectPath);
    final packageName = (await Pubspec.read(paths.pubspec))?.name;
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
        _unquoted(match.namedGroup('value')!): match.namedGroup('name')!,
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

    var rewritten = 0;
    final changedFiles = <String>[];
    for (final MapEntry(key: path, value: strings) in byFile.entries) {
      final file = File(path);
      var content = await file.readAsString();
      final edits = <HardcodedString>[];
      for (final string in strings) {
        if (HardcodedStringFinder.isStringAt(content, string.site)) {
          edits.add(string);
        } else {
          HardcodedStringFinder.count(
            skipped,
            HardcodedStringFinder.changedFile,
          );
        }
      }
      if (edits.isEmpty) continue;
      edits.sort((a, b) => b.site.offset - a.site.offset);
      for (final string in edits) {
        content = content.replaceRange(
          string.site.offset,
          string.site.offset + string.site.length,
          '${plan.className}.${nameFor(string)}',
        );
      }
      content = withImport(
        content,
        plan.importUri,
        isImported: (uri) => p.url.basename(uri) == p.basename(_fileInLib),
      );
      await file.writeAsString(await _formatter.formatOrKeep(path, content));
      changedFiles.add(path);
      rewritten += edits.length;
    }

    if (added.isNotEmpty) {
      await constantsFile.parent.create(recursive: true);
      await constantsFile.writeAsString(
        await _formatter.formatOrKeep(
          constantsFile.path,
          _declare(existing, plan.className, added),
        ),
      );
    }
    return StringRewrite(
      action: 'Made constants of',
      rewritten: rewritten,
      changedFiles: [...changedFiles, if (added.isNotEmpty) plan.constantsPath],
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
            "  static const String $name = '${_quoted(value)}';",
    ].join('\n\n');
    if (existing == null) {
      return '/// Identifiers the app uses as data, such as Firestore '
          'collection and\n/// field names: named once here and never '
          'translated.\nclass $className {\n  $className._();\n\n$fields\n}\n';
    }
    final end = existing.lastIndexOf('}');
    return '${existing.substring(0, end).trimRight()}\n\n$fields\n}\n';
  }

  /// [value] escaped for a single-quoted Dart string.
  static String _quoted(String value) => value
      .replaceAll(r'\', r'\\')
      .replaceAll("'", r"\'")
      .replaceAll(r'$', r'\$')
      .replaceAll('\n', r'\n');

  /// The value of the single-quoted Dart string body [quoted].
  static String _unquoted(String quoted) => quoted.replaceAllMapped(
    RegExp(r'\\(.)'),
    (match) => match[1] == 'n' ? '\n' : match[1]!,
  );
}
