import 'dart:io';
import 'dart:math' as math;

import 'package:fide/models/document_state.dart';
import 'package:fide/models/file_history.dart';
import 'package:fide/models/open_documents.dart';
import 'package:fide/providers/active_editor.dart';
import 'package:fide/providers/service_providers.dart';
import 'package:fide/services/editor_commands.dart';
import 'package:fide/services/file_content_reader.dart';
import 'package:fide/services/file_type_utils.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:path/path.dart' as p;

/// The editor's open documents and active tab.
final openDocumentsProvider =
    StateNotifierProvider<OpenDocumentsNotifier, OpenDocuments>(
      (ref) => OpenDocumentsNotifier(
        onSaved: (filePaths) {
          ref.read(savedFilesRevisionProvider.notifier).state++;
          if (!filePaths.every(FileTypeUtils.isDartFile)) {
            ref.read(savedAssetsRevisionProvider.notifier).state++;
          }
        },
        activeEditor: ref.read(activeEditorProvider),
        reader: ref.read(fileContentReaderProvider),
      ),
    );

/// Bumped each time the editor saves a file, so views derived from file
/// contents can refresh.
final savedFilesRevisionProvider = StateProvider<int>((_) => 0);

/// Bumped like [savedFilesRevisionProvider], but only by saves that wrote
/// a file other than Dart source, so views derived from assets and
/// platform files (such as the app icons) don't refresh for code edits.
final savedAssetsRevisionProvider = StateProvider<int>((_) => 0);

/// The document showing in the editor, or null.
final activeDocumentProvider = Provider<DocumentState?>(
  (ref) => ref.watch(openDocumentsProvider).active,
);

/// The only writer of the editor's open documents and active tab.
class OpenDocumentsNotifier extends StateNotifier<OpenDocuments> {
  /// Starts with no documents open; calls [onSaved] after each [save] and
  /// saves the showing document through [activeEditor]; reads and writes
  /// files with [reader].
  OpenDocumentsNotifier({
    this.onSaved,
    this.activeEditor,
    this.reader = const FileContentReader(),
  }) : super(OpenDocuments.empty);

  /// Loads the text of the documents opened and writes their saves.
  final FileContentReader reader;

  /// Called with the files written after each [save] and
  /// [reloadWritten].
  final void Function(Iterable<String> filePaths)? onSaved;

  /// The mounted editor, which saves the showing document so it knows
  /// the document is saved; without it, that document saves as the others.
  final EditorCommands? activeEditor;

  /// Shows the tab at [index].
  void activate(int index) => _show(state.documents, index);

  /// Shows the file shown before the showing one, reopening it if closed.
  Future<void> goBack() => _revisit(state.history.back());

  /// Shows the file [goBack] left, reopening it if closed.
  Future<void> goForward() => _revisit(state.history.forward());

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
    await saveAll();
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
      await reader.write(path, content);
    }
    if (files.isNotEmpty) await reloadWritten(files.keys);
    return files;
  }

  /// Closes the showing tab, saving its unsaved edits first, and shows
  /// the tab after it (the one before when it was the last); hides the
  /// editor when no tab is left.
  Future<void> closeActive() async {
    final closing = state.active;
    if (closing == null) return;
    if (closing.isDirty) {
      final editor = activeEditor;
      if (editor == null) {
        await save(closing.filePath, closing.content);
      } else {
        await editor.save();
      }
    }
    // Looked up again: the tabs may have changed while saving
    final index = state.indexOf(closing.filePath);
    if (index == OpenDocuments.noActiveDocument) return;
    final kept = [...state.documents]..removeAt(index);
    _show(
      kept,
      kept.isEmpty
          ? OpenDocuments.noActiveDocument
          : math.min(index, kept.length - 1),
    );
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
    _show(
      kept,
      activePath == null
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
    onSaved?.call(filePaths);
  }

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
    _show(documents, documents.length - 1);
  }

  /// Shows the open [filePath], whose type the editor doesn't support, as
  /// plain text in the code editor; false, changing nothing, when it is
  /// not open, too big, or not UTF-8 text, so a save can't overwrite it.
  Future<bool> openAsPlainText(String filePath) async {
    final index = state.indexOf(filePath);
    if (index == OpenDocuments.noActiveDocument) return false;
    try {
      if (await reader.tryRead(filePath) == null) return false;
    } on FileSystemException {
      return false;
    }
    _show(
      [...state.documents]..[index] = state.documents[index].toPlainText(),
      state.activeIndex,
    );
    return true;
  }

  /// Writes [content] to [filePath] and records it as the clean, saved
  /// content of its document.
  Future<void> save(String filePath, String content) async {
    await reader.write(filePath, content);
    update(filePath, content: content, isDirty: false);
    onSaved?.call([filePath]);
  }

  /// Writes [content] to [filePath] immediately without changing state,
  /// for an editor that is closing and can neither wait nor notify.
  void saveOnClose(String filePath, String content) {
    reader.writeSync(filePath, content);
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
    if (updated == current) return;
    _show([...state.documents]..[index] = updated, state.activeIndex);
  }

  /// Shows [documents] at [activeIndex], recording the visit of the
  /// document showing then.
  void _show(List<DocumentState> documents, int activeIndex) {
    final next = OpenDocuments(documents: documents, activeIndex: activeIndex);
    state = OpenDocuments(
      documents: documents,
      activeIndex: activeIndex,
      history: state.history.visit(next.active?.filePath),
    );
  }

  /// Moves to [history]'s current visit, then shows its file: opening it
  /// records no visit, as that file is the current one already.
  Future<void> _revisit(FileHistory history) async {
    final path = history.current;
    if (path == null || history.index == state.history.index) return;
    state = OpenDocuments(
      documents: state.documents,
      activeIndex: state.activeIndex,
      history: history,
    );
    await open(path);
  }

  /// Saves every document with unsaved edits: the showing one through
  /// [activeEditor], the others (and that one without an editor) from
  /// their recorded content.
  Future<void> saveAll() async {
    if (state.active?.isDirty ?? false) await activeEditor?.save();
    for (final document in state.documents.where((d) => d.isDirty).toList()) {
      await save(document.filePath, document.content);
    }
  }

  /// Text content of [filePath]; empty for images, sounds and missing
  /// files.
  Future<String> _readContent(String filePath) async {
    if (FileTypeUtils.viewKindOf(filePath).isMedia) return '';
    try {
      if (!await reader.exists(filePath)) return '';
      return await reader.read(filePath);
    } catch (_) {
      return '// Error loading file\n';
    }
  }
}
