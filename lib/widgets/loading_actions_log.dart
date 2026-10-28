import 'package:fide/constants/constants.dart';
import 'package:fide/models/loading_action.dart';
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
    return Container(
      constraints: const BoxConstraints(maxHeight: AppSize.statusLogMaxHeight),
      decoration: framed
          ? BoxDecoration(
              border: Border.all(
                color: colorScheme.outline.withValues(
                  alpha: AppOpacity.divider,
                ),
              ),
              borderRadius: BorderRadius.circular(AppRadius.medium),
            )
          : null,
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
                _buildStatusIcon(action.status, colorScheme),
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
  }

  /// Returns a spinner, check or error icon for [status].
  Widget _buildStatusIcon(LoadingStatus status, ColorScheme colorScheme) {
    switch (status) {
      case LoadingStatus.pending:
        return SizedBox(
          width: AppIconSize.large,
          height: AppIconSize.large,
          child: CircularProgressIndicator(
            strokeWidth: AppSize.borderThin,
            valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
          ),
        );
      case LoadingStatus.success:
        return const Icon(
          Icons.check_circle,
          color: Colors.green,
          size: AppIconSize.large,
        );
      case LoadingStatus.failed:
        return Icon(
          Icons.error,
          color: colorScheme.error,
          size: AppIconSize.large,
        );
    }
  }
}
