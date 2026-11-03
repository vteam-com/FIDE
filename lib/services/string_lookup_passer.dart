import 'dart:io';

import 'package:fcheck/fcheck.dart' as fcheck;
import 'package:fide/models/arb_keys.dart';
import 'package:fide/models/hardcoded_string.dart';
import 'package:fide/models/localization_plan.dart';
import 'package:fide/models/lookup_field.dart';
import 'package:fide/models/lookup_plan.dart';
import 'package:fide/models/lookup_rewrite.dart';
import 'package:fide/models/string_rewrite.dart';
import 'package:fide/services/arb_service.dart';
import 'package:fide/services/code_formatter.dart';
import 'package:fide/services/l10n_generator.dart';
import 'package:fide/services/reference_finder.dart';
import 'package:fide/services/string_localizer.dart';

/// Localizes hardcoded strings passed, where no `BuildContext` is, to a
/// widget's `String` field, without AI: [plan] finds the field each fills
/// through the resolved analysis of [ReferenceFinder], and [apply] turns
/// the fields into lookup functions the widgets call with their context,
/// passes lookups of new ARB keys in place of the strings, regenerates the
/// localizations class, and keeps the change only if it compiles.
class StringLookupPasser {
  /// Creates a passer resolving through [_finder], regenerating through
  /// [_generator] and formatting through [_formatter].
  const StringLookupPasser(this._finder, this._generator, this._formatter);

  final ReferenceFinder _finder;

  final CodeFormatter _formatter;

  final L10nGenerator _generator;

  /// The strings [localization] cannot look up for lack of a
  /// `BuildContext` that fill a widget's `String` field which can become a
  /// lookup function, and why the others cannot.
  Future<LookupPlan> plan(LocalizationPlan localization) async {
    final candidates = <HardcodedString, LookupField>{};
    final rejected = <HardcodedString, String>{};
    for (final MapEntry(key: string, value: reason)
        in localization.rejected.entries) {
      if (reason != StringLocalizer.noContext ||
          string.role == fcheck.HardcodedStringRole.data ||
          string.role == fcheck.HardcodedStringRole.fragment) {
        continue;
      }
      try {
        candidates[string] = await _finder.lookupField(
          filePath: string.path,
          offset: string.site.offset,
        );
      } on Exception catch (e) {
        rejected[string] = _reason(e);
      }
    }
    return LookupPlan(candidates: candidates, rejected: rejected);
  }

  /// Turns the fields the [selected] strings of [lookups] fill into lookup
  /// functions, every string passed to them becoming a lookup; throws,
  /// changing nothing, when the result would not compile.
  Future<StringRewrite> apply(
    LocalizationPlan localization,
    LookupPlan lookups,
    Iterable<HardcodedString> selected,
  ) async {
    final fields = [for (final string in selected) lookups.candidates[string]!];
    final paths = {
      for (final field in fields) ...[
        field.path,
        for (final argument in field.arguments) argument.path,
        for (final read in field.reads) read.path,
      ],
    };
    final rewrite = LookupRewrite(
      fields: fields,
      contents: {
        for (final path in paths) path: await File(path).readAsString(),
      },
      config: localization.config,
      importUri: localization.importUri,
    );
    final projectPath = localization.projectPath;
    final config = localization.config;
    final arb = await StringLocalizer.readTemplate(projectPath, config);
    final keys = ArbKeys(arb);
    final result = rewrite.apply([
      ...localization.candidates,
      ...localization.rejected.keys,
    ], keys);
    final contents = {
      for (final MapEntry(key: path, value: content) in result.contents.entries)
        path: await _formatter.formatOrKeep(path, content),
    };

    // The lookups compile only once the keys are generated
    final template = File(StringLocalizer.templatePath(projectPath, config));
    final original = await template.readAsString();
    await template.writeAsString(ArbService.encode({...arb, ...keys.added}));
    await _generator.generateClasses(projectPath);
    try {
      await _finder.checkCompiles(contents, 'Passing lookups');
    } catch (_) {
      await template.writeAsString(original);
      await _generator.generateClasses(projectPath);
      rethrow;
    }
    for (final MapEntry(key: path, value: content) in contents.entries) {
      await File(path).writeAsString(content);
    }
    return StringRewrite(
      action: 'Localized',
      rewritten: result.localized,
      changedFiles: contents.keys.toList(),
      skipped: const {},
    );
  }

  /// The reason in the error [e] the analysis answered with.
  static String _reason(Exception e) =>
      '$e'.replaceFirst('Exception: ', '').replaceFirst('Bad state: ', '');
}
