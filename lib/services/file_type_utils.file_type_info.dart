part of 'file_type_utils.dart';

/// What FIDE knows about one file extension.
class FileTypeInfo {
  /// Which icon the file gets.
  final FileCategory category;

  /// How the editor shows it.
  final FileViewKind opensAs;

  /// Syntax highlighting for text files; null means plain text.
  final Mode? language;

  /// Language name when it isn't the extension in capitals.
  final String? label;

  /// A file the code editor opens, highlighted as [language] when given.
  const FileTypeInfo.text(this.category, [this.language, this.label])
    : opensAs = FileViewKind.code;

  /// An image the image viewer opens.
  const FileTypeInfo.image()
    : category = FileCategory.image,
      opensAs = FileViewKind.image,
      language = null,
      label = null;

  /// A recognized file FIDE only shows an icon for.
  const FileTypeInfo.other(this.category)
    : opensAs = FileViewKind.unsupported,
      language = null,
      label = null;
}
