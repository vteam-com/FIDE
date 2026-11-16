part of 'file_type_utils.dart';

/// How the editor shows a file.
enum FileViewKind {
  /// In the code editor.
  code,

  /// In the image viewer.
  image,

  /// In the audio editor.
  audio,

  /// In the font viewer.
  font,

  /// Not at all: the editor says it can't open it.
  unsupported;

  /// Whether the file is a picture, a sound or a font, shown by its own
  /// viewer rather than read as text.
  bool get isMedia => this == image || this == audio || this == font;

  /// Whether the editor can show the file's changes against Git: text
  /// side by side, images overlaid; sounds and fonts have no diff view.
  bool get hasDiffView => this == code || this == image;
}
