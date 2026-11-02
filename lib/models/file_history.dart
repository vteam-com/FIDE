/// The files the editor showed, in the order it showed them, and where
/// going back and forward through them stands, as in a web browser.
class FileHistory {
  /// Nothing shown yet.
  static const FileHistory empty = FileHistory._(paths: [], index: _noVisit);

  /// Most visits remembered; older ones are forgotten first.
  static const int maxLength = 100;

  /// Value of [index] while [paths] is empty.
  static const int _noVisit = -1;

  /// Shown files' paths, oldest first; a file shows once per visit.
  final List<String> paths;

  /// Index in [paths] of the visit showing now, or [_noVisit].
  final int index;

  const FileHistory._({required this.paths, required this.index});

  /// Whether an earlier visit is there to [back] to.
  bool get canGoBack => index > 0;

  /// Whether a later visit, left by [back], is there to go [forward] to.
  bool get canGoForward => index < paths.length - 1;

  /// The path of the visit showing now, or null before any.
  String? get current => index == _noVisit ? null : paths[index];

  /// The history one visit earlier; unchanged when there is none.
  FileHistory back() => canGoBack ? _at(index - 1) : this;

  /// The history one visit later; unchanged when there is none.
  FileHistory forward() => canGoForward ? _at(index + 1) : this;

  /// The history after showing [path], which forgets the visits [back]
  /// left; unchanged when [path] is null or already showing.
  FileHistory visit(String? path) {
    if (path == null || path == current) return this;
    final kept = [...paths.take(index + 1), path];
    final trimmed = kept.length > maxLength
        ? kept.sublist(kept.length - maxLength)
        : kept;
    return FileHistory._(paths: trimmed, index: trimmed.length - 1);
  }

  /// The same visits, standing at [newIndex].
  FileHistory _at(int newIndex) => FileHistory._(paths: paths, index: newIndex);
}
