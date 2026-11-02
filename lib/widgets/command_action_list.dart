import 'package:fide/providers/command_runner.dart';
import 'package:fide/widgets/action_list.dart';
import 'package:fide/widgets/panel_action.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// [ActionList] for actions run by [commandRunnerProvider]: each shows its
/// run's status and stops its process.
class CommandActionList extends ConsumerWidget {
  /// Creates the list of [actions].
  const CommandActionList({super.key, required this.actions});

  /// The actions, in display order; their status comes from the runner.
  final List<PanelAction> actions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final runs = ref.watch(commandRunnerProvider);
    final runner = ref.read(commandRunnerProvider.notifier);
    return ActionList(
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
