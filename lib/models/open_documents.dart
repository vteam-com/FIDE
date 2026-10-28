import 'package:fide/models/document_state.dart';

/// The editor's open tabs and which one is showing.
class OpenDocuments {
  /// No tabs open.
  static const OpenDocuments empty = OpenDocuments(documents: []);

  /// Value of [activeIndex] when no tab is showing.
  static const int noActiveDocument = -1;

  /// Open documents in tab order.
  final List<DocumentState> documents;

  /// Index of the showing tab in [documents], or [noActiveDocument].
  final int activeIndex;

  /// Creates the tab list [documents] showing [activeIndex].
  const OpenDocuments({
    required this.documents,
    this.activeIndex = noActiveDocument,
  });

  /// The showing document, or null when none is.
  DocumentState? get active =>
      activeIndex >= 0 && activeIndex < documents.length
      ? documents[activeIndex]
      : null;

  /// Index of the tab for [filePath], or [noActiveDocument] if not open.
  int indexOf(String filePath) =>
      documents.indexWhere((document) => document.filePath == filePath);
}
