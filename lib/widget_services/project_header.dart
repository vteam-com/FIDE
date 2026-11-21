import 'package:fide/constants/constants.dart';
import 'package:fide/providers/app_providers.dart';
import 'package:fide/providers/project_info_controller.dart';
import 'package:fide/widget_services/project_icon.dart';
import 'package:fide/widgets/badge_status.dart';
import 'package:fide/widgets/header_title.dart';
import 'package:fide/widgets/message_box.dart';
import 'package:fide/widgets/refresh_button.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;

/// The open project's identity, the same on every surface showing it, the
/// project overview and the Info tab: its app icon, name, version and
/// description, then the button checking it again and [actions].
/// Hero-sized once it has the width of two overview cards, compact in a
/// narrower panel; nothing without an open project.
class ProjectHeader extends ConsumerWidget {
  /// Creates the header of the open project.
  const ProjectHeader({
    super.key,
    this.isRinged = false,
    this.actions = const [],
  });

  /// Buttons after the refresh button, such as the overview's close.
  final List<Widget> actions;

  /// Whether the tab of the panel showing the header rings while the
  /// project's quality is analyzed, as the Info tab does: the refresh
  /// button is then only disabled meanwhile, without its ring.
  final bool isRinged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectPath = ref.watch(currentProjectPathProvider);
    if (projectPath == null) return const SizedBox.shrink();
    final metrics = ref.watch(projectMetricsProvider);
    final version = metrics.version;
    final refresh = _buildRefreshButton(context, ref);
    return LayoutBuilder(
      builder: (_ /*context*/, constraints) {
        final isHero = constraints.maxWidth >= AppSize.heroHeaderMinWidth;
        return Row(
          spacing: AppSpacing.tiny,
          children: [
            Expanded(
              child: Row(
                spacing: isHero ? AppSpacing.huge : AppSpacing.medium,
                children: [
                  ProjectIcon(
                    projectPath: projectPath,
                    size: isHero
                        ? AppSize.heroLogoHeight
                        : AppIconSize.headerLogo,
                  ),
                  Expanded(
                    child: HeaderTitle(
                      title: metrics.name ?? p.basename(projectPath),
                      badge: version == null
                          ? null
                          : BadgeStatus.info(text: 'v$version', large: isHero),
                      subtitle: metrics.description,
                      isHero: isHero,
                    ),
                  ),
                ],
              ),
            ),
            refresh,
            ...actions,
          ],
        );
      },
    );
  }

  /// Analyzes the project's quality and measures it again, the one way to
  /// check the project again: rings while either runs, unless the tab
  /// rings for the quality ([isRinged]), whose ring wins meanwhile.
  Widget _buildRefreshButton(BuildContext context, WidgetRef ref) {
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
  /// measuring ended once it has, while the header is there.
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
