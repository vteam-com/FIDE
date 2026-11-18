part of 'outline_controller.dart';

/// The outline of one file as its project tree row shows it: its entries,
/// the cursor line highlighting them, and the consumers of the selected
/// entry.
@immutable
class OutlineState {
  /// Before the first parse.
  static const OutlineState loading = OutlineState(isLoading: true);

  /// Value of [cursorLine] while the cursor hasn't moved yet.
  static const int noCursorLine = -1;

  /// The outline's entries in file order.
  final List<OutlineNode> nodes;

  /// Whether a parse is running.
  final bool isLoading;

  /// Why the last parse failed; empty when it didn't.
  final String error;

  /// The editor's cursor line, or [noCursorLine].
  final int cursorLine;

  /// The selected entry whose consumers are shown, if any.
  final OutlineNode? countedNode;

  /// Uses of [countedNode]; null while they are being found.
  final List<SearchResult>? consumers;

  /// Whether [countedNode] is being renamed.
  final bool isRenaming;

  /// The widget-tree entry being edited, if any.
  final OutlineNode? editedWidget;

  /// Creates an outline state.
  const OutlineState({
    this.nodes = const [],
    this.isLoading = false,
    this.error = '',
    this.cursorLine = noCursorLine,
    this.countedNode,
    this.consumers,
    this.isRenaming = false,
    this.editedWidget,
  });

  /// Whether an entry is being renamed or edited, so no other edit starts.
  bool get isEditing => isRenaming || editedWidget != null;

  /// The consumers of [node] once found, or null while they are being
  /// found or when [node] isn't the counted entry.
  List<SearchResult>? consumersOf(OutlineNode node) =>
      isCounted(node) ? consumers : null;

  /// Whether [node] is the entry whose consumers are shown.
  bool isCounted(OutlineNode node) => node.isSameAs(countedNode);

  /// Whether [node] is the widget-tree entry being edited.
  bool isEdited(OutlineNode node) => node.isSameAs(editedWidget);

  /// Whether the cursor is on [node] or inside its scope.
  bool isHighlighted(OutlineNode node) =>
      cursorLine != noCursorLine && node.coversLine(cursorLine, nodes);

  /// The innermost entry under the cursor, if any, widget-tree entries
  /// aside: the cursor in a build function's widgets selects the function,
  /// whose consumers are counted.
  OutlineNode? get selected => nodes
      .where((node) => !node.kind.isWidget && isHighlighted(node))
      .lastOrNull;

  /// The innermost widget-tree entry under the cursor, if any: the widget
  /// the widget menu edits.
  OutlineNode? get selectedWidget => nodes
      .where((node) => node.kind.isWidget && isHighlighted(node))
      .lastOrNull;

  /// The entry [node] is nested in, such as a method's class; null for a
  /// top-level entry.
  OutlineNode? parentOf(OutlineNode node) {
    for (var i = nodes.indexOf(node) - 1; i >= 0; i--) {
      if (nodes[i].level < node.level) return nodes[i];
    }
    return null;
  }

  /// The class [node] is or is a member of; null for anything else, such
  /// as a top-level function.
  OutlineNode? classOf(OutlineNode node) {
    for (OutlineNode? entry = node; entry != null; entry = parentOf(entry)) {
      if (entry.kind == OutlineKind.dartClass) return entry;
    }
    return null;
  }

  /// The entries a file tree shows, each with the count of widgets folded
  /// under it: every declaration, heading and key, and only the widget
  /// tree of the [selected] declaration, so the outline stays short and
  /// the cursor unfolds the tree it is in.
  List<({OutlineNode node, int foldedWidgets})> get shownNodes {
    final selected = this.selected;
    final shown = <OutlineNode>[];
    final folded = <int>[];
    // Whether the widgets met belong to the selected declaration
    var isUnfolded = true;
    for (final node in nodes) {
      if (!node.kind.isWidget) {
        isUnfolded = node.isSameAs(selected);
      } else if (!isUnfolded && shown.isNotEmpty) {
        // The owner was the last entry shown: its widgets stay folded
        folded.last++;
        continue;
      }
      shown.add(node);
      folded.add(0);
    }
    return [
      for (var i = 0; i < shown.length; i++)
        (node: shown[i], foldedWidgets: folded[i]),
    ];
  }

  /// A copy with the given fields replaced; [countedNode], [consumers]
  /// and [editedWidget] are replaced by [counted], [found] and [edited]
  /// when given, as they can become null.
  OutlineState copyWith({
    List<OutlineNode>? nodes,
    bool? isLoading,
    String? error,
    int? cursorLine,
    ({OutlineNode? node})? counted,
    ({List<SearchResult>? uses})? found,
    bool? isRenaming,
    ({OutlineNode? node})? edited,
  }) {
    return OutlineState(
      nodes: nodes ?? this.nodes,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      cursorLine: cursorLine ?? this.cursorLine,
      countedNode: counted == null ? countedNode : counted.node,
      consumers: found == null ? consumers : found.uses,
      isRenaming: isRenaming ?? this.isRenaming,
      editedWidget: edited == null ? editedWidget : edited.node,
    );
  }
}
