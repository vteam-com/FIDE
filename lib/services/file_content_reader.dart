import 'dart:io';

/// Reads project files as text, refusing those too big to edit.
///
/// Kept apart from the tree models so they stay plain data, and next to
/// `FileEntryService`, which creates, renames and deletes the entries.
class FileContentReader {
  /// Creates a stateless reader.
  const FileContentReader();

  /// The largest file read as text, in bytes.
  static const int maxFileSize = 1 * 1024 * 1024; // 1MB

  /// What [read] returns in place of a file over [maxFileSize].
  static const String tooBigMessage = '// file too big to load';

  /// Whether the file at [filePath] is at most [maxFileSize] bytes.
  Future<bool> isWithinMaxSize(String filePath) async {
    return await File(filePath).length() <= maxFileSize;
  }

  /// The text of the file at [filePath]; null when it is over
  /// [maxFileSize].
  ///
  /// Throws a [FileSystemException] when it can't be read as UTF-8 text.
  Future<String?> tryRead(String filePath) async {
    if (!await isWithinMaxSize(filePath)) return null;
    return File(filePath).readAsString();
  }

  /// The text of the file at [filePath], or [tooBigMessage] when it is
  /// over [maxFileSize].
  ///
  /// Throws a [FileSystemException] when it can't be read as UTF-8 text.
  Future<String> read(String filePath) async {
    return await tryRead(filePath) ?? tooBigMessage;
  }
}
