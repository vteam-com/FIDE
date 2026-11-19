import 'package:fide/models/shortcut_help_entry.dart';
import 'package:fide/widgets/task_button.dart';
import 'package:material_ui/material_ui.dart';

/// The one button that runs a panel's check or analysis again: the same
/// glyph, words and place, the end of the panel's header, everywhere.
///
/// A [TaskButton], so while [busy] the ring spinning around it is the
/// one sign that the panel is working, whether the check started from
/// it or by itself, such as after a save. In a side panel whose tab rings
/// for that check, the tab's ring is that sign: the button is only
/// disabled meanwhile (no [onPressed]), not [busy].
class RefreshButton extends StatelessWidget {
  /// Creates the button calling [onPressed].
  const RefreshButton({
    super.key,
    required this.onPressed,
    this.busy = false,
    this.shortcut,
  });

  /// Whether the check is running.
  final bool busy;

  /// Runs the check again; the button is disabled when null.
  final VoidCallback? onPressed;

  /// Keys a menu item running the same check answers to, named in the
  /// tooltip; none when null.
  final SingleActivator? shortcut;

  @override
  Widget build(BuildContext context) {
    return TaskButton(
      icon: Icons.refresh,
      tooltip: ShortcutHelpEntry.tooltip('Check again', shortcut),
      running: busy,
      onRun: onPressed,
    );
  }
}
