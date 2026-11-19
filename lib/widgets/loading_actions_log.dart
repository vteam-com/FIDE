import 'package:fide/constants/constants.dart';
import 'package:fide/models/loading_action.dart';
import 'package:fide/models/status_tone.dart';
import 'package:fide/widgets/inline_spinner.dart';
import 'package:fide/widgets/outlined_surface.dart';
import 'package:fide/widgets/status_indicator.dart';
import 'package:fide/widgets/status_tone_style.dart';
import 'package:fide/widgets/surface_padding.dart';
import 'package:material_ui/material_ui.dart';

/// Scrollable list of load steps in an outlined box, each with a pending,
/// success or failure icon; failed steps are shown in the error color.
class LoadingActionsLog extends StatelessWidget {
  /// Creates a log of [actions].
  const LoadingActionsLog({super.key, required this.actions});

  /// Steps reported so far.
  final List<LoadingAction> actions;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final log = ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: AppSize.statusLogMaxHeight),
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: actions.length,
        itemBuilder: (_, index) {
          final action = actions[index];
          return Padding(
            padding: const EdgeInsets.symmetric(
              vertical: AppSpacing.tiny,
              horizontal: AppSpacing.xLarge,
            ),
            child: Row(
              spacing: AppSpacing.medium,
              children: [
                _buildStatusIcon(action.status),
                Expanded(
                  child: Text(
                    action.text,
                    style: AppTextStyle.label.copyWith(
                      color: action.status == LoadingStatus.failed
                          ? StatusTone.error.readableIn(colorScheme)
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
    return OutlinedSurface(padding: SurfacePadding.none, child: log);
  }

  /// Returns a spinner while [status] is pending, else a success or
  /// error mark.
  Widget _buildStatusIcon(LoadingStatus status) => switch (status) {
    LoadingStatus.pending => const InlineSpinner.small(),
    LoadingStatus.success => StatusIndicator.tone(StatusTone.success),
    LoadingStatus.failed => StatusIndicator.tone(StatusTone.error),
  };
}
