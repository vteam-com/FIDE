import 'package:fide/constants/constants.dart';
import 'package:fide/widgets/compact_icon_button.dart';
import 'package:fide/widgets/icon_only_labels.dart';
import 'package:fide/widgets/optional_tooltip.dart';
import 'package:material_ui/material_ui.dart';

/// A small text button that fits inside a row of caption text, such as
/// "Edit" next to a file name or "Install" next to a missing tool; under
/// [IconOnlyLabels], one with an [icon] shows it alone, [label] as tooltip.
class CompactTextButton extends StatelessWidget {
  /// Creates the button labelled [label].
  const CompactTextButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.tooltip,
  });

  /// Glyph before [label]; none when null.
  final IconData? icon;

  /// The button text.
  final String label;

  /// Called when pressed; the button is disabled when null.
  final VoidCallback? onPressed;

  /// Shown while the pointer is over the button; none when null.
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final icon = this.icon;
    if (icon != null && IconOnlyLabels.of(context)) {
      return CompactIconButton(
        icon: icon,
        tooltip: tooltip ?? label,
        onPressed: onPressed,
        color: Theme.of(context).colorScheme.primary,
      );
    }
    final style = TextButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.tiny),
      minimumSize: const Size(
        AppSize.compactTextButtonMinWidth,
        AppSize.compactTextButtonHeight,
      ),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      textStyle: AppTextStyle.caption,
    );
    final button = icon == null
        ? TextButton(onPressed: onPressed, style: style, child: Text(label))
        : TextButton.icon(
            onPressed: onPressed,
            style: style,
            icon: Icon(icon, size: AppIconSize.small),
            label: Text(label),
          );
    return OptionalTooltip(message: tooltip, child: button);
  }
}
