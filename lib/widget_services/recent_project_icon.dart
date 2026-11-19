import 'package:fide/constants/constants.dart';
import 'package:fide/models/status_tone.dart';
import 'package:fide/widget_services/project_icon.dart';
import 'package:fide/widgets/status_tone_style.dart';
import 'package:material_ui/material_ui.dart';

/// A recent project's picture, alike in the welcome screen's list and the
/// title bar's project menu: its app icon ([ProjectIcon]) while its folder
/// can be opened, else a crossed-out folder in the error color.
class RecentProjectIcon extends StatelessWidget {
  /// Creates the picture of the recent project at [projectPath].
  const RecentProjectIcon({
    super.key,
    required this.projectPath,
    required this.hasAccess,
    this.size = AppIconSize.medium,
  });

  /// Whether the project's folder can be opened.
  final bool hasAccess;

  /// The project's root folder.
  final String projectPath;

  /// Width and height.
  final double size;

  @override
  Widget build(BuildContext context) {
    return hasAccess
        ? ProjectIcon(projectPath: projectPath, size: size)
        : Icon(
            Icons.folder_off,
            size: size,
            color: StatusTone.error.readableIn(Theme.of(context).colorScheme),
          );
  }
}
