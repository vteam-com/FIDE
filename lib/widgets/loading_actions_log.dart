import 'package:fide/constants/constants.dart';
import 'package:fide/models/action_status.dart';
import 'package:fide/models/loading_action.dart';
import 'package:fide/widgets/inline_spinner.dart';
import 'package:fide/widgets/outlined_surface.dart';
import 'package:fide/widgets/status_indicator.dart';
import 'package:flutter/material.dart';

/// Scrollable list of load steps, each with a pending, success or failure
/// icon; failed steps are shown in the error color.
class LoadingActionsLog extends StatelessWidget {
  /// Creates a log of [actions].
  const LoadingActionsLog({
    super.key,
    required this.actions,
    this.framed = false,
  });

  /// Steps reported so far.
  final List<LoadingAction> actions;

  /// Whether to draw the log inside an outlined, padded box.
  final bool framed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final log = ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: AppSize.statusLogMaxHeight),
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: actions.length,
        itemBuilder: (context, index) {
          final action = actions[index];
          return Padding(
            padding: EdgeInsets.symmetric(
              vertical: AppSpacing.tiny,
              horizontal: framed ? AppSpacing.xLarge : 0,
            ),
            child: Row(
              spacing: AppSpacing.medium,
              children: [
                _buildStatusIcon(action.status),
                Expanded(
                  child: Text(
                    action.text,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: action.status == LoadingStatus.failed
                          ? colorScheme.error
                          : null,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
    return framed ? OutlinedSurface(padding: EdgeInsets.zero, child: log) : log;
  }

  /// Returns a spinner while [status] is pending, else the shared result
  /// mark.
  Widget _buildStatusIcon(LoadingStatus status) {
    final result = switch (status) {
      LoadingStatus.pending => null,
      LoadingStatus.success => ActionStatus.success,
      LoadingStatus.failed => ActionStatus.error,
    };
    if (result == null) return const InlineSpinner();
    return StatusIndicator.forResult(
          result,
          showLabel: false,
          iconSize: AppIconSize.large,
        ) ??
        const SizedBox.shrink();
  }
}
