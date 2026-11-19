import 'package:fide/constants/constants.dart';
import 'package:fide/models/status_tone.dart';
import 'package:fide/theme/app_theme.dart';
import 'package:fide/widgets/status_tone_style.dart';
import 'package:fide/widgets/task_ring.dart';
import 'package:material_ui/material_ui.dart';

/// The one button for a task the user starts with a click, such as Build,
/// Run or Test, Send in the AI prompt, writing the commit message with AI,
/// or a panel's Refresh.
///
/// Idle, a round tonal button showing the task's [icon], or, when
/// [prominent], one filled with the theme's accent color. While [running],
/// a ring spins around it, the task's only progress indicator, and a red
/// Stop takes its place, or, for a task that can't be stopped (no
/// [onStop]), the disabled [icon]; the ring stops once the task is
/// [live], such as an app that has launched and runs until stopped.
class TaskButton extends StatelessWidget {
  /// Creates the button starting the task with [onRun] and stopping it
  /// with [onStop].
  const TaskButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onRun,
    this.onStop,
    this.running = false,
    this.live = false,
    this.prominent = false,
    this.stopTooltip = 'Stop (Esc)',
  });

  /// Glyph of the idle button, naming the task.
  final IconData icon;

  /// Whether the running task is past its startup, which stops the ring.
  final bool live;

  /// Starts the task; the idle button is disabled when null.
  final VoidCallback? onRun;

  /// Stops the task; null for a task that can't be stopped, which shows
  /// its disabled [icon] while it runs.
  final VoidCallback? onStop;

  /// Whether the idle button asks for attention, filled with the theme's
  /// accent color rather than tonal, for a task waiting for the user,
  /// such as installing a newer release.
  final bool prominent;

  /// Whether the task is in progress, showing Stop.
  final bool running;

  /// Hover text of the Stop button.
  final String stopTooltip;

  /// Hover text of the idle button, naming the task.
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    const constraints = BoxConstraints.tightFor(
      width: AppSize.compactActionButton,
      height: AppSize.compactActionButton,
    );
    final onStop = this.onStop;
    final button = running && onStop != null
        ? IconButton.filled(
            onPressed: onStop,
            tooltip: stopTooltip,
            constraints: constraints,
            padding: EdgeInsets.zero,
            style: IconButton.styleFrom(
              backgroundColor: StatusTone.error.color,
              foregroundColor: AppTheme.onFill(StatusTone.error.color),
            ),
            icon: const Icon(Icons.stop_rounded, size: AppIconSize.mediumLarge),
          )
        // Both styles take the same arguments
        : (prominent ? IconButton.filled : IconButton.filledTonal)(
            onPressed: running ? null : onRun,
            tooltip: tooltip,
            constraints: constraints,
            padding: EdgeInsets.zero,
            icon: Icon(icon, size: AppIconSize.mediumLarge),
          );
    return TaskRing(
      size: AppSize.actionButtonRing,
      spinning: running && !live,
      child: button,
    );
  }
}
