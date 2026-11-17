import 'package:fide/constants/constants.dart';
import 'package:fide/providers/side_panel.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// A rounded, borderless surface that floats a workspace panel above the
/// `AppTheme.workspaceBackground` gradient; the contrast with the gradient
/// alone separates the panels.
///
/// A click or the focus inside makes its [panel] the
/// [activePanelProvider], which the gradient centers on.
///
/// Each island paints on its own layer, so a spinner, progress bar or
/// hover fade in one panel repaints that panel alone, not the editor
/// text and the other panels beside it.
class PanelIsland extends ConsumerWidget {
  /// Creates an island around [child], holding [panel] or, when null, the
  /// editor area.
  const PanelIsland({super.key, required this.child, this.panel});
  static const BorderRadius _radius = BorderRadius.all(
    Radius.circular(AppRadius.island),
  );

  /// The panel content, clipped to the island's rounded corners.
  final Widget child;

  /// The side panel the island holds; null for the editor area.
  final SidePanel? panel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void activate() => ref.read(activePanelProvider.notifier).state = panel;
    // Focus only reports the focus moving into the content: it takes none
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onFocusChange: (focused) {
        if (focused) activate();
      },
      child: Listener(
        onPointerDown: (_) => activate(),
        child: RepaintBoundary(
          child: ClipRRect(
            borderRadius: _radius,
            child: ColoredBox(
              color: Theme.of(context).colorScheme.surface,
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
