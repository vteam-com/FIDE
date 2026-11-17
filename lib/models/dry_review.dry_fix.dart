part of 'dry_review.dart';

/// A deterministic fix of a [DryFinding], such as using a constant for a
/// number: the [edits] it makes across the project and the files it
/// [created], with its [label].
///
/// A fix extracting a shared widget leaves its name to the user: its
/// code says [widgetName] and [widgetFile] until [named] fills them in.
class DryFix {
  /// Creates the fix named [label] making [edits] and adding the [created]
  /// files, its widget named after [nameHint] when it has one to name.
  const DryFix(
    this.label,
    this.edits, {
    this.created = const {},
    this.nameHint,
  });

  /// The fix of every one of [fixes] at once, named [label].
  DryFix.all(this.label, Iterable<DryFix> fixes)
    : edits = [for (final fix in fixes) ...fix.edits],
      created = {for (final fix in fixes) ...fix.created},
      nameHint = null;

  /// Placeholder for the name of the widget the fix extracts.
  static const String widgetName = r'$WidgetName$';

  /// Placeholder for the file stem of the widget the fix extracts.
  static const String widgetFile = r'$widget_file$';

  /// The files the fix adds, by project-relative path.
  final Map<String, String> created;

  /// The replacements, in any order.
  final List<DryEdit> edits;

  /// What the fix does, as its button says: `Use AppIconSize.large`.
  final String label;

  /// The name proposed for the widget the fix extracts; null when it
  /// extracts none.
  final String? nameHint;

  /// Project-relative paths of the files the fix edits.
  Set<String> get paths => {for (final edit in edits) edit.path};

  /// The fix with its widget called [name], in a file named after it.
  DryFix named(String name) {
    final file = ProjectName.normalize(name) ?? name;
    String fill(String text) =>
        text.replaceAll(widgetName, name).replaceAll(widgetFile, file);
    return DryFix(
      fill(label),
      [
        for (final edit in edits)
          DryEdit(
            edit.path,
            edit.offset,
            edit.original,
            fill(edit.replacement),
            importUri: switch (edit.importUri) {
              final uri? => fill(uri),
              null => null,
            },
          ),
      ],
      created: {
        for (final MapEntry(key: path, value: content) in created.entries)
          fill(path): fill(content),
      },
    );
  }

  /// [contents], the files' code by project-relative path, with the fix's
  /// edits made and the imports they need added, plus the files it
  /// creates, and how many edits were made: an edit inside one already
  /// made is left out, its code being rewritten.
  ///
  /// Throws a [StateError], changing nothing, when a file no longer has
  /// an edit's original code where the review found it.
  ({Map<String, String> contents, int count}) applyTo(
    Map<String, String> contents,
  ) {
    final edited = <String, String>{...created};
    var count = 0;
    for (final path in paths) {
      final content = contents[path]!;
      final edits =
          [
            for (final edit in this.edits)
              if (edit.path == path) edit,
          ]..sort(
            (a, b) => a.offset != b.offset
                ? a.offset - b.offset
                : b.original.length - a.original.length,
          );
      final kept = <DryEdit>[];
      for (final edit in edits) {
        if (kept.isNotEmpty && edit.offset < kept.last.end) continue;
        if (edit.end > content.length ||
            content.substring(edit.offset, edit.end) != edit.original) {
          throw StateError('$path changed since the review: check again');
        }
        kept.add(edit);
      }
      var result = TextOffsets.applyEdits(content, {
        for (final edit in kept)
          edit.offset: (edit.original.length, edit.replacement),
      });
      for (final uri in {for (final edit in kept) ?edit.importUri}) {
        result = withImport(result, uri, isImported: (other) => other == uri);
      }
      edited[path] = result;
      count += kept.length;
    }
    return (contents: edited, count: count);
  }
}
