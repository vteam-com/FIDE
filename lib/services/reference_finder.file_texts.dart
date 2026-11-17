part of 'reference_finder.dart';

/// The analyzed files of a project with their text, kept between
/// [ReferenceFinder] requests: a file is read again only once its
/// modification time changes, so a request doesn't re-read the project.
class FileTexts {
  /// Creates an empty cache reading the text of the file at a path through
  /// [_read], by default from disk.
  FileTexts([this._read = _readFile]);

  /// Last seen modification time of each known file.
  final Map<String, DateTime> _modified = {};

  final String Function(String path) _read;

  /// Text of the known files read since they last changed.
  final Map<String, String> _texts = {};

  /// The known files.
  Iterable<String> get paths => _modified.keys;

  /// Records that [path] was last modified at [modified]; true when it was
  /// known with another time, its text then read again on next use.
  bool update(String path, DateTime modified) {
    final previous = _modified[path];
    if (previous == modified) return false;
    _modified[path] = modified;
    _texts.remove(path);
    return previous != null;
  }

  /// Forgets [path], such as once it is deleted.
  void remove(String path) {
    _modified.remove(path);
    _texts.remove(path);
  }

  /// The known files whose text contains [name].
  List<String> mentioning(String name) => [
    for (final path in _modified.keys)
      if (_texts.putIfAbsent(path, () => _read(path)).contains(name)) path,
  ];

  /// [path]'s text, read from disk.
  static String _readFile(String path) => File(path).readAsStringSync();
}
