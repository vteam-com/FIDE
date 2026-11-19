import 'dart:async';

import 'package:fide/constants/core_constants.dart';
import 'package:fide/models/outline_kind.dart';
import 'package:fide/models/outline_node.dart';
import 'package:fide/models/search_result.dart';
import 'package:fide/models/text_offsets.dart';
import 'package:fide/providers/app_providers.dart';
import 'package:fide/providers/outline_providers.dart';
import 'package:fide/providers/service_providers.dart';
import 'package:fide/providers/ui_state_providers.dart';
import 'package:fide/services/debouncer.dart';
import 'package:fide/services/widget_editor.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

part 'outline_controller.outline_state.dart';

/// The outline of a file, kept while its project tree row shows it.
final outlineControllerProvider = NotifierProvider.autoDispose
    .family<OutlineController, OutlineState, String>(OutlineController.new);

/// Outlines one file for its project tree row: parses its editor text (or
/// its saved text when it isn't open) again as it is edited, follows the
/// editor's cursor to highlight the entry under it, finds that entry's
/// consumers, renames it across the project, and edits the widgets of its
/// widget trees.
class OutlineController extends Notifier<OutlineState> {
  /// Creates the controller outlining [filePath].
  OutlineController(this.filePath);

  /// The file outlined.
  final String filePath;

  /// Bumped per consumer lookup so a stale answer is dropped.
  int _consumersGeneration = 0;

  /// The pending parse, while edits are debounced.
  final Debouncer _parse = Debouncer(AppDuration.updateDebounce);

  /// The pending consumer lookup, while cursor moves are debounced.
  final Debouncer _consumers = Debouncer(AppDuration.updateDebounce);

  /// The text last parsed and its outline, so an unchanged text isn't
  /// parsed again.
  ({String content, List<OutlineNode> nodes})? _parsed;

  @override
  OutlineState build() {
    // Re-outline as the file is edited
    ref.listen(
      openDocumentsProvider.select(
        (documents) => documents.contentOf(filePath),
      ),
      (_, _) => scheduleParse(),
    );
    ref.listen(editorCursorLineProvider, (_, line) => setCursorLine(line));
    ref.onDispose(() {
      _parse.cancel();
      _consumers.cancel();
    });
    // The first parse runs once the state exists
    unawaited(Future.microtask(parse));
    return OutlineState.loading;
  }

  /// Whether entries can be renamed: a project must be open.
  bool get canRename => ref.read(referenceFinderProvider) != null;

  /// Outlines the file now, keeping the last outline when its text hasn't
  /// changed, then finds the consumers of the entry under the cursor.
  Future<void> parse() async {
    final parser = ref.read(outlineParserProvider(filePath));
    if (parser == null) {
      state = state.copyWith(nodes: const [], isLoading: false, error: '');
      return;
    }
    state = state.copyWith(isLoading: true, error: '');
    try {
      final content = await _content();
      if (!ref.mounted) return;
      final parsed = _parsed;
      final nodes = parsed != null && parsed.content == content
          ? parsed.nodes
          : parser.parse(content);
      _parsed = (content: content, nodes: nodes);
      state = state.copyWith(nodes: nodes, isLoading: false);
      _updateConsumers();
    } catch (e) {
      if (!ref.mounted) return;
      state = state.copyWith(isLoading: false, error: 'Error parsing file: $e');
    }
  }

  /// Renames [node] and its uses across the project to [newName], after
  /// saving the open files, and returns the files rewritten; throws when
  /// no project is open or the rename fails.
  Future<Map<String, String>> rename(OutlineNode node, String newName) async {
    final finder = ref.read(referenceFinderProvider);
    if (finder == null) throw StateError('No project is open');
    state = state.copyWith(isRenaming: true);
    try {
      return await ref
          .read(openDocumentsProvider.notifier)
          .applyEdits(
            () => finder.rename(
              filePath: filePath,
              line: node.line,
              column: node.column,
              newName: newName,
            ),
          );
    } finally {
      if (ref.mounted) {
        state = state.copyWith(isRenaming: false);
        scheduleParse();
      }
    }
  }

  /// Makes [edit] to the widget-tree entry [node] in the saved file, after
  /// saving the open files, formats the file and returns the 1-based line
  /// and column the edited widget starts at now; throws, writing nothing,
  /// when [node] isn't in the file any more or [edit] doesn't apply to it.
  Future<({int line, int column})> editWidget(
    OutlineNode node,
    WidgetEdit edit,
  ) async {
    state = state.copyWith(edited: (node: node));
    try {
      int? offset;
      final written = await ref
          .read(openDocumentsProvider.notifier)
          .applyFileEdit(filePath, (content) {
            final editor = WidgetEditor.find(content, node);
            final result = editor == null ? null : edit(editor);
            offset = result?.offset;
            return result?.content;
          }, formatter: ref.read(codeFormatterProvider));
      final at = offset;
      if (written == null || at == null) {
        throw StateError('${node.name} changed since it was outlined');
      }
      return TextOffsets.positionOf(
        written.written,
        TextOffsets.formattedOffset(written.edited, written.written, at),
      );
    } finally {
      if (ref.mounted) {
        state = state.copyWith(edited: (node: null));
        scheduleParse();
      }
    }
  }

  /// Outlines the file again once edits pause for
  /// [AppDuration.updateDebounce].
  void scheduleParse() {
    _parse.run(() {
      if (ref.mounted) unawaited(parse());
    });
  }

  /// Highlights the entry at the editor's cursor [line] at once, then
  /// finds its consumers once the cursor rests for
  /// [AppDuration.updateDebounce], so moving through the file doesn't
  /// search the project for each entry passed.
  void setCursorLine(int line) {
    state = state.copyWith(cursorLine: line);
    _consumers.run(() {
      if (ref.mounted) _updateConsumers();
    });
  }

  /// The widget-tree entry [node] in the text last outlined, to list the
  /// edits the widget menu offers; null when it isn't one, or when that
  /// text no longer has it.
  WidgetEditor? widgetEditorOf(OutlineNode node) {
    final content = _parsed?.content;
    return content == null ? null : WidgetEditor.find(content, node);
  }

  /// The text to outline: the editor's, unsaved edits included, when the
  /// file is open there, otherwise what is on disk.
  Future<String> _content() async {
    return ref.read(openDocumentsProvider).contentOf(filePath) ??
        await ref.read(fileContentReaderProvider).read(filePath);
  }

  /// Finds the consumers of the innermost entry under the cursor, unless
  /// they are already shown.
  void _updateConsumers() {
    final selected = state.selected;
    if (selected != null && state.isCounted(selected)) return;
    final finder = ref.read(referenceFinderProvider);
    final countable =
        selected != null &&
        finder != null &&
        selected.kind.isCountable &&
        // Overrides are reached through the overridden member
        !selected.isOverride;
    final generation = ++_consumersGeneration;
    state = state.copyWith(
      counted: (node: countable ? selected : null),
      found: (uses: null),
    );
    if (!countable) return;

    finder
        .find(filePath: filePath, line: selected.line, column: selected.column)
        .then((uses) {
          if (!ref.mounted || generation != _consumersGeneration) return;
          state = state.copyWith(found: (uses: uses));
        })
        .catchError((Object _) {
          // No count when the code can't be analyzed
          if (!ref.mounted || generation != _consumersGeneration) return;
          state = state.copyWith(counted: (node: null));
        });
  }
}
