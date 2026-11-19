import 'package:fide/constants/constants.dart';
import 'package:fide/providers/app_providers.dart';
import 'package:fide/providers/app_view_notifier.dart';
import 'package:fide/providers/service_providers.dart';
import 'package:fide/widget_services/app_command.dart';
import 'package:fide/widget_services/recent_project_icon.dart';
import 'package:fide/widgets/centered_scroll_view.dart';
import 'package:fide/widgets/compact_icon_button.dart';
import 'package:fide/widgets/hero_title_widget.dart';
import 'package:fide/widgets/outlined_list_tile.dart';
import 'package:fide/widgets/outlined_surface.dart';
import 'package:fide/widgets/primary_button.dart';
import 'package:fide/widgets/screen_scaffold.dart';
import 'package:fide/widgets/secondary_button.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;

/// The welcome screen: open or create a project, or reopen a recent one.
class WelcomeScreen extends ConsumerStatefulWidget {
  /// Creates the welcome screen.
  const WelcomeScreen({super.key});

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen> {
  @override
  Widget build(BuildContext context) {
    final appVersion = ref.watch(appVersionProvider).value ?? '';
    return ScreenScaffold(
      child: LayoutBuilder(
        builder: (context, _) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            spacing: AppSpacing.xLarge,
            children: [
              // Fixed content at top (centered)
              Row(
                spacing: AppSpacing.huge,
                children: [
                  // Flexible so a narrow window shortens the title instead
                  // of overflowing the version beside it
                  Flexible(
                    child: HeroTitleWidget(
                      title: 'Welcome to ${AppName.short}',
                      subTitle: AppName.full,
                    ),
                  ),
                  // Version Info
                  Text(
                    'Version\n$appVersion',
                    style: AppTextStyle.secondary(context),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
              // Scrollable content taking remaining space
              Expanded(
                child: CenteredScrollView(
                  maxWidth: AppSize.welcomeContentWidth,
                  child: OutlinedSurface(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      spacing: AppSpacing.xLarge,
                      children: [
                        // The File menu's commands, as the menus show them
                        PrimaryButton(
                          onPressed: () =>
                              AppCommand.openProject.run(context, ref),
                          icon: AppCommand.openProject.icon,
                          label: AppCommand.openProject.label,
                        ),
                        SecondaryButton(
                          onPressed: () =>
                              AppCommand.createProject.run(context, ref),
                          icon: AppCommand.createProject.icon,
                          label: AppCommand.createProject.label,
                        ),
                        // Recent Projects Section
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          spacing: AppSpacing.medium,
                          children: _buildRecentProjectsList(),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// The tiles of the recent projects, which [mruFoldersProvider] keeps
  /// few.
  List<Widget> _buildRecentProjectsList() {
    final accessibleFolders = ref.watch(accessibleMruFoldersProvider);
    return ref.watch(mruFoldersProvider).map((path) {
      final projectName = p.basename(path);
      final hasAccess = accessibleFolders.contains(path);

      return OutlinedListTile(
        leading: RecentProjectIcon(
          projectPath: path,
          hasAccess: hasAccess,
          size: AppIconSize.large,
        ),
        title: projectName,
        subtitle: path,
        trailing: CompactIconButton(
          icon: Icons.close,
          tooltip: 'Remove from recent projects',
          onPressed: () => ref.read(mruFoldersProvider.notifier).remove(path),
        ),
        onTap: hasAccess
            ? () => ref.read(appViewProvider.notifier).loadProject(path)
            : null,
      );
    }).toList();
  }
}
