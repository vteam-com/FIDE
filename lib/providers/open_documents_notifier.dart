part of 'app_providers.dart';

/// The only writer of the editor's open documents and active tab.
class OpenDocumentsNotifier extends StateNotifier<OpenDocuments> {
  /// Starts with no documents open.
  OpenDocumentsNotifier() : super(OpenDocuments.empty);

  /// Shows the tab at [index].
  void activate(int index) {
    state = OpenDocuments(documents: state.documents, activeIndex: index);
  }

  /// Closes every tab.
  void closeAll() {
    state = OpenDocuments.empty;
  }

  /// Hides the editor while keeping the tabs open.
  void deactivate() => activate(OpenDocuments.noActiveDocument);

  /// Shows [filePath], loading it into a new tab unless it is already open.
  Future<void> open(String filePath) async {
    final existingIndex = state.indexOf(filePath);
    if (existingIndex != OpenDocuments.noActiveDocument) {
      activate(existingIndex);
      return;
    }

    final document = DocumentState(
      filePath: filePath,
      content: await _readContent(filePath),
      language: FileTypeUtils.languageForFile(filePath),
    );
    final documents = [...state.documents, document];
    state = OpenDocuments(
      documents: documents,
      activeIndex: documents.length - 1,
    );
  }

  /// Writes [content] to [filePath] and records it as the clean, saved
  /// content of its document.
  Future<void> save(String filePath, String content) async {
    await File(filePath).writeAsString(content);
    update(filePath, content: content, isDirty: false);
  }

  /// Writes [content] to [filePath] immediately without changing state,
  /// for an editor that is closing and can neither wait nor notify.
  void saveOnClose(String filePath, String content) {
    File(filePath).writeAsStringSync(content);
  }

  /// Records the editor's latest [content], [selection] and [isDirty] for
  /// [filePath]; does nothing when nothing changed.
  void update(
    String filePath, {
    String? content,
    TextSelection? selection,
    bool? isDirty,
  }) {
    final index = state.indexOf(filePath);
    if (index == OpenDocuments.noActiveDocument) return;

    final current = state.documents[index];
    final updated = current.copyWith(
      content: content,
      selection: selection,
      isDirty: isDirty,
    );
    if (updated.content == current.content &&
        updated.selection == current.selection &&
        updated.isDirty == current.isDirty) {
      return;
    }
    state = OpenDocuments(
      documents: [...state.documents]..[index] = updated,
      activeIndex: state.activeIndex,
    );
  }

  /// Text content of [filePath]; empty for images and missing files.
  Future<String> _readContent(String filePath) async {
    if (FileTypeUtils.isImageFile(filePath)) return '';
    try {
      final file = File(filePath);
      if (!await file.exists()) return '';
      return await FileSystemItem.fileToStringMaxSizeCheck(file);
    } catch (_) {
      return '// Error loading file\n';
    }
  }
}
