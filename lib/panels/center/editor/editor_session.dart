import 'dart:async';

import 'package:code_forge/code_forge.dart';
import 'package:fide/models/document_state.dart';
import 'package:fide/models/editor_diff_outcome.dart';
import 'package:fide/providers/app_providers.dart';
import 'package:fide/services/code_formatter.dart';
import 'package:fide/services/dart_language_server.dart';
import 'package:fide/services/git_service.dart';
import 'package:flutter/widgets.dart';
import 'package:logging/logging.dart';

/// The text of one editor and what happens to it: the document loaded in
/// its [code] controller, whether it is dirty against [savedText], and
/// its saves, formatting and git diff. Every edit is published to the
/// open documents; a caret move is not, as it changes no text: the caret
/// is published when the session leaves the file (see [load] and
/// [dispose]). Listeners are told of each change.
///
/// With a Dart language server, each Dart file of the project loaded is
/// shown to it, which then completes and checks the text as typed.
class EditorSession extends ChangeNotifier {
  /// Creates a session publishing to the open documents, formatting with
  /// the code formatter, diffing against HEAD with the git service, and
  /// showing its Dart files to [languageServer] when there is one.
  EditorSession({
    required this._documents,
    required this._formatter,
    required this._git,
    DartLanguageServer? languageServer,
  }) : _languageServer = languageServer,
       code = CodeForgeController(lspConfig: languageServer?.config) {
    // Opening a file, CodeForge would show the server the file as saved,
    // read from disk, unless it is served from a URL
    if (languageServer != null) code.fileUrl = _servedFromEditor;
    code.addListener(_onCodeChanged);
  }

  /// The [CodeForgeController.fileUrl] telling CodeForge that the text is
  /// the editor's own, so it shows the language server the file loaded,
  /// unsaved edits included.
  static const String _servedFromEditor = 'fide-editor:';

  /// The editor's text and selection.
  final CodeForgeController code;

  final OpenDocumentsNotifier _documents;

  final DartLanguageServer? _languageServer;

  final CodeFormatter _formatter;

  final GitService _git;

  final Logger _logger = Logger('EditorSession');

  /// The caret's line and column since the last change; null until
  /// [cursor] computes them.
  ({int line, int column})? _cursor;

  ({String oldText, String newText})? _diff;

  String _filePath = '';

  bool _isDirty = false;

  bool _isDisposed = false;

  /// The [CodeForgeController.contentVersion] last loaded or published,
  /// telling an edit from a change that leaves the text as it is.
  int _publishedVersion = 0;

  /// The selection the open documents record for [filePath].
  TextSelection _publishedSelection = const TextSelection.collapsed(offset: 0);

  String _savedText = '';

  /// Whether the file's type can be formatted.
  bool get canFormat => CodeFormatter.canFormat(_filePath);

  /// Line and column of the caret in the text, 1-based; computed once
  /// per change from the controller's line index.
  ({int line, int column}) get cursor =>
      _cursor ??= _cursorAt(code.selection.base.offset);

  /// The sides of the diff view once [loadDiff] loaded them: the
  /// committed text and the editor's; null until then and after
  /// [clearDiff].
  ({String oldText, String newText})? get diff => _diff;

  /// The file loaded, empty while none is.
  String get filePath => _filePath;

  /// Whether the text differs from [savedText].
  bool get isDirty => _isDirty;

  /// The text as last loaded or saved.
  String get savedText => _savedText;

  /// Forgets the loaded [diff].
  void clearDiff() {
    _diff = null;
    notifyListeners();
  }

  /// Formats the text, unsaved edits included, and returns the result
  /// without applying or saving it; throws when the formatter fails.
  Future<String> format() => _formatter.format(_filePath, code.text);

  /// Loads the committed text of the file against the editor's into
  /// [diff], saying whether there is one to show.
  Future<EditorDiffOutcome> loadDiff() async {
    final diff = await _git.diffAgainstHead(_filePath, newText: code.text);
    if (diff == null) return EditorDiffOutcome.notGitRepository;
    if (diff.oldText == diff.newText) return EditorDiffOutcome.unchanged;
    _diff = diff;
    notifyListeners();
    return EditorDiffOutcome.loaded;
  }

  /// Loads [document] into the editor, replacing the text, selection and
  /// dirty state without publishing them back as an edit; listeners are
  /// not told, as the loader shows the document itself. The caret left in
  /// the file shown before is published for it.
  void load(DocumentState document) {
    _publishSelection();
    _filePath = document.filePath;
    _quietly(() => code.text = document.content);
    _showToLanguageServer();
    restoreSelection(document.selection);
    _publishedVersion = code.contentVersion;
    _publishedSelection = document.selection;
    _isDirty = document.isDirty;
    _savedText = document.content;
  }

  /// Moves the caret to [selection] without publishing it as an edit;
  /// clamped to the text, as a caret published for an earlier text of the
  /// file may lie past its end.
  void restoreSelection(TextSelection selection) {
    final length = code.length;
    _quietly(
      () => code.selection = selection.copyWith(
        baseOffset: selection.baseOffset.clamp(0, length),
        extentOffset: selection.extentOffset.clamp(0, length),
      ),
    );
  }

  /// Writes the text to the file and records it as saved; throws when the
  /// write fails.
  Future<void> save() async {
    if (_filePath.isEmpty) return;
    final text = code.text;
    await _documents.save(_filePath, text);
    if (_isDisposed) return;
    _savedText = text;
    _isDirty = text != code.text;
    notifyListeners();
  }

  /// Writes unsaved edits to disk at once, as the closing editor can
  /// neither wait nor report, publishes the caret, stops showing the file
  /// to the language server, then releases the controller.
  @override
  void dispose() {
    _isDisposed = true;
    code.removeListener(_onCodeChanged);
    _publishSelection();
    if (_isDirty && _filePath.isNotEmpty) {
      try {
        _documents.saveOnClose(_filePath, code.text);
      } catch (e) {
        _logger.warning('Error auto-saving file on close: $e');
      }
    }
    if (code.openedFile case final shown?) _languageServer?.close(shown);
    code.dispose();
    super.dispose();
  }

  /// The 1-based line and column of [offset], clamped to the text, from
  /// the controller's line index instead of a scan of the text.
  ({int line, int column}) _cursorAt(int offset) {
    final clamped = offset.clamp(0, code.length);
    final line = code.getLineAtOffset(clamped);
    return (
      line: line + 1,
      column: clamped - code.getLineStartOffset(line) + 1,
    );
  }

  /// On an edit, marks the text dirty when it differs from [savedText] and
  /// publishes the text and the selection; a caret move or a decoration
  /// publishes nothing. Listeners are told of either.
  void _onCodeChanged() {
    if (_isDisposed) return;
    _cursor = null;
    final version = code.contentVersion;
    if (version != _publishedVersion) {
      _publishedVersion = version;
      final text = code.text;
      _isDirty = text != _savedText;
      _publishedSelection = code.selection;
      _documents.update(
        _filePath,
        content: text,
        selection: _publishedSelection,
        isDirty: _isDirty,
      );
    }
    notifyListeners();
  }

  /// Records the caret in the open documents when it moved since last
  /// published. Deferred to a microtask, as the session leaves a file
  /// while widgets build, when providers can't change.
  void _publishSelection() {
    final selection = code.selection;
    if (_filePath.isEmpty || selection == _publishedSelection) return;
    final filePath = _filePath;
    final documents = _documents;
    _publishedSelection = selection;
    scheduleMicrotask(() {
      if (documents.mounted) documents.update(filePath, selection: selection);
    });
  }

  /// Shows [filePath] to the language server when it analyzes the file,
  /// with the text just loaded. The file shown before stops being shown,
  /// else the server would keep analyzing it as the editor left it rather
  /// than as saved, even once changed on disk.
  void _showToLanguageServer() {
    final server = _languageServer;
    if (server == null) return;
    final shown = code.openedFile;
    if (server.analyzes(_filePath)) {
      // CodeForge stops showing the file shown before itself; the text
      // just loaded goes to the server with the file
      code.openFile = _filePath;
    } else if (shown != null) {
      code.openFile = null;
      server.close(shown);
    }
  }

  /// Runs [change] on [code] without publishing it as an edit; the caret
  /// may move, so its [cursor] is computed again.
  void _quietly(VoidCallback change) {
    code.removeListener(_onCodeChanged);
    change();
    code.addListener(_onCodeChanged);
    _cursor = null;
  }
}
