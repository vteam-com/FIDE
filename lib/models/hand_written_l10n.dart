/// Code written by hand into a generated localizations file, cut out by
/// `HandWrittenL10nParser` so it survives `flutter gen-l10n`: static
/// members become top-level declarations, extensions and other
/// declarations move as they are.
class HandWrittenL10n {
  /// Creates the moved code and the names its callers must change.
  const HandWrittenL10n({
    required this.source,
    required this.staticNames,
    required this.topLevelNames,
    required this.extensionMembers,
  });

  /// Members of the moved extensions, used as `context.member`.
  final List<String> extensionMembers;

  /// The moved code, as top-level declarations.
  final String source;

  /// Static members turned top-level, used as `Class.name` until now.
  final List<String> staticNames;

  /// Moved top-level declarations, used by their name.
  final List<String> topLevelNames;
}
