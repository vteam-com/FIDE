import 'package:fide/constants/constants.dart';
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
      child: ValueListenableBuilder(
        valueListenable: controller,
        builder: (context, value, _) => TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: hintText,
            prefixIcon: const Icon(Icons.filter_list, size: AppIconSize.large),
            suffixIcon: value.text.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.clear, size: AppIconSize.large),
                    onPressed: controller.clear,
                  ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.medium),
              borderSide: BorderSide.none,
            ),
            filled: true,
            fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.large,
              vertical: AppSpacing.medium,
            ),
          ),
          style: const TextStyle(fontSize: AppFontSize.body),
        ),
      ),
    );
  }
}
