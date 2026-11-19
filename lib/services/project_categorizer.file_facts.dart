part of 'project_categorizer.dart';

/// What [ProjectCategorizer] looks for in a file's content, worked out
/// once and kept while the file keeps its date and size.
class _FileFacts {
  /// Reads the facts of [content], the file at [path] as [stat]
  /// describes it.
  _FileFacts(String path, String content, FileStat stat)
    : modified = stat.modified,
      size = stat.size,
      isApp = content.contains('MaterialApp('),
      declaresWidget = _declaresWidget(content),
      showsDialog = content.contains('showDialog'),
      arbEntries = path.endsWith(ArbService.arbExtension)
          ? ArbService.countEntries(content)
          : null;

  /// When the file was modified as read.
  final DateTime modified;

  /// The file's size in bytes as read.
  final int size;

  /// Whether the file builds an app (`MaterialApp(`), making it a view.
  final bool isApp;

  /// Whether the file declares a widget subclass.
  final bool declaresWidget;

  /// Whether the file calls `showDialog`.
  final bool showsDialog;

  /// Translatable entries, for an ARB file; null for other files and
  /// when not valid ARB.
  final int? arbEntries;

  /// Whether these facts still describe the file [stat] describes.
  bool isCurrent(FileStat stat) =>
      stat.modified == modified && stat.size == size;

  /// Whether [content] declares a class extending a `...Widget` type.
  ///
  /// fCheck's public results don't say which files declare widgets yet.
  static bool _declaresWidget(String content) {
    return RegExp(r'class\s+(\w+)\s+extends\s+(\w+)')
        .allMatches(content)
        .any(
          (match) => match
              .group(AppMetric.regexBaseClassGroupIndex)!
              .endsWith('Widget'),
        );
  }
}
