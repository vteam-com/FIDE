import 'package:fide/constants/constants.dart';
import 'package:fide/widgets/surface_padding.dart';
import 'package:material_ui/material_ui.dart';

/// A rounded box on the surface color with a thin outline, grouping related
/// controls, a notice or a value inside a panel: the one box of the app.
class OutlinedSurface extends StatelessWidget {
  /// Creates the box around [child], inset by [padding].
  const OutlinedSurface({
    super.key,
    required this.child,
    this.padding = SurfacePadding.normal,
    this.highlight,
  });

  /// The content.
  final Widget child;

  /// Color of an outline drawn thicker to pick the box out, such as a
  /// file related to the focused one in the architecture graph; the thin
  /// divider-colored outline when null.
  final Color? highlight;

  /// Space between the outline and [child].
  final SurfacePadding padding;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    // Clipped, so content that fills the box keeps its rounded corners
    return Container(
      clipBehavior: Clip.antiAlias,
      padding: padding.insets,
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.medium),
        border: Border.all(
          color: highlight ?? Theme.of(context).dividerColor,
          width: highlight == null ? AppSize.borderThin : AppBorderWidth.medium,
        ),
      ),
      child: child,
    );
  }
}
