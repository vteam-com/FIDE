import 'dart:io';

/// A file's modification time and size: while both stay the same, what was
/// read from the file still describes it.
typedef FileStamp = ({DateTime modified, int size});

/// The [FileStamp] of a file's [FileStat].
extension FileStatStamp on FileStat {
  /// This file's modification time and size.
  FileStamp get stamp => (modified: modified, size: size);
}
