import 'package:fide/models/document_state.dart';
import 'package:fide/models/file_history.dart';

/// The editor's open tabs, which one is showing and the files shown
/// before it.
class OpenDocuments {
  /// No tabs open.
  static const OpenDocuments empty = OpenDocuments(documents: []);

  /// Value of [activeIndex] when no tab is showing.
  static const int noActiveDocument = -1;

  /// Open documents in tab order.
  final List<DocumentState> documents;

  /// Index of the showing tab in [documents], or [noActiveDocument].
  final int activeIndex;

  /// The files shown, for going back and forward through them.
  final FileHistory history;

  /// Creates the tab list [documents] showing [activeIndex], after the
  /// visits of [history].
  const OpenDocuments({
    required this.documents,
    this.activeIndex = noActiveDocument,
    this.history = FileHistory.empty,
  });

  /// The showing document, or null when none is.
  DocumentState? get active =>
      activeIndex >= 0 && activeIndex < documents.length
      ? documents[activeIndex]
      : null;

  /// The editor's text for [filePath], or null when it isn't open.
  String? contentOf(String filePath) {
    final index = indexOf(filePath);
    return index == noActiveDocument ? null : documents[index].content;
  }

  /// Index of the tab for [filePath], or [noActiveDocument] if not open.
  int indexOf(String filePath) =>
      documents.indexWhere((document) => document.filePath == filePath);
}
