import 'dart:io';

import 'package:fide/services/file_content_reader.dart';

/// A [FileContentReader] keeping the files in memory, by absolute path.
class FakeFileContentReader extends FileContentReader {
  /// The files' text, by absolute path.
  final Map<String, String> files = {};

  /// How many times [writeSync] was called.
  int syncWrites = 0;

  /// Whether [write] fails, as on a read-only disk.
  bool failWrites = false;

  @override
  Future<bool> exists(String filePath) async => files.containsKey(filePath);

  @override
  Future<String> read(String filePath) async => files[filePath]!;

  @override
  Future<void> write(String filePath, String content) async {
    if (failWrites) throw const FileSystemException('read only');
    files[filePath] = content;
  }

  @override
  void writeSync(String filePath, String content) {
    syncWrites++;
    files[filePath] = content;
  }
}
