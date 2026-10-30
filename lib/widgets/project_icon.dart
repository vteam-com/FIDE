import 'package:fide/constants/constants.dart';
import 'package:fide/providers/app_providers.dart';
import 'package:fide/widgets/app_icon_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The app icon of the project at [projectPath], the same one the project
/// overview shows, or a folder icon while it loads or when there is none.
class ProjectIcon extends ConsumerWidget {
  /// Creates the icon for the project at [projectPath].
  const ProjectIcon({
    super.key,
    required this.projectPath,
    this.size = AppIconSize.medium,
  });

  /// The project's root folder.
  final String projectPath;

  /// Width and height.
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppIconImage(
      path: ref.watch(projectIconPathProvider(projectPath)).value,
      size: size,
      fallback: Icon(
        Icons.folder,
        size: size,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }
}
