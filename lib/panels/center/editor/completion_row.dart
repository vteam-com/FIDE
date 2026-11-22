import 'package:code_forge/code_forge.dart';
import 'package:fide/constants/constants.dart';
import 'package:fide/models/outline_kind.dart';
import 'package:fide/widgets/outline_kind_style.dart';
import 'package:fide/widgets/tree_row.dart';
import 'package:material_ui/material_ui.dart';

/// One completion of the Dart language server in the code editor's list,
/// drawn as the outline draws a symbol: the icon of its kind, its name,
/// then the library it is imported from, or its type, dimmed.
class CompletionRow extends StatelessWidget {
  /// Creates the row of [completion], filled when [isSelected].
  const CompletionRow({
    super.key,
    required this.completion,
    required this.isSelected,
  });

  /// The completion shown.
  final LspCompletion completion;

  /// Whether [completion] is the one Enter or Tab would insert.
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final kind = _outlineKindOf(completion.itemType);
    final detail = _detail;
    return TreeRow(
      icon: SizedBox.square(
        dimension: AppIconSize.medium,
        child: kind == null
            ? null
            : Icon(
                kind.icon,
                color: kind.colorIn(Theme.of(context).colorScheme),
                size: AppIconSize.medium,
              ),
      ),
      name: completion.label,
      highlighted: isSelected,
      trailing: [
        if (detail != null)
          Text(
            detail,
            style: AppTextStyle.secondary(context),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
      ],
    );
  }

  /// The library inserting the completion imports, else its type, as the
  /// server describes it; null when it gives neither.
  String? get _detail =>
      completion.importUri?.firstOrNull ??
      switch (completion.completionItem['detail']) {
        final String detail when detail.isNotEmpty => detail,
        _ => null,
      };

  /// The outline kind drawn as completions of [type] are; null for kinds
  /// the outline doesn't show, such as keywords, which get no icon.
  static OutlineKind? _outlineKindOf(CompletionItemType type) => switch (type) {
    CompletionItemType.class_ ||
    CompletionItemType.interface ||
    CompletionItemType.enum_ ||
    CompletionItemType.struct => OutlineKind.dartClass,
    CompletionItemType.function => OutlineKind.function,
    CompletionItemType.method ||
    CompletionItemType.constructor => OutlineKind.method,
    CompletionItemType.field ||
    CompletionItemType.property ||
    CompletionItemType.variable ||
    CompletionItemType.constant ||
    CompletionItemType.enumMember => OutlineKind.variable,
    _ => null,
  };
}
