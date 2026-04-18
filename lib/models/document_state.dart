import 'package:flutter/material.dart';

/// Represents an open document in the editor, including its path, content, cursor state, and dirty flag.
class DocumentState {
  final String filePath;
  String content;
  TextSelection selection;
  bool isDirty;
  dynamic language;

  DocumentState({
    required this.filePath,
    this.content = '',
    this.selection = const TextSelection.collapsed(offset: 0),
    this.isDirty = false,
    this.language,
  });

  // Create a copy with updated fields
  /// Handles `DocumentState.copyWith`.
  DocumentState copyWith({
    String? filePath,
    String? content,
    TextSelection? selection,
    bool? isDirty,
    dynamic language,
  }) {
    return DocumentState(
      filePath: filePath ?? this.filePath,
      content: content ?? this.content,
      selection: selection ?? this.selection,
      isDirty: isDirty ?? this.isDirty,
      language: language ?? this.language,
    );
  }

  // Get the file name from path
  /// Returns `fileName`.
  String get fileName {
    return filePath.split('/').last;
  }
}
