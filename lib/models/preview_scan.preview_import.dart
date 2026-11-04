part of 'preview_scan.dart';

/// An import directive of a scanned file, kept so the preview host can
/// import the same libraries the file's previews use.
@immutable
class PreviewImport {
  /// The directive's source, such as `import 'a.dart' as a;`.
  final String source;

  /// Each URI of the directive (its own, then its conditional ones), with
  /// the offsets of its string literal in [source].
  final List<({int start, int end, String uri})> uris;

  /// Creates the import.
  const PreviewImport({required this.source, required this.uris});

  /// The directive's main URI.
  String get uri => uris.first.uri;

  /// [source] with each URI replaced by what [resolve] returns for it.
  String rewritten(String Function(String uri) resolve) {
    var result = source;
    for (final literal in uris.reversed) {
      result = result.replaceRange(
        literal.start,
        literal.end,
        "'${resolve(literal.uri)}'",
      );
    }
    return result;
  }
}
