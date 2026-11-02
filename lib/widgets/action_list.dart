import 'package:fide/constants/constants.dart';
import 'package:fide/models/action_status.dart';
import 'package:fide/theme/app_theme.dart';
import 'package:fide/widgets/compact_icon_button.dart';
import 'package:fide/widgets/outlined_surface.dart';
import 'package:fide/widgets/panel_action.dart';
import 'package:fide/widgets/status_tone_style.dart';
import 'package:fide/widgets/surface_padding.dart';
import 'package:flutter/material.dart';

/// Panel actions as one compact row each: the action's status-aware icon,
/// its title, an info toggle revealing its details, and a round run (or
/// stop) button. Every action stays one click away and shows its own
/// status.
class ActionList extends StatelessWidget {
  /// Creates the list of [actions].
  const ActionList({super.key, required this.actions});

  /// The actions, in display order.
  final List<PanelAction> actions;

  @override
  Widget build(BuildContext context) {
    return OutlinedSurface(
      padding: SurfacePadding.dense,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: AppSpacing.tiny,
        children: [
          for (final action in actions)
            _ActionRow(key: ValueKey(action.id), action: action),
        ],
      ),
    );
  }
}

/// One action of an [ActionList].
class _ActionRow extends StatefulWidget {
  /// Creates the row of [action].
  const _ActionRow({super.key, required this.action});

  /// The action shown.
  final PanelAction action;

  @override
  State<_ActionRow> createState() => _ActionRowState();
}

class _ActionRowState extends State<_ActionRow> {
  /// Whether the details are shown.
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final action = widget.action;
    final colorScheme = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.small),
      child: Material(
        color: action.isRunning
            ? colorScheme.primary.withValues(alpha: AppOpacity.subtle)
            : Colors.transparent,
        child: InkWell(
          onTap: _toggle,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: AppPadding.actionRow,
                child: Row(
                  spacing: AppSpacing.medium,
                  children: [
                    _buildLeading(colorScheme),
                    Expanded(
                      child: Text(
                        action.title,
                        style: AppTextStyle.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    CompactIconButton(
                      icon: _expanded ? Icons.info : Icons.info_outline,
                      tooltip: _expanded ? 'Hide details' : 'Show details',
                      color: _expanded
                          ? colorScheme.primary
                          : colorScheme.onSurfaceVariant,
                      onPressed: _toggle,
                    ),
                    _buildRunButton(colorScheme),
                  ],
                ),
              ),
              AnimatedSize(
                duration: AppDuration.expand,
                alignment: Alignment.topCenter,
                child: _expanded
                    ? Padding(
                        padding: AppPadding.actionRowDetails,
                        child: Text(
                          action.details.trim(),
                          style: AppTextStyle.secondary(context),
                        ),
                      )
                    : const SizedBox(width: double.infinity),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// The result's mark once finished, otherwise the action's own icon: the
  /// row's tint and the ring around its button already mark a run in
  /// progress.
  Widget _buildLeading(ColorScheme colorScheme) {
    final action = widget.action;
    final tone = action.status.resultTone;
    final icon = Icon(
      tone?.icon ?? action.icon,
      size: AppIconSize.large,
      color: AppTheme.readable(tone?.color ?? colorScheme.primary, colorScheme),
    );
    final label = action.status.resultLabel;
    return label == null ? icon : Tooltip(message: label, child: icon);
  }

  /// Runs the action, or stops it while it runs. A ring spins around the
  /// button while the task works, and stops once it is
  /// [ActionStatus.live], such as an app that has launched.
  Widget _buildRunButton(ColorScheme colorScheme) {
    final action = widget.action;
    const constraints = BoxConstraints.tightFor(
      width: AppSize.compactActionButton,
      height: AppSize.compactActionButton,
    );
    final Widget button;
    if (action.isRunning) {
      final onStop = action.onStop;
      button = IconButton.filled(
        onPressed: onStop,
        tooltip: onStop == null ? 'Running...' : 'Stop ${action.title}',
        constraints: constraints,
        padding: EdgeInsets.zero,
        style: IconButton.styleFrom(
          backgroundColor: colorScheme.error,
          foregroundColor: colorScheme.onError,
        ),
        icon: const Icon(Icons.stop_rounded, size: AppIconSize.mediumLarge),
      );
    } else {
      button = IconButton.filledTonal(
        onPressed: action.onRun,
        tooltip: '${action.title}: ${action.description}',
        constraints: constraints,
        padding: EdgeInsets.zero,
        icon: const Icon(
          Icons.play_arrow_rounded,
          size: AppIconSize.mediumLarge,
        ),
      );
    }
    // The slot keeps the ring's size, so rows don't jump when it shows
    return SizedBox.square(
      dimension: AppSize.actionButtonRing,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (action.status == ActionStatus.running)
            const SizedBox.expand(
              child: CircularProgressIndicator(
                strokeWidth: AppBorderWidth.medium,
              ),
            ),
          button,
        ],
      ),
    );
  }

  /// Shows or hides the details.
  void _toggle() => setState(() => _expanded = !_expanded);
}
