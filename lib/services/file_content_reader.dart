import 'dart:io';
import 'dart:typed_data';

/// Reads and writes the content of project files: text, refusing files
/// too big to edit, and bytes.
///
/// Kept apart from the tree models so they stay plain data, and next to
/// `FileEntryService`, which creates, renames and deletes the entries.
/// Notifiers and widgets go through it instead of `dart:io` so tests can
/// fake the disk.
class FileContentReader {
  /// Creates a stateless reader.
  const FileContentReader();

  /// The largest file read as text, in bytes.
  static const int maxFileSize = 1 * 1024 * 1024; // 1MB

  /// What [read] returns in place of a file over [maxFileSize].
  static const String tooBigMessage = '// file too big to load';

  /// Whether a file exists at [filePath].
  Future<bool> exists(String filePath) => File(filePath).exists();

  /// Whether the file at [filePath] is at most [maxFileSize] bytes.
  Future<bool> isWithinMaxSize(String filePath) async {
    return await File(filePath).length() <= maxFileSize;
  }

  /// The text of the file at [filePath], or [tooBigMessage] when it is
  /// over [maxFileSize].
  ///
  /// Throws a [FileSystemException] when it can't be read as UTF-8 text.
  Future<String> read(String filePath) async {
    return await tryRead(filePath) ?? tooBigMessage;
  }

  /// The bytes of the file at [filePath], whatever its size.
  ///
  /// Throws a [FileSystemException] when it is missing.
  Future<Uint8List> readBytes(String filePath) => File(filePath).readAsBytes();

  /// The text of the file at [filePath]; null when it is over
  /// [maxFileSize].
  ///
  /// Throws a [FileSystemException] when it can't be read as UTF-8 text.
  Future<String?> tryRead(String filePath) async {
    if (!await isWithinMaxSize(filePath)) return null;
    return File(filePath).readAsString();
  }

  /// Writes [content] as UTF-8 text to [filePath], creating its folders.
  Future<void> write(String filePath, String content) async {
    final file = File(filePath);
    await file.parent.create(recursive: true);
    await file.writeAsString(content);
  }

  /// [write] without waiting, for a caller that is closing and can't.
  void writeSync(String filePath, String content) {
    File(filePath)
      ..parent.createSync(recursive: true)
      ..writeAsStringSync(content);
  }
}
