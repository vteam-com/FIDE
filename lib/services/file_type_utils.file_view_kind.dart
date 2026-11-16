part of 'file_type_utils.dart';

/// How the editor shows a file.
enum FileViewKind {
  /// In the code editor.
  code,

  /// In the image viewer.
  image,

  /// In the audio editor.
  audio,

  /// Not at all: the editor says it can't open it.
  unsupported;

  /// Whether the file is a picture or a sound, shown by its own viewer
  /// rather than read as text.
  bool get isMedia => this == image || this == audio;
}
