import 'package:analyzer/dart/ast/ast.dart';
import 'package:fide/models/dart_parse.dart';
import 'package:path/path.dart' as p;

/// The scheme every package library URI starts with.
const String packageScheme = 'package:';

/// The scheme of the Dart SDK's libraries.
const String _dartScheme = 'dart:';

/// The keyword starting an export directive.
const String _exportKeyword = 'export';

/// The keyword starting a part directive.
const String _partKeyword = 'part ';

/// The quoted URI of a directive line, in group 1.
final RegExp _quotedUri = RegExp(r"'([^']*)'");

/// Sort groups of [_uriOrder]: `dart:` URIs, `package:` ones, then
/// relative ones.
const String _dartUriGroup = '0';
const String _packageUriGroup = '1';
const String _relativeUriGroup = '2';

/// The `package:` URI of [packageName]'s file at [pathInLib], a path
/// relative to the package's `lib` folder, with `/` separators on every
/// platform.
String packageUriOf(String packageName, String pathInLib) =>
    '$packageScheme$packageName/${p.url.joinAll(p.split(pathInLib))}';

/// The relative URI the Dart file at [from] imports the file at [target]
/// with, with `/` separators on every platform.
String relativeUriOf(String target, {required String from}) =>
    p.url.joinAll(p.split(p.relative(target, from: p.dirname(from))));

/// Dart [content] importing [importUri] (see [withDirective]); unchanged
/// when an import already satisfies [isImported].
String withImport(
  String content,
  String importUri, {
  required bool Function(String) isImported,
}) {
  final imports = parseDart(content).unit.directives
      .whereType<ImportDirective>();
  if (imports.any((import) => isImported(import.uri.stringValue ?? ''))) {
    return content;
  }
  return withDirective(content, "import '$importUri';");
}

/// Dart [content] with the directive [line] (an import, export or part)
/// in URI order among the directives of its kind, `dart:` first, then
/// `package:`, then relative ones, as the `directives_ordering` lint
/// expects; else after the last directive it may follow, else at the top.
String withDirective(String content, String line) {
  final directives = parseDart(content).unit.directives;
  final isPart = line.startsWith(_partKeyword);
  if (!isPart) {
    final isExport = line.startsWith(_exportKeyword);
    final peers = directives
        .whereType<NamespaceDirective>()
        .where((d) => (d is ExportDirective) == isExport)
        .toList();
    final key = _lineOrder(line);
    final next = peers
        .where((d) => _uriOrder(d.uri.stringValue ?? '').compareTo(key) > 0)
        .firstOrNull;
    if (next != null) {
      return content.replaceRange(next.offset, next.offset, '$line\n');
    }
    if (peers.isNotEmpty) {
      return content.replaceRange(peers.last.end, peers.last.end, '\n$line');
    }
  }
  final anchor = isPart
      ? directives.lastOrNull
      : directives.where((d) => d is! PartDirective).lastOrNull;
  if (anchor != null) {
    return content.replaceRange(anchor.end, anchor.end, '\n$line');
  }
  final firstPart = directives.whereType<PartDirective>().firstOrNull;
  final offset = firstPart?.offset ?? 0;
  return content.replaceRange(offset, offset, '$line\n\n');
}

/// Orders the directive lines [a] and [b] as [withDirective] places them.
int compareDirectiveLines(String a, String b) =>
    _lineOrder(a).compareTo(_lineOrder(b));

/// Sort key of the directive [line], by its quoted URI.
String _lineOrder(String line) =>
    _uriOrder(_quotedUri.firstMatch(line)?.group(1) ?? '');

/// Sort key of [uri] in [withDirective]'s order: its group, then the URI.
String _uriOrder(String uri) {
  final group = uri.startsWith(_dartScheme)
      ? _dartUriGroup
      : uri.startsWith(packageScheme)
      ? _packageUriGroup
      : _relativeUriGroup;
  return '$group$uri';
}
