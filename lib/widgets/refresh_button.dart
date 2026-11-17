import 'package:fide/widgets/task_button.dart';
import 'package:material_ui/material_ui.dart';

/// The one button that runs a panel's check or analysis again: the same
/// glyph, words and place, the end of the panel's header, everywhere.
///
/// A [TaskButton], so while [busy] the ring spinning around it is the
/// one sign that the panel is working, whether the check started from
/// it or by itself, such as after a save.
class RefreshButton extends StatelessWidget {
  /// Creates the button calling [onPressed].
  const RefreshButton({super.key, required this.onPressed, this.busy = false});

  /// Whether the check is running.
  final bool busy;

  /// Runs the check again.
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TaskButton(
      icon: Icons.refresh,
      tooltip: 'Check again',
      running: busy,
      onRun: onPressed,
    );
  }
}
