import 'package:fide/constants/constants.dart';
import 'package:fide/models/status_tone.dart';
import 'package:fide/widgets/priority_row.dart';
import 'package:fide/widgets/status_tone_style.dart';
import 'package:material_ui/material_ui.dart';

/// The content of every popup menu entry: an icon, its label, then an
/// optional [trailing] widget.
///
/// Entries without an icon keep its space, so labels line up; a check
/// menu passes [Icons.check] for the selected entry only. Too narrow for
/// all of it, the label keeps its room and [trailing] hides, rather than
/// overflowing.
class IconMenuRow extends StatelessWidget {
  /// Creates a row showing [icon] then [label].
  const IconMenuRow({
    super.key,
    required this.icon,
    required this.label,
    this.isError = false,
    this.leading,
    this.labelWidget,
    this.trailing,
  });

  /// Leading icon; a same-sized gap when null.
  final IconData? icon;

  /// Whether the entry is destructive or unavailable, shown in the error
  /// color.
  final bool isError;

  /// Entry text.
  final String label;

  /// Widget shown instead of [label], such as a file's path.
  final Widget? labelWidget;

  /// Widget shown instead of [icon], such as a project's app icon; sized to
  /// the same square.
  final Widget? leading;

  /// Widget after the label, such as a count or a lock.
  final Widget? trailing;
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = isError ? StatusTone.error.readableIn(colorScheme) : null;
    // As the row narrows, such as the open file's name atop a narrow
    // editor, the label keeps its room and the trailing part hides
    return PriorityRow(
      packed: true,
      spacing: AppSpacing.medium,
      leading: SizedBox.square(
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
      title:
          labelWidget ??
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyle.label.copyWith(color: color),
          ),
      trailing: trailing,
    );
  }
}
