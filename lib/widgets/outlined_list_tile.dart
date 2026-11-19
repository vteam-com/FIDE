import 'package:fide/constants/constants.dart';
import 'package:fide/widgets/outlined_surface.dart';
import 'package:fide/widgets/surface_padding.dart';
import 'package:fide/widgets/truncated_text.dart';
import 'package:material_ui/material_ui.dart';

/// A list entry in an outlined box: [leading], [title] over [subtitle], an
/// optional [trailing] widget, and a tap action; disabled when [onTap] is
/// null.
class OutlinedListTile extends StatelessWidget {
  /// Creates the entry for [title].
  const OutlinedListTile({
    super.key,
    required this.leading,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
  });

  /// Picture before the text, such as a project's icon, sized
  /// [AppIconSize.large].
  final Widget leading;

  /// Called when the entry is tapped; the entry is disabled when null.
  final VoidCallback? onTap;

  /// Second line, such as a path or description.
  final String subtitle;

  /// The entry's name.
  final String title;

  /// Widgets after the text, such as a status or a button.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return OutlinedSurface(
      padding: SurfacePadding.none,
      // Transparent Material so the ListTile's ink effects paint above
      // the surface's background color.
      child: Material(
        type: MaterialType.transparency,
        child: ListTile(
          enabled: onTap != null,
          dense: true,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.medium),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xLarge,
            vertical: AppSpacing.tiny,
          ),
          leading: leading,
          title: TruncatedText(title, style: AppTextStyle.label),
          subtitle: Text(
            subtitle,
            style: AppTextStyle.secondary(context),
            maxLines: AppMetric.doubleLineLimit,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: trailing,
          onTap: onTap,
        ),
      ),
    );
  }
}
