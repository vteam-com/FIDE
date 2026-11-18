import 'package:fide/constants/constants.dart';
import 'package:fide/models/outline_kind.dart';
import 'package:fide/models/outline_node.dart';
import 'package:fide/models/search_result.dart';
import 'package:fide/providers/app_providers.dart';
import 'package:fide/providers/outline_controller.dart';
import 'package:fide/providers/outline_providers.dart';
import 'package:fide/widget_services/search_result_row.dart';
import 'package:fide/widgets/empty_label.dart';
import 'package:fide/widgets/section_panel.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// The Info tab's section about [node], the declaration under the
/// editor's cursor in the file at [path], titled by its name (with its
/// class for a member): the places calling it and, for a function or
/// method, the project's declarations it calls, each opening the code
/// there.
class SymbolInfoSection extends ConsumerWidget {
  /// Creates the section about [node] of [path].
  const SymbolInfoSection({super.key, required this.path, required this.node});

  /// The declaration described.
  final OutlineNode node;

  /// The file declaring it, as an absolute path.
  final String path;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final outline = ref.watch(outlineControllerProvider(path));
    final rootPath = ref.watch(currentProjectPathProvider);
    final owner = outline.classOf(node);
    final name = owner == null || identical(owner, node)
        ? node.name
        : '${owner.usedName}.${node.name}';
    final callsOthers =
        node.kind == OutlineKind.function || node.kind == OutlineKind.method;
    return SectionPanel(
      title: name,
      isExpanded: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: AppSpacing.medium,
        children: [
          _buildCallers(outline, rootPath),
          if (callsOthers) _buildCallees(ref, rootPath),
        ],
      ),
    );
  }

  /// The places calling [node], as [outline] found them.
  Widget _buildCallers(OutlineState outline, String? rootPath) {
    final callers = outline.consumersOf(node);
    return _buildPlaces(
      'Callers',
      callers,
      rootPath,
      pending: node.isOverride
          // Callers reach an override through the member it overrides
          ? 'Called through the member it overrides'
          : 'Finding callers…',
      none: 'Nothing calls it',
    );
  }

  /// The declarations of the project [node] calls, found once the code is
  /// analyzed; nothing when it can't be, such as while unsaved edits
  /// moved it.
  Widget _buildCallees(WidgetRef ref, String? rootPath) {
    final callees = ref.watch(
      calleesProvider((path: path, line: node.line, column: node.column)),
    );
    if (callees.hasError && !callees.hasValue) return const SizedBox.shrink();
    return _buildPlaces(
      'Calls',
      callees.value,
      rootPath,
      pending: 'Finding calls…',
      none: 'Calls nothing the project declares',
    );
  }

  /// A collapsible group titled [title] of [places], saying [pending]
  /// while they are null and [none] when there are none.
  Widget _buildPlaces(
    String title,
    List<SearchResult>? places,
    String? rootPath, {
    required String pending,
    required String none,
  }) {
    return SectionPanel(
      title: title,
      count: places?.length,
      isExpanded: true,
      child: switch (places) {
        null => EmptyLabel(pending),
        [] => EmptyLabel(none),
        _ => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final place in places)
              SearchResultRow(result: place, rootPath: rootPath),
          ],
        ),
      },
    );
  }
}
