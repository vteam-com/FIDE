import 'package:fide/constants/constants.dart';
import 'package:fide/widget_services/loading_actions_progress.dart';
import 'package:fide/widgets/centered_scroll_view.dart';
import 'package:fide/widgets/hero_title_widget.dart';
import 'package:fide/widgets/path_text.dart';
import 'package:fide/widgets/screen_scaffold.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;

/// Full-screen progress view shown while a project loads.
///
/// Transparent, so the workspace gradient shows through behind it. The app
/// leaves it once loading ends, for the IDE or, on a failure, the welcome
/// screen.
class LoadingScreen extends StatelessWidget {
  /// Creates the loading view for the project at [loadingProjectName].
  const LoadingScreen({super.key, required this.loadingProjectName});

  /// Full path of the project being loaded.
  final String? loadingProjectName;

  @override
  Widget build(BuildContext context) {
    final projectPath = loadingProjectName!;
    return ScreenScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HeroTitleWidget(
            title: 'Loading ${p.basename(projectPath)}',
            subWidget: PathText(
              projectPath,
              selectable: true,
              style: AppTextStyle.label,
            ),
          ),
          const SizedBox(height: AppSpacing.huge),
          const Expanded(
            child: CenteredScrollView(
              maxWidth: AppSize.wizardMaxWidth,
              child: LoadingActionsProgress(
                failureMessage:
                    'Project loading failed. Please check the errors above.',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
