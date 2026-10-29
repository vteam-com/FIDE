part of 'file_type_utils.dart';

/// How the editor opens a file.
enum FileOpening {
  /// In the code editor.
  text,

  /// In the image viewer.
  image,

  /// Not at all.
  none,
}

/// What FIDE knows about one file extension.
class FileTypeInfo {
  /// Which icon the file gets.
  final FileCategory category;

  /// How the editor opens it.
  final FileOpening opensAs;

  /// Syntax highlighting for text files; null means plain text.
  final Mode? language;

  /// Language name when it isn't the extension in capitals.
  final String? label;

  /// A file the code editor opens, highlighted as [language] when given.
  const FileTypeInfo.text(this.category, [this.language, this.label])
    : opensAs = FileOpening.text;

  /// An image the image viewer opens.
  const FileTypeInfo.image()
    : category = FileCategory.image,
      opensAs = FileOpening.image,
      language = null,
      label = null;

  /// A recognized file FIDE only shows an icon for.
  const FileTypeInfo.other(this.category)
    : opensAs = FileOpening.none,
      language = null,
      label = null;
}
