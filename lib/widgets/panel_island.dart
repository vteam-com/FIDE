import 'package:fide/constants/constants.dart';
import 'package:material_ui/material_ui.dart';

/// A rounded, borderless surface that floats a workspace panel above the
/// `AppTheme.workspaceBackground` gradient; the contrast with the gradient
/// alone separates the panels.
class PanelIsland extends StatelessWidget {
  /// Creates an island around [child].
  const PanelIsland({super.key, required this.child});
  static const BorderRadius _radius = BorderRadius.all(
    Radius.circular(AppRadius.island),
  );

  /// The panel content, clipped to the island's rounded corners.
  final Widget child;
  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: _radius,
      child: ColoredBox(
        color: Theme.of(context).colorScheme.surface,
        child: child,
      ),
    );
  }
}
