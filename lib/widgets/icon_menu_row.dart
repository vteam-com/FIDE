import 'package:fide/constants/constants.dart';
import 'package:flutter/material.dart';

/// The content of every popup menu entry: an icon, its label, then an
/// optional [trailing] widget.
///
/// Entries without an icon keep its space, so labels line up; a check
/// menu passes [Icons.check] for the selected entry only.
class IconMenuRow extends StatelessWidget {
  /// Creates a row showing [icon] then [label].
  const IconMenuRow({
    super.key,
    required this.icon,
    required this.label,
    this.isError = false,
    this.leading,
    this.trailing,
  });

  /// Leading icon; a same-sized gap when null.
  final IconData? icon;

  /// Whether the entry is destructive or unavailable, shown in the error
  /// color.
  final bool isError;

  /// Entry text.
  final String label;

  /// Widget shown instead of [icon], such as a project's app icon; sized to
  /// the same square.
  final Widget? leading;

  /// Widget after the label, such as a count or a lock.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = isError ? colorScheme.error : null;
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: AppSpacing.medium,
      children: [
        SizedBox.square(
          dimension: AppIconSize.medium,
          child:
              leading ??
              (icon == null
                  ? null
                  : Icon(
                      icon,
                      size: AppIconSize.medium,
                      color: color ?? colorScheme.primary,
                    )),
        ),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyle.label.copyWith(color: color),
          ),
        ),
        ?trailing,
      ],
    );
  }
}
