import 'package:fide/providers/ai_request.dart';
import 'package:fide/providers/command_runner.dart';
import 'package:fide/widget_services/output_panel.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The errors and output of a [commandRunnerProvider] log, each in an
/// [OutputPanel] shown once it has text; errors of the last failed build
/// ([lastBuildErrorsProvider]) offer Fix with AI, which has the AI panel's
/// Fix Build edit the project until it builds.
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
    // Fix Build sends the last failed build's errors: offered only when
    // they are the ones shown, not another platform's or a test run's
    final isLastBuildFailure = ref.watch(
      lastBuildErrorsProvider.select(
        (last) => last.isNotEmpty && last == errors,
      ),
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
            onFixWithAi: isLastBuildFailure
                ? () => ref.read(aiRequestsProvider).fixBuild()
                : null,
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
