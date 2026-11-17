import 'package:fide/providers/command_runner.dart';
import 'package:fide/widget_services/output_panel.dart';
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
    // Only this log's text: other logs and status changes don't rebuild it
    final (:errors, :output) = ref.watch(
      commandRunnerProvider.select((runs) {
        final log = runs.logOf(logKey);
        return (errors: log.errors, output: log.output);
      }),
    );
    void clear() => ref.read(commandRunnerProvider.notifier).clearLog(logKey);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (errors.isNotEmpty)
          OutputPanel(
            title: 'Errors',
            isExpanded: true,
            text: errors,
            onClear: clear,
          ),
        if (output.isNotEmpty)
          OutputPanel(
            title: 'Output',
            isExpanded: true,
            text: output,
            onClear: clear,
          ),
      ],
    );
  }
}
