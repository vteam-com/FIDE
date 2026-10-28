import 'package:flutter/material.dart';

/// An open document in the editor: its path, content, cursor and dirty flag.
///
/// Immutable; `OpenDocumentsNotifier` replaces it through [copyWith] so
/// everything watching the open documents sees each change.
@immutable
class DocumentState {
  final String filePath;
  final String content;
  final TextSelection selection;
  final bool isDirty;
  final dynamic language;

  /// Creates a document for [filePath].
  const DocumentState({
    required this.filePath,
    this.content = '',
    this.selection = const TextSelection.collapsed(offset: 0),
    this.isDirty = false,
    this.language,
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
    );
  }

  /// The file name without its directory.
  String get fileName {
    return filePath.split('/').last;
  }
}
