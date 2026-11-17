import 'package:fide/widgets/compact_icon_button.dart';
import 'package:material_ui/material_ui.dart';

/// The one button that runs a panel's check or analysis again: the same
/// glyph, words and place, the end of the panel's header, everywhere;
/// disabled while [busy], as the panel's busy bar tells it is running.
class RefreshButton extends StatelessWidget {
  /// Creates the button calling [onPressed].
  const RefreshButton({super.key, required this.onPressed, this.busy = false});

  /// Whether the check is running, disabling the button.
  final bool busy;

  /// Runs the check again.
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return CompactIconButton(
      icon: Icons.refresh,
      tooltip: 'Check again',
      onPressed: busy ? null : onPressed,
    );
  }
}
