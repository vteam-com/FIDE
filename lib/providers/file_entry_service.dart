import 'dart:io';

/// Creates, renames and deletes files and folders for the project trees.
///
/// Kept apart from the tree panels' dialogs so the file-system side can be
/// replaced in tests and reused without a `BuildContext`.
class FileEntryService {
  /// Creates a stateless service.
  const FileEntryService();

  /// Creates an empty file, or a folder when [isDirectory], at [targetPath],
  /// along with any missing parents.
  Future<void> create(String targetPath, {required bool isDirectory}) async {
    if (isDirectory) {
      await Directory(targetPath).create(recursive: true);
    } else {
      await File(targetPath).create(recursive: true);
    }
  }

  /// Deletes the file or folder (with its contents) at [entryPath].
  Future<void> delete(String entryPath, {required bool isDirectory}) async {
    if (isDirectory) {
      await Directory(entryPath).delete(recursive: true);
    } else {
      await File(entryPath).delete();
    }
  }

  /// Whether a file or folder already exists at [entryPath].
  bool exists(String entryPath) {
    return FileSystemEntity.typeSync(entryPath) !=
        FileSystemEntityType.notFound;
  }

  /// Moves the file or folder at [entryPath] to [newPath].
  Future<void> rename(
    String entryPath,
    String newPath, {
    required bool isDirectory,
  }) async {
    if (isDirectory) {
      await Directory(entryPath).rename(newPath);
    } else {
      await File(entryPath).rename(newPath);
    }
  }
}
