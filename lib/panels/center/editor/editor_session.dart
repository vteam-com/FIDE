import 'package:code_forge/code_forge.dart';
import 'package:fide/models/document_state.dart';
import 'package:fide/models/editor_diff_outcome.dart';
import 'package:fide/models/text_offsets.dart';
import 'package:fide/providers/app_providers.dart';
import 'package:fide/services/code_formatter.dart';
import 'package:fide/services/git_service.dart';
import 'package:flutter/widgets.dart';
import 'package:logging/logging.dart';

/// The text of one editor and what happens to it: the document loaded in
/// its [code] controller, whether it is dirty against [savedText], and
/// its saves, formatting and git diff. Every edit is published to the
/// open documents; listeners are told of each change.
class EditorSession extends ChangeNotifier {
  /// Creates a session publishing to the open documents, formatting with
  /// the code formatter and diffing against HEAD with the git service.
  EditorSession({
    required this._documents,
    required this._formatter,
    required this._git,
  }) {
    code.addListener(_onCodeChanged);
  }

  /// The editor's text and selection.
  final CodeForgeController code = CodeForgeController();

  final OpenDocumentsNotifier _documents;

  final CodeFormatter _formatter;

  final GitService _git;

  final Logger _logger = Logger('EditorSession');

  ({String oldText, String newText})? _diff;

  String _filePath = '';

  bool _isDirty = false;

  bool _isDisposed = false;

  String _savedText = '';

  /// Whether the file's type can be formatted.
  bool get canFormat => CodeFormatter.canFormat(_filePath);

  /// Line and column of the caret in the text, 1-based.
  ({int line, int column}) get cursor =>
      TextOffsets.positionOf(code.text, code.selection.base.offset);

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
  /// not told, as the loader shows the document itself.
  void load(DocumentState document) {
    _filePath = document.filePath;
    _quietly(() {
      code
        ..text = document.content
        ..selection = document.selection;
    });
    _isDirty = document.isDirty;
    _savedText = document.content;
  }

  /// Moves the caret to [selection] without publishing it as an edit.
  void restoreSelection(TextSelection selection) {
    _quietly(() => code.selection = selection);
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
  /// neither wait nor report, then releases the controller.
  @override
  void dispose() {
    _isDisposed = true;
    code.removeListener(_onCodeChanged);
    if (_isDirty && _filePath.isNotEmpty) {
      try {
        _documents.saveOnClose(_filePath, code.text);
      } catch (e) {
        _logger.warning('Error auto-saving file on close: $e');
      }
    }
    code.dispose();
    super.dispose();
  }

  /// Marks the text dirty when it differs from [savedText] and publishes
  /// the edit and the selection.
  void _onCodeChanged() {
    if (_isDisposed) return;
    _isDirty = code.text != _savedText;
    _documents.update(
      _filePath,
      content: code.text,
      selection: code.selection,
      isDirty: _isDirty,
    );
    notifyListeners();
  }

  /// Runs [change] on [code] without publishing it as an edit.
  void _quietly(VoidCallback change) {
    code.removeListener(_onCodeChanged);
    change();
    code.addListener(_onCodeChanged);
  }
}
