import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:re_highlight/languages/plaintext.dart';
import 'package:re_highlight/re_highlight.dart';

/// An open document in the editor: its path, content, cursor and dirty flag.
///
/// Immutable; `OpenDocumentsNotifier` replaces it through [copyWith] so
/// everything watching the open documents sees each change. Equal by
/// value, so a provider deriving one notifies only when it changes.
@immutable
class DocumentState {
  final String filePath;
  final String content;
  final TextSelection selection;
  final bool isDirty;

  /// The syntax highlighting language; null to pick it from the file
  /// name.
  final Mode? language;

  /// Whether the user chose to edit this file as plain text although the
  /// editor doesn't support its type.
  final bool asPlainText;

  /// Creates a document for [filePath].
  const DocumentState({
    required this.filePath,
    this.content = '',
    this.selection = const TextSelection.collapsed(offset: 0),
    this.isDirty = false,
    this.language,
    this.asPlainText = false,
  });

  /// Returns a copy with the given fields replaced.
  DocumentState copyWith({
    String? content,
    TextSelection? selection,
    bool? isDirty,
  }) {
    return DocumentState(
      filePath: filePath,
      content: content ?? this.content,
      selection: selection ?? this.selection,
      isDirty: isDirty ?? this.isDirty,
      language: language,
      asPlainText: asPlainText,
    );
  }

  /// A copy shown in the code editor as unhighlighted plain text.
  DocumentState toPlainText() {
    return DocumentState(
      filePath: filePath,
      content: content,
      selection: selection,
      isDirty: isDirty,
      language: langPlaintext,
      asPlainText: true,
    );
  }

  /// Whether [other] is the same document in the same state; the texts
  /// are compared by identity first, as an unchanged document keeps its
  /// text object.
  @override
  bool operator ==(Object other) {
    return other is DocumentState &&
        other.filePath == filePath &&
        other.selection == selection &&
        other.isDirty == isDirty &&
        other.language == language &&
        other.asPlainText == asPlainText &&
        (identical(other.content, content) || other.content == content);
  }

  /// Hashes the text by its length, so equal documents hash alike without
  /// a pass over the text.
  @override
  int get hashCode => Object.hash(
    filePath,
    content.length,
    selection,
    isDirty,
    language,
    asPlainText,
  );
}
