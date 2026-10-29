import 'package:fide/providers/editor_commands.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Routes [EditorCommands] to the editor that is currently mounted.
///
/// The editor attaches itself on mount and detaches on dispose; while no
/// editor is attached every command is a no-op.
class ActiveEditor implements EditorCommands {
  EditorCommands? _editor;

  /// Makes [editor] the target of subsequent commands.
  void attach(EditorCommands editor) => _editor = editor;

  /// Stops routing to [editor], unless another editor has attached since.
  void detach(EditorCommands editor) {
    if (identical(_editor, editor)) {
      _editor = null;
    }
  }

  @override
  void close() => _editor?.close();

  @override
  void findNext() => _editor?.findNext();

  @override
  void findPrevious() => _editor?.findPrevious();

  @override
  void openSearch() => _editor?.openSearch();

  @override
  void navigateToLine(int lineNumber, {int column = 1}) =>
      _editor?.navigateToLine(lineNumber, column: column);

  @override
  void save() => _editor?.save();

  @override
  String get searchSeed => _editor?.searchSeed ?? '';
}

/// Provides the [ActiveEditor] that menus, shortcuts and panels send
/// editor commands through.
final activeEditorProvider = Provider<ActiveEditor>((_) => ActiveEditor());
