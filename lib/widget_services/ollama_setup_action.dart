import 'package:fide/constants/constants.dart';
import 'package:fide/models/ollama_step.dart';
import 'package:fide/models/readable_error.dart';
import 'package:fide/providers/ollama_status_notifier.dart';
import 'package:fide/widgets/loading_indicator.dart';
import 'package:fide/widgets/message_box.dart';
import 'package:fide/widgets/primary_button.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// Where the local Ollama setup stands and the one button completing it
/// (install, start or download the model), alike in the AI panel and the
/// new-project wizard; "Setting up Ollama…" while that runs.
class OllamaSetupAction extends ConsumerWidget {
  /// Creates the setup's state and action.
  const OllamaSetupAction({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final step = ref.watch(ollamaStatusProvider).value;
    if (step == null) return const LoadingIndicator();
    final actionLabel = step.actionLabel;
    final isFixing = ref.watch(ollamaSetupRunningProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: AppSpacing.medium,
      children: [
        Text(
          isFixing ? 'Setting up Ollama…' : step.message,
          style: AppTextStyle.caption,
        ),
        if (actionLabel != null && !isFixing)
          PrimaryButton(
            onPressed: () => _fix(context, ref, step),
            label: actionLabel,
          ),
      ],
    );
  }

  /// Runs the action completing [step], telling over [context] what it
  /// did or why it failed.
  static Future<void> _fix(
    BuildContext context,
    WidgetRef ref,
    OllamaStep step,
  ) async {
    try {
      final done = await ref.read(ollamaStatusProvider.notifier).fix();
      if (context.mounted && done != null) MessageBox.showInfo(context, done);
    } catch (e) {
      if (context.mounted) {
        MessageBox.showError(
          context,
          '${step.errorPrefix}: ${ReadableError.describe(e)}',
        );
      }
    }
  }
}
