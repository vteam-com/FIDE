import 'package:fide/providers/command_runner.dart';
import 'package:fide/widgets/action_tabs.dart';
import 'package:fide/widgets/panel_action.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// [ActionTabsWithExecute] for actions run by [commandRunnerProvider]:
/// each shows its run's status and stops its process.
class CommandActionTabs extends ConsumerWidget {
  /// Creates tabs for [actions], selecting [initialId] first.
  const CommandActionTabs({super.key, required this.actions, this.initialId});

  /// The actions, in tab order; their status comes from the runner.
  final List<PanelAction> actions;

  /// The id of the action selected first, or null for the first tab.
  final String? initialId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final runs = ref.watch(commandRunnerProvider);
    final runner = ref.read(commandRunnerProvider.notifier);
    return ActionTabsWithExecute(
      initialId: initialId,
      actions: [
        for (final action in actions)
          action.withProgress(
            runs.statusOf(action.id),
            onStop: () => runner.stop(action.id),
          ),
      ],
    );
  }
}
