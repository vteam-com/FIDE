import 'package:fide/models/arb_keys.dart';
import 'package:fide/models/dart_imports.dart';
import 'package:fide/models/hardcoded_string.dart';
import 'package:fide/models/l10n_config.dart';
import 'package:fide/models/lookup_field.dart';
import 'package:path/path.dart' as p;

/// Parameter name of the lookup functions passed to a [LookupField].
const String _l10n = 'l10n';

/// The `const` keyword with the spaces after it.
final RegExp _constKeyword = RegExp(r'const\s+');

/// Turns [LookupField]s into lookup functions: each field's `String` type
/// becomes `String Function(AppLocalizations l10n)`, each read calls it
/// with the localizations of the `BuildContext` there, each hardcoded
/// string passed to it becomes a lookup of its ARB key, and each other
/// value is passed through as `(_) => value`.
///
/// A read passed straight to another of the fields stays as is: it already
/// is a lookup function.
class LookupRewrite {
  /// Creates the rewrite of [fields] in [contents], the current text of
  /// every file they touch.
  const LookupRewrite({
    required this.fields,
    required this.contents,
    required this.config,
    required this.importUri,
  });

  /// The project's gen-l10n settings.
  final L10nConfig config;

  /// Current text of every file the fields touch, by absolute path.
  final Map<String, String> contents;

  /// The fields to turn into lookup functions.
  final List<LookupField> fields;

  /// Import of the generated localizations class.
  final String importUri;

  /// Whether [argument] is a read of one of the fields, passing its lookup
  /// function on as is.
  bool _isForwarding(LookupFieldArgument argument) =>
      fields.any((field) => field.reads.any((read) => _isSame(argument, read)));

  /// Whether [read] is passed as is to one of the fields.
  bool _isForwarded(LookupFieldRead read) => fields.any(
    (field) => field.arguments.any((argument) => _isSame(argument, read)),
  );

  /// Whether [argument] is exactly [read].
  static bool _isSame(LookupFieldArgument argument, LookupFieldRead read) =>
      argument.path == read.path &&
      argument.offset == read.offset &&
      argument.offset + argument.length == read.end;

  /// Every changed file's new text, the hardcoded [strings] passed to the
  /// fields replaced by lookups under keys from [keys]; with how many were.
  ({Map<String, String> contents, int localized}) apply(
    Iterable<HardcodedString> strings,
    ArbKeys keys,
  ) {
    final byLocation = {
      for (final string in strings) (string.path, string.site.offset): string,
    };
    // Path → offset → (length, replacement), applied from the end
    final edits = <String, Map<int, (int, String)>>{};
    void edit(String path, int offset, int length, String text) =>
        (edits[path] ??= {})[offset] = (length, text);

    var localized = 0;
    for (final field in {for (final f in fields) f.id: f}.values) {
      edit(
        field.path,
        field.typeOffset,
        field.typeLength,
        'String Function(${config.outputClass} $_l10n)',
      );
      for (final argument in field.arguments) {
        if (_isForwarding(argument)) continue;
        final string = byLocation[(argument.path, argument.offset)];
        if (string == null) {
          edit(
            argument.path,
            argument.offset,
            argument.length,
            '(_) => ${argument.source}',
          );
          continue;
        }
        final key = keys.keyFor(string.message);
        edit(
          argument.path,
          argument.offset,
          argument.length,
          '($_l10n) => ${string.message.lookup(_l10n, key)}',
        );
        final content = contents[argument.path]!;
        for (final offset in string.site.constKeywordOffsets) {
          final match = _constKeyword.matchAsPrefix(content, offset);
          if (match != null) {
            edit(argument.path, offset, match.end - offset, '');
          }
        }
        localized++;
      }
      for (final read in field.reads) {
        if (!_isForwarded(read)) {
          edit(read.path, read.end, 0, '(${config.lookup(read.contextName)})');
        }
      }
    }

    final changed = <String, String>{};
    for (final MapEntry(key: path, value: fileEdits) in edits.entries) {
      var result = contents[path]!;
      for (final offset in fileEdits.keys.toList()..sort((a, b) => b - a)) {
        final (length, text) = fileEdits[offset]!;
        result = result.replaceRange(offset, offset + length, text);
      }
      final declares = fields.any((field) => field.path == path);
      changed[path] = declares
          ? withImport(
              result,
              importUri,
              isImported: (uri) => p.url.basename(uri) == config.outputFile,
            )
          : result;
    }
    return (contents: changed, localized: localized);
  }
}
