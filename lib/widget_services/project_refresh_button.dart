import 'package:fide/providers/app_providers.dart';
import 'package:fide/providers/project_info_controller.dart';
import 'package:fide/widgets/message_box.dart';
import 'package:fide/widgets/refresh_button.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// The one way to check the open project again, wherever it shows (the
/// project's header, the Architecture view): analyzes its quality and
/// measures it again, then shows how measuring ended; rings while either
/// runs, unless the tab of the panel showing it rings for the quality
/// ([isRinged]), whose ring wins meanwhile.
class ProjectRefreshButton extends ConsumerWidget {
  /// Creates the button checking the open project again.
  const ProjectRefreshButton({super.key, this.isRinged = false});

  /// Whether the tab of the panel showing the button rings while the
  /// project's quality is analyzed, as the Info tab does: the button is
  /// then only disabled meanwhile, without its ring.
  final bool isRinged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isQualityBusy = ref.watch(projectQualityBusyProvider);
    final isMeasuring = ref.watch(
      projectInfoControllerProvider.select((info) => info.isAnalyzing),
    );
    return RefreshButton(
      busy: (isMeasuring || isQualityBusy) && !(isRinged && isQualityBusy),
      onPressed: isQualityBusy ? null : () => _refresh(context, ref),
    );
  }

  /// Runs the quality's analyses and the measuring again, showing how
  /// measuring ended once it has, while the button is there.
  Future<void> _refresh(BuildContext context, WidgetRef ref) async {
    refreshProjectQuality(ref.invalidate);
    final outcome = await ref
        .read(projectInfoControllerProvider.notifier)
        .analyze();
    if (context.mounted && outcome != null) {
      MessageBox.showOutcome(context, outcome);
    }
  }
}
