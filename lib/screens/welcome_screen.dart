import 'package:fide/constants/constants.dart';
import 'package:fide/providers/app_providers.dart';
import 'package:fide/providers/app_view_notifier.dart';
import 'package:fide/theme/app_theme.dart';
import 'package:fide/widgets/compact_icon_button.dart';
import 'package:fide/widgets/hero_title_widget.dart';
import 'package:fide/widgets/outlined_list_tile.dart';
import 'package:fide/widgets/outlined_surface.dart';
import 'package:fide/widgets/primary_button.dart';
import 'package:fide/widgets/secondary_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;

/// The welcome screen: open or create a project, or reopen a recent one.
class WelcomeScreen extends ConsumerStatefulWidget {
  /// Creates the welcome screen.
  const WelcomeScreen({super.key});

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen> {
  String _appVersion = '1.0.0';

  @override
  void initState() {
    super.initState();
    _loadAppVersion();
  }

  @override
  Widget build(BuildContext context) {
    final view = ref.read(appViewProvider.notifier);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.huge),
      decoration: AppTheme.screenBackground(context),
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
                  HeroTitleWidget(
                    title: 'Welcome to FIDE',
                    subTitle: 'Flutter Integrated Developer Environment',
                  ),
                  // Version Info
                  Text(
                    'Version\n$_appVersion',
                    style: AppTextStyle.secondary(context),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
              // Scrollable content taking remaining space
              Expanded(
                child: SingleChildScrollView(
                  child: Center(
                    child: SizedBox(
                      width: AppSize.welcomeContentWidth,
                      child: OutlinedSurface(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          spacing: AppSpacing.xLarge,
                          children: [
                            PrimaryButton(
                              onPressed: view.pickAndOpenProject,
                              icon: Icons.folder_open,
                              label: 'Open Flutter Project',
                            ),
                            SecondaryButton(
                              onPressed: view.showCreateProject,
                              icon: Icons.add,
                              label: 'Create New Project',
                            ),
                            // Recent Projects Section
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: _buildRecentProjectsList(),
                            ),
                          ],
                        ),
                      ),
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

  /// Builds the list of recent project tiles from [mruFolders], limited to the most recent entries.
  List<Widget> _buildRecentProjectsList() {
    final accessibleFolders = ref.watch(accessibleMruFoldersProvider);
    final validMruFolders = ref
        .watch(mruFoldersProvider)
        .where((path) => path.isNotEmpty)
        .take(AppMetric.mruFolderLimit) // Limit to configured recent projects
        .toList();

    return validMruFolders.map((path) {
      final projectName = p.basename(path);
      final hasAccess = accessibleFolders.contains(path);

      return OutlinedListTile(
        icon: hasAccess ? Icons.folder : Icons.folder_off,
        iconColor: hasAccess ? null : Theme.of(context).colorScheme.error,
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

  /// Fetches the app version from the package info plugin and stores it in [_appVersion].
  Future<void> _loadAppVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() {
          _appVersion = packageInfo.version;
        });
      }
    } catch (_) {
      // Keep default version if loading fails
    }
  }
}
