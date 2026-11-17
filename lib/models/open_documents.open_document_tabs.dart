part of 'open_documents.dart';

/// The editor's tabs as its header shows them: the files open, in tab
/// order, and which one is showing; not their text or caret, so watching
/// it doesn't rebuild on each edit.
@immutable
class OpenDocumentTabs {
  /// Paths of the open files in tab order.
  final List<String> filePaths;

  /// Index of the showing tab in [filePaths], or
  /// [OpenDocuments.noActiveDocument].
  final int activeIndex;

  /// Creates the tabs of [filePaths] showing [activeIndex].
  const OpenDocumentTabs({required this.filePaths, required this.activeIndex});

  /// Whether [other] lists the same files showing the same one.
  @override
  bool operator ==(Object other) {
    return other is OpenDocumentTabs &&
        other.activeIndex == activeIndex &&
        listEquals(other.filePaths, filePaths);
  }

  @override
  int get hashCode => Object.hash(activeIndex, Object.hashAll(filePaths));
}
