import 'package:fide/constants/constants.dart';
import 'package:fide/providers/app_providers.dart';
import 'package:fide/providers/center_view.dart';
import 'package:fide/providers/service_providers.dart';
import 'package:fide/widget_services/file_action.dart';
import 'package:fide/widgets/compact_icon_button.dart';
import 'package:fide/widgets/compact_text_button.dart';
import 'package:fide/widgets/path_text.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// The full path of a file, then its [FileAction]s: the copies as icons
/// beside the path, the others as buttons under it; Open in FIDE only
/// while the file isn't the open tab already, in view. Opened from a
/// center view, closing the file returns to the view.
class FileActions extends ConsumerWidget {
  /// Creates the actions of the file at [path].
  const FileActions({super.key, required this.path});

  /// The file, as an absolute path.
  final String path;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isShown =
        ref.watch(
          activeDocumentProvider.select((doc) => doc?.filePath == path),
        ) &&
        ref.watch(centerViewProvider) == null;
    final shell = ref.read(desktopShellProvider);
    final projectPath = ref.watch(currentProjectPathProvider);
    final actions = [
      for (final action in FileAction.values)
        if (action.appliesTo(
              path,
              isDirectory: false,
              projectPath: projectPath,
            ) &&
            !(action == FileAction.open && isShown))
          action,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: AppSpacing.small,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: AppSpacing.tiny,
          children: [
            Expanded(
              child: PathText(
                path,
                selectable: true,
                style: AppTextStyle.caption,
              ),
            ),
            for (final action in actions)
              if (action.isCopy)
                CompactIconButton(
                  icon: action.icon,
                  tooltip: action.labelIn(shell),
                  onPressed: () => action.run(context, ref, path),
                ),
          ],
        ),
        Wrap(
          spacing: AppSpacing.small,
          runSpacing: AppSpacing.tiny,
          children: [
            for (final action in actions)
              if (!action.isCopy)
                CompactTextButton(
                  icon: action.icon,
                  label: action.labelIn(shell),
                  onPressed: () => action.run(context, ref, path),
                ),
          ],
        ),
      ],
    );
  }
}
