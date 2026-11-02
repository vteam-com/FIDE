part of 'file_type_utils.dart';

/// How the editor shows a file.
enum FileViewKind {
  /// In the code editor.
  code,

  /// In the image viewer.
  image,

  /// Not at all: the editor says it can't open it.
  unsupported,
}
