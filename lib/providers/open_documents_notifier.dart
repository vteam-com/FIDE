part of 'app_providers.dart';

/// The only writer of the editor's open documents and active tab.
class OpenDocumentsNotifier extends StateNotifier<OpenDocuments> {
  /// Starts with no documents open; calls [onSaved] after each [save] and
  /// saves the showing document through [activeEditor]; reads files with
  /// [reader].
  OpenDocumentsNotifier({
    this.onSaved,
    this.activeEditor,
    this.reader = const FileContentReader(),
  }) : super(OpenDocuments.empty);

  /// Loads the text of the documents opened.
  final FileContentReader reader;

  /// Called after each [save] writes its file.
  final VoidCallback? onSaved;

  /// The mounted editor, which saves the showing document so it knows
  /// the document is saved; without it, that document saves as the others.
  final EditorCommands? activeEditor;

  /// Shows the tab at [index].
  void activate(int index) {
    state = OpenDocuments(documents: state.documents, activeIndex: index);
  }

  /// Applies a project-wide edit (a rename, a replace-all, a class
  /// split...), the one way such edits reach the disk.
  ///
  /// Every document with unsaved edits is saved first, so [edit] computes
  /// its changes from what the user sees and no editor later writes its
  /// buffer over them. The files [edit] returns, keyed by absolute path,
  /// are then written and [reloadWritten]; they are returned too.
  ///
  /// Throws, writing nothing, when one of them was edited again while
  /// [edit] ran.
  Future<Map<String, String>> applyEdits(
    Future<Map<String, String>> Function() edit,
  ) async {
    await _saveAll();
    final files = await edit();
    final editedMeanwhile = state.documents.where(
      (document) => document.isDirty && files.containsKey(document.filePath),
    );
    if (editedMeanwhile.isNotEmpty) {
      throw StateError(
        '${p.basename(editedMeanwhile.first.filePath)} was edited '
        'meanwhile, so nothing was changed',
      );
    }
    for (final MapEntry(key: path, value: content) in files.entries) {
      await File(path).writeAsString(content);
    }
    if (files.isNotEmpty) await reloadWritten(files.keys);
    return files;
  }

  /// Closes every tab.
  void closeAll() {
    state = OpenDocuments.empty;
  }

  /// Closes the tabs of [filePaths] that are open, then reopens the one
  /// that was showing, so it shows the files' current content.
  Future<void> reload(Iterable<String> filePaths) async {
    final paths = filePaths.toSet();
    final activePath = state.active?.filePath;
    final kept = [
      for (final document in state.documents)
        if (!paths.contains(document.filePath)) document,
    ];
    if (kept.length == state.documents.length) return;
    state = OpenDocuments(
      documents: kept,
      activeIndex: activePath == null
          ? OpenDocuments.noActiveDocument
          : kept.indexWhere((d) => d.filePath == activePath),
    );
    if (activePath != null && paths.contains(activePath)) {
      await open(activePath);
    }
  }

  /// [reload]s [filePaths] after something other than the editor wrote
  /// them, then calls [onSaved] so views derived from them refresh.
  Future<void> reloadWritten(Iterable<String> filePaths) async {
    await reload(filePaths);
    onSaved?.call();
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
    onSaved?.call();
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

  /// Saves every document with unsaved edits: the showing one through
  /// [activeEditor], the others (and that one without an editor) from
  /// their recorded content.
  Future<void> _saveAll() async {
    if (state.active?.isDirty ?? false) await activeEditor?.save();
    for (final document in state.documents.where((d) => d.isDirty).toList()) {
      await save(document.filePath, document.content);
    }
  }

  /// Text content of [filePath]; empty for images and missing files.
  Future<String> _readContent(String filePath) async {
    if (FileTypeUtils.isImageFile(filePath)) return '';
    try {
      final file = File(filePath);
      if (!await file.exists()) return '';
      return await reader.read(filePath);
    } catch (_) {
      return '// Error loading file\n';
    }
  }
}
