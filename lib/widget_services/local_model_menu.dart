import 'package:fide/constants/constants.dart';
import 'package:fide/models/local_model.dart';
import 'package:fide/models/ollama_step.dart';
import 'package:fide/providers/local_model_notifier.dart';
import 'package:fide/providers/ollama_model_provider.dart';
import 'package:fide/providers/ollama_status_notifier.dart';
import 'package:fide/widget_services/ollama_setup_action.dart';
import 'package:fide/widgets/dropdown_menu_button.dart';
import 'package:fide/widgets/icon_menu_item.dart';
import 'package:fide/widgets/truncated_text.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// The local model the AI answers with, as a menu of the models FIDE
/// offers ([LocalModel]), each with the memory it needs: the one in use
/// checked, those not downloaded marked, picking one downloading it.
class LocalModelMenu extends ConsumerWidget {
  /// Creates the menu.
  const LocalModelMenu({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final picked = ref.watch(localModelProvider);
    final model = ref.watch(ollamaModelProvider);
    final isReady = ref.watch(ollamaStatusProvider).value == OllamaStep.ready;
    final isSettingUp = ref.watch(ollamaSetupRunningProvider);
    final style = AppTextStyle.secondary(context);
    return DropdownMenuButton<LocalModel>(
      tooltip: 'Model',
      initialValue: picked,
      itemBuilder: (_) => [
        for (final offered in LocalModel.values)
          IconMenuItem(
            value: offered,
            enabled: !isSettingUp,
            icon: isReady && model.isInUse(offered)
                ? Icons.check
                : model.isDownloaded(offered)
                ? null
                : Icons.download,
            label: offered.label,
            trailing: Text('${offered.minMemoryGb} GB+ RAM', style: style),
          ),
      ],
      onSelected: (offered) => OllamaSetupAction.report(
        context,
        () => ref.read(ollamaStatusProvider.notifier).use(offered),
        OllamaStep.noModel.errorPrefix,
      ),
      label: TruncatedText(
        isSettingUp
            ? 'Setting up ${picked.label}…'
            : isReady
            ? model.label
            : picked.label,
        style: AppTextStyle.caption,
      ),
    );
  }
}
