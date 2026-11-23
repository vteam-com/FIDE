import 'package:analyzer/dart/ast/ast.dart';
import 'package:fide/models/dart_imports.dart';
import 'package:fide/models/dart_parse.dart';
import 'package:fide/models/project_files.dart';
import 'package:fide/models/project_paths.dart';
import 'package:fide/models/text_offsets.dart';
import 'package:fide/services/file_content_reader.dart';
import 'package:path/path.dart' as p;

/// Lists the absolute paths of the Dart files of the project at a path.
typedef DartFileLister = Future<List<String>> Function(String projectPath);

/// Moves Dart files within a project, keeping every directive that names
/// them right, reading code without resolving it: the `import`, `export`
/// and `part` directives of the files moved, which now sit elsewhere, and
/// those of every other Dart file of the project (`lib`, `test`, `tool`…)
/// naming a moved file, by `package:` or relative URI.
///
/// A rewritten import or export moves to its place in URI order, as the
/// `directives_ordering` lint expects; a URI keeps its style and quotes.
/// Planning writes nothing: the caller writes the files and deletes the
/// moved ones.
class FileMover {
  /// Creates a mover reading files with [reader] and listing a project's
  /// Dart files with [listDartFiles].
  const FileMover({
    this.reader = const FileContentReader(),
    this.listDartFiles = _walk,
  });

  /// Lists the project's Dart files.
  final DartFileLister listDartFiles;

  /// Reads the files.
  final FileContentReader reader;

  /// The files to write to make [moves] (new project-relative path by
  /// current one, with `/` separators) in the project at [projectPath],
  /// by absolute path: each moved file at its new path, and every other
  /// Dart file whose directives name a moved file, rewritten. [packageName]
  /// is the project's, which its `package:` imports start with.
  ///
  /// Throws a [StateError], planning nothing, when a file to move is gone
  /// or another is at its new path.
  Future<Map<String, String>> plan(
    String projectPath,
    Map<String, String> moves, {
    String? packageName,
  }) async {
    final absolute = ProjectPaths(projectPath).absoluteOf;
    for (final MapEntry(key: from, value: to) in moves.entries) {
      if (!await reader.exists(absolute(from))) {
        throw StateError('$from is gone: check again');
      }
      if (await reader.exists(absolute(to))) {
        throw StateError('$to already exists');
      }
    }
    // Only a file whose text names a moved file can need a rewrite
    final names = {for (final from in moves.keys) p.posix.basename(from)};
    final contents = <String, String>{
      for (final from in moves.keys) from: await reader.read(absolute(from)),
    };
    for (final path in await listDartFiles(projectPath)) {
      final relative = ProjectPaths(projectPath).relativeOf(path);
      if (contents.containsKey(relative)) continue;
      final content = await reader.read(path);
      if (names.any(content.contains)) contents[relative] = content;
    }
    return {
      for (final MapEntry(key: path, value: content) in rewrite(
        contents,
        moves,
        packageName: packageName,
      ).entries)
        absolute(path): content,
    };
  }

  /// [contents], Dart files' text by project-relative path, rewritten for
  /// [moves] (new path by current one): each moved file at its new path,
  /// and each other file whose directives changed; a file left alone is
  /// left out.
  static Map<String, String> rewrite(
    Map<String, String> contents,
    Map<String, String> moves, {
    String? packageName,
  }) => {
    for (final MapEntry(key: path, value: content) in contents.entries)
      if (_Repointer(path, moves, packageName).rewrite(content)
          case final rewritten
          when moves.containsKey(path) || rewritten != content)
        moves[path] ?? path: rewritten,
  };

  /// The Dart files of the project at [projectPath], leaving out tool
  /// output and hidden folders.
  static Future<List<String>> _walk(String projectPath) async => [
    await for (final file in ProjectFiles.walk(
      projectPath,
      extension: ProjectFiles.dartExtension,
    ))
      file.path,
  ];
}

/// Points the directives of the file at [_from], moving to [_to], at
/// where the files they name are after [_moves].
class _Repointer {
  _Repointer(this._from, this._moves, this._packageName)
    : _to = _moves[_from] ?? _from;

  /// A run of blank lines more than one long.
  static final RegExp _blankLines = RegExp(r'\n{3,}');

  /// The blank line a run of them collapses to.
  static const String _blankLine = '\n\n';

  /// The line break a file ends with.
  static const String _lineBreak = '\n';

  final String _from;

  final Map<String, String> _moves;

  final String? _packageName;

  final String _to;

  /// The `package:` URI prefix of the project's own libraries; null
  /// without a package name.
  String? get _ownPrefix =>
      _packageName == null ? null : '$packageScheme$_packageName/';

  /// [content] with its directives naming moved files, or naming any
  /// file by a relative URI when it moves itself, pointed at their new
  /// place.
  String rewrite(String content) {
    final unit = parseDart(content).unit;
    final edits = <int, (int, String)>{};
    final placed = <String>[];
    for (final directive in unit.directives) {
      final literals = [
        if (directive case UriBasedDirective(:final uri)) uri,
        if (directive case PartOfDirective(:final uri?)) uri,
        if (directive case NamespaceDirective(:final configurations))
          for (final configuration in configurations) configuration.uri,
      ];
      final uris = {
        for (final literal in literals)
          literal: ?_repointed(literal.stringValue),
      };
      if (uris.isEmpty) continue;
      final line = (
        start: TextOffsets.lineStartOf(content, directive.offset),
        end: TextOffsets.lineEndAfter(content, directive.end),
      );
      final isOwnLine =
          content.substring(line.start, directive.offset).trim().isEmpty &&
          content.substring(directive.end, line.end).trim().isEmpty;
      if (directive is NamespaceDirective &&
          directive.configurations.isEmpty &&
          directive.metadata.isEmpty &&
          directive.documentationComment == null &&
          isOwnLine) {
        // Cut, then placed again in URI order
        final (literal, uri) = (uris.keys.single, uris.values.single);
        final start = literal.offset - directive.offset;
        placed.add(
          content
              .substring(directive.offset, directive.end)
              .replaceRange(
                start,
                start + literal.length,
                _quoted(content, literal, uri),
              ),
        );
        edits[line.start] = (line.end - line.start, '');
      } else {
        for (final MapEntry(key: literal, value: uri) in uris.entries) {
          edits[literal.offset] = (
            literal.length,
            _quoted(content, literal, uri),
          );
        }
      }
    }
    if (edits.isEmpty) return content;
    var result = TextOffsets.applyEdits(content, edits);
    for (final line in placed) {
      result = withDirective(result, line);
    }
    return _tidied(result);
  }

  /// [uri], named by the file at [_from], as the file at [_to] names the
  /// same file after the moves; null when it stays as written.
  String? _repointed(String? uri) {
    if (uri == null) return null;
    final ownPrefix = _ownPrefix;
    if (ownPrefix != null && uri.startsWith(ownPrefix)) {
      final target = p.posix.join(
        ProjectPaths.libFolder,
        uri.substring(ownPrefix.length),
      );
      final moved = _moves[target];
      if (moved == null) return null;
      return '$ownPrefix'
          '${p.posix.relative(moved, from: ProjectPaths.libFolder)}';
    }
    if (Uri.parse(uri).hasScheme) return null;
    final target = p.posix.normalize(p.posix.join(p.posix.dirname(_from), uri));
    final moved = _moves[target] ?? target;
    final repointed = p.posix.relative(moved, from: p.posix.dirname(_to));
    return repointed == uri ? null : repointed;
  }

  /// [uri] quoted as [literal] is in [content].
  static String _quoted(String content, StringLiteral literal, String uri) {
    final quote = content[literal.offset];
    return '$quote$uri$quote';
  }

  /// [content] with no run of blank lines among its directives, which a
  /// directive cut can leave.
  static String _tidied(String content) {
    final first = parseDart(content).unit.declarations.firstOrNull;
    // A file of directives only ends with one line break
    if (first == null) return '${content.trimRight()}$_lineBreak';
    return content
            .substring(0, first.offset)
            .replaceAll(_blankLines, _blankLine) +
        content.substring(first.offset);
  }
}
