import 'package:fide/constants/constants.dart';
import 'package:flutter/material.dart';

/// The outlined text box used by every panel (search, find, filter, AI
/// prompt, commit message), so they share one border, padding and font.
class AppTextField extends StatelessWidget {
  /// Creates a text box editing [controller].
  const AppTextField({
    super.key,
    required this.controller,
    this.focusNode,
    this.hintText,
    this.icon,
    this.clearable = false,
    this.onCleared,
    this.onChanged,
    this.onSubmitted,
    this.minLines,
    this.maxLines = 1,
  });

  /// Whether a clear button shows while there is text.
  final bool clearable;

  /// Holds the text.
  final TextEditingController controller;

  /// Focus of the box, for callers that move focus into it.
  final FocusNode? focusNode;

  /// Placeholder shown while empty.
  final String? hintText;

  /// Icon shown before the text.
  final IconData? icon;

  /// Lines the box grows to before scrolling.
  final int? maxLines;

  /// Lines the box shows while nearly empty.
  final int? minLines;

  /// Called on every edit.
  final ValueChanged<String>? onChanged;

  /// Called after the clear button empties the box.
  final VoidCallback? onCleared;

  /// Called when Enter submits a single-line box.
  final ValueChanged<String>? onSubmitted;
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: controller,
      builder: (_ /*context*/, value, _ /*child*/) => TextField(
        controller: controller,
        focusNode: focusNode,
        minLines: minLines,
        maxLines: maxLines,
        style: const TextStyle(fontSize: AppFontSize.body),
        decoration: InputDecoration(
          hintText: hintText,
          prefixIcon: icon == null ? null : Icon(icon, size: AppIconSize.large),
          suffixIcon: clearable && value.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: AppIconSize.large),
                  onPressed: () {
                    controller.clear();
                    onCleared?.call();
                  },
                )
              : null,
          isDense: true,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.small),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.large,
            vertical: AppSpacing.medium,
          ),
        ),
        onChanged: onChanged,
        onSubmitted: onSubmitted,
      ),
    );
  }
}
