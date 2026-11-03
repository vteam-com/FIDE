import 'package:fide/constants/constants.dart';
import 'package:fide/widgets/empty_label.dart';
import 'package:flutter/material.dart';

/// A tree entry that holds others, such as a folder: its [header] row and,
/// when expanded, its indented [children], or an empty-folder label when
/// it [isEmpty].
class TreeBranch extends StatelessWidget {
  /// Creates a branch under [header].
  const TreeBranch({
    super.key,
    required this.header,
    required this.isExpanded,
    required this.children,
    this.isEmpty = false,
  });

  /// Entries shown under the header when expanded.
  final List<Widget> children;

  /// The branch's own row.
  final Widget header;

  /// Whether the branch holds no entries at all; a filter can hide every
  /// one of [children] of a branch that is not empty.
  final bool isEmpty;

  /// Whether the branch is open.
  final bool isExpanded;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        header,
        if (isExpanded)
          Padding(
            // The empty label lines up with the name, past the chevron
            padding: EdgeInsets.only(
              left: isEmpty ? AppSize.compactActionButton : AppSpacing.xLarge,
            ),
            child: isEmpty
                ? const EmptyLabel('empty folder')
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: children,
                  ),
          ),
      ],
    );
  }
}
