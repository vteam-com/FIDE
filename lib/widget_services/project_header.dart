import 'package:fide/constants/constants.dart';
import 'package:fide/providers/app_providers.dart';
import 'package:fide/widget_services/project_icon.dart';
import 'package:fide/widget_services/project_refresh_button.dart';
import 'package:fide/widgets/badge_status.dart';
import 'package:fide/widgets/header_title.dart';
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
  /// project's quality is analyzed, as the Info tab does: see
  /// [ProjectRefreshButton.isRinged].
  final bool isRinged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectPath = ref.watch(currentProjectPathProvider);
    if (projectPath == null) return const SizedBox.shrink();
    final metrics = ref.watch(projectMetricsProvider);
    final version = metrics.version;
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
            ProjectRefreshButton(isRinged: isRinged),
            ...actions,
          ],
        );
      },
    );
  }
}
