part of 'preview_scan.dart';

/// An import or export directive of a scanned file: the preview host
/// imports the same libraries as the file's previews, and the libraries
/// it names tell which classes a generated preview can build.
@immutable
class PreviewDirective {
  /// The directive's source, such as `import 'a.dart' as a;`.
  final String source;

  /// Each URI of the directive (its own, then its conditional ones), with
  /// the offsets of its string literal in [source].
  final List<({int start, int end, String uri})> uris;

  /// The prefix of an `import ... as prefix`; null without one.
  final String? prefix;

  /// The only names a `show` lets through; null for every name.
  final Set<String>? shown;

  /// The names a `hide` leaves out.
  final Set<String> hidden;

  /// Creates the directive.
  const PreviewDirective({
    required this.source,
    required this.uris,
    this.prefix,
    this.shown,
    this.hidden = const {},
  });

  /// The directive's main URI.
  String get uri => uris.first.uri;

  /// Whether the directive lets [name] through its `show` and `hide`.
  bool shows(String name) =>
      (shown?.contains(name) ?? true) && !hidden.contains(name);

  /// [source] with each URI replaced by what [resolve] returns for it.
  String rewritten(String Function(String uri) resolve) =>
      TextOffsets.applyEdits(source, {
        for (final literal in uris)
          literal.start: (
            literal.end - literal.start,
            "'${resolve(literal.uri)}'",
          ),
      });
}
