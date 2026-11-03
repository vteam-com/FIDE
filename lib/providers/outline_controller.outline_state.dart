part of 'outline_controller.dart';

/// The outline of one file as the Outline panel shows it: its entries,
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

  /// Creates an outline state.
  const OutlineState({
    this.nodes = const [],
    this.isLoading = false,
    this.error = '',
    this.cursorLine = noCursorLine,
    this.countedNode,
    this.consumers,
    this.isRenaming = false,
  });

  /// The consumers of [node] once found, or null while they are being
  /// found or when [node] isn't the counted entry.
  List<SearchResult>? consumersOf(OutlineNode node) =>
      isCounted(node) ? consumers : null;

  /// Whether [node] is the entry whose consumers are shown.
  bool isCounted(OutlineNode node) => node.isSameAs(countedNode);

  /// Whether the cursor is on [node] or inside its scope.
  bool isHighlighted(OutlineNode node) =>
      cursorLine != noCursorLine && node.coversLine(cursorLine, nodes);

  /// The innermost entry under the cursor, if any.
  OutlineNode? get selected => nodes.where(isHighlighted).lastOrNull;

  /// A copy with the given fields replaced; [countedNode] and
  /// [consumers] are replaced by [counted] and [found] when given, as
  /// both can become null.
  OutlineState copyWith({
    List<OutlineNode>? nodes,
    bool? isLoading,
    String? error,
    int? cursorLine,
    ({OutlineNode? node})? counted,
    ({List<SearchResult>? uses})? found,
    bool? isRenaming,
  }) {
    return OutlineState(
      nodes: nodes ?? this.nodes,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      cursorLine: cursorLine ?? this.cursorLine,
      countedNode: counted == null ? countedNode : counted.node,
      consumers: found == null ? consumers : found.uses,
      isRenaming: isRenaming ?? this.isRenaming,
    );
  }
}
