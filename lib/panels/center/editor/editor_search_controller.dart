import 'package:code_forge/code_forge.dart';
import 'package:fide/models/editor_search.dart';
import 'package:flutter/widgets.dart';

/// Find and replace in an editor's text: the find bar's fields and
/// visibility, the query's matches, and selecting them in the editor.
class EditorSearchController extends ChangeNotifier {
  /// Creates find and replace for the text of [_code]; [onMatchSelected]
  /// is called each time a match gets selected, to scroll it into view.
  EditorSearchController(this._code, {this.onMatchSelected});

  /// The editor searched and edited.
  final CodeForgeController _code;

  /// Called after a match is selected in the editor.
  final VoidCallback? onMatchSelected;

  /// The query, its options and its matches.
  final EditorSearch _search = EditorSearch();

  /// Holds the text searched for.
  final TextEditingController queryController = TextEditingController();

  /// Holds the replacement text.
  final TextEditingController replaceController = TextEditingController();

  /// Focus of the query field.
  final FocusNode queryFocusNode = FocusNode();

  bool _isOpen = false;

  bool _isDisposed = false;

  /// Whether the find bar shows.
  bool get isOpen => _isOpen;

  /// Whether letter case must match.
  bool get caseSensitive => _search.caseSensitive;

  /// Whether matches must be whole words.
  bool get wholeWord => _search.wholeWord;

  /// Index of the selected match, or [EditorSearch.noMatch].
  int get currentIndex => _search.currentIndex;

  /// Number of matches of the query.
  int get matchCount => _search.matches.length;

  /// The text a find starts with: the editor's selection, unless it spans
  /// lines; empty without a selection.
  String get seed {
    final selection = _code.selection;
    if (!selection.isValid) return '';
    return EditorSearch.seedFrom(selection.textInside(_code.text));
  }

  /// Shows the find bar focused with its query selected, starting from the
  /// selected text when there is a [seed], else from the last query with
  /// its matches counted again in the current text.
  void open() {
    final seed = this.seed;
    _isOpen = true;
    if (seed.isEmpty) {
      queryController.text = _search.query;
      _search.run(_code.text, _search.query, fromOffset: _code.selection.start);
      notifyListeners();
    } else {
      queryController.text = seed;
      search(seed);
    }
    queryController.selection = TextSelection(
      baseOffset: 0,
      extentOffset: queryController.text.length,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_isDisposed && _isOpen) queryFocusNode.requestFocus();
    });
  }

  /// Hides the find bar; the query stays, so [findNext] and [findPrevious]
  /// keep working and [open] shows it again.
  void close() {
    _isOpen = false;
    queryFocusNode.unfocus();
    notifyListeners();
  }

  /// Shows the find bar when hidden, hides it when shown.
  void toggle() => _isOpen ? close() : open();

  /// Finds [query] in the text and selects its first match at or after
  /// the caret.
  void search(String query) {
    _search.run(_code.text, query, fromOffset: _code.selection.start);
    notifyListeners();
    if (_search.hasMatches) _select(_search.currentIndex);
  }

  /// Sets whether letter case must match and searches again.
  void setCaseSensitive(bool value) {
    _search.caseSensitive = value;
    search(_search.query);
  }

  /// Sets whether matches must be whole words and searches again.
  void setWholeWord(bool value) {
    _search.wholeWord = value;
    search(_search.query);
  }

  /// Selects the next match after the caret, wrapping at the end; see
  /// [findPrevious].
  bool findNext() => _step(backward: false);

  /// Selects the match before the caret, wrapping at the start, even with
  /// the find bar closed or the text edited since. Without a query yet,
  /// searches for the selected text; without a selection either, opens
  /// the find bar. Returns whether a match got selected.
  bool findPrevious() => _step(backward: true);

  /// Replaces the current match, then selects the next one after the
  /// replacement.
  void replace() {
    // Matches go stale once the text is edited by hand
    _search.run(_code.text, _search.query, fromOffset: _code.selection.start);
    if (!_search.hasMatches) return;
    final start = _search.matches[_search.currentIndex];
    final replacement = replaceController.text;
    _code.replaceRange(start, start + _search.query.length, replacement);
    _code.selection = TextSelection.collapsed(
      offset: start + replacement.length,
    );
    search(_search.query);
  }

  /// Replaces every match in one undoable edit; returns how many were
  /// replaced.
  int replaceAll() {
    final text = _code.text;
    final replaced = EditorSearch.replaceAll(
      text,
      _search.query,
      replaceController.text,
      caseSensitive: _search.caseSensitive,
      wholeWord: _search.wholeWord,
    );
    if (replaced.count == 0) return 0;
    _code.replaceRange(0, text.length, replaced.text);
    search(_search.query);
    return replaced.count;
  }

  @override
  void dispose() {
    _isDisposed = true;
    queryController.dispose();
    replaceController.dispose();
    queryFocusNode.dispose();
    super.dispose();
  }

  /// Selects the next match after the caret, or the one before it when
  /// [backward]; see [findPrevious].
  bool _step({required bool backward}) {
    if (_search.query.isEmpty) {
      final seed = this.seed;
      if (seed.isEmpty) {
        open();
        return false;
      }
      _search.query = seed;
      queryController.text = seed;
    }
    final selection = _code.selection;
    _search.step(
      _code.text,
      selection.isValid ? selection.start : 0,
      backward: backward,
    );
    if (!_search.hasMatches) {
      notifyListeners();
      return false;
    }
    _select(_search.currentIndex);
    return true;
  }

  /// Selects the match at [index] in the editor.
  void _select(int index) {
    final start = _search.matches[index];
    _code.selection = TextSelection(
      baseOffset: start,
      extentOffset: start + _search.query.length,
    );
    _search.currentIndex = index;
    notifyListeners();
    onMatchSelected?.call();
  }
}
