import 'package:fide/providers/panel_actions.dart';
import 'package:fide/widgets/compact_icon_button.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// The button closing the view shown in the center island (the project
/// overview, the app icons or the architecture), back to the open files;
/// one for every center view, so they all close alike.
class CenterViewCloseButton extends ConsumerWidget {
  /// Creates the button for a page header, beside its `RefreshButton`.
  const CenterViewCloseButton({super.key}) : _inStrip = false;

  /// Creates the button for the strip atop a view, as large as the strip's
  /// other buttons ([CompactIconButton.header]).
  const CenterViewCloseButton.header({super.key}) : _inStrip = true;

  /// Whether the button sits in a strip, at its height.
  final bool _inStrip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void close() => closeCenterView(ref);
    const tooltip = 'Close';
    return _inStrip
        ? CompactIconButton.header(
            icon: Icons.close,
            tooltip: tooltip,
            onPressed: close,
          )
        : CompactIconButton(
            icon: Icons.close,
            tooltip: tooltip,
            onPressed: close,
          );
  }
}
