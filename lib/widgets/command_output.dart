import 'package:fide/providers/command_runner.dart';
import 'package:fide/widgets/output_panel.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The errors and output of a [commandRunnerProvider] log, each in an
/// [OutputPanel] shown once it has text.
class CommandOutput extends ConsumerWidget {
  /// Creates the view of log [logKey].
  const CommandOutput({super.key, required this.logKey});

  /// Key of the log shown.
  final String logKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final log = ref.watch(commandRunnerProvider).logOf(logKey);
    void clear() => ref.read(commandRunnerProvider.notifier).clearLog(logKey);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (log.hasErrors)
          OutputPanel(
            title: 'Errors',
            isExpanded: true,
            text: log.errors,
            onClear: clear,
          ),
        if (log.hasOutput)
          OutputPanel(
            title: 'Output',
            isExpanded: true,
            text: log.output,
            onClear: clear,
          ),
      ],
    );
  }
}
