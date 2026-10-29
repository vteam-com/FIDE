import 'package:fide/constants/constants.dart';
import 'package:fide/widgets/app_text_field.dart';
import 'package:flutter/material.dart';

/// The filter box under the tree and list panels: a filter icon, the
/// query, and a clear button while there is one.
class FilterField extends StatelessWidget {
  /// Creates a filter box editing [controller].
  const FilterField({
    super.key,
    required this.controller,
    this.hintText = 'Filter...',
  });

  /// Holds the query; listeners see every change, including clearing.
  final TextEditingController controller;

  /// Placeholder shown while empty.
  final String hintText;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.medium,
        0,
        AppSpacing.medium,
        AppSpacing.medium,
      ),
      child: AppTextField(
        controller: controller,
        hintText: hintText,
        icon: Icons.filter_list,
        clearable: true,
      ),
    );
  }
}
