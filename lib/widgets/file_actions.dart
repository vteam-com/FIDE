import 'package:fide/constants/constants.dart';
import 'package:fide/providers/app_providers.dart';
import 'package:fide/providers/center_view.dart';
import 'package:fide/providers/editor_navigation.dart';
import 'package:fide/providers/panel_actions.dart';
import 'package:fide/providers/service_providers.dart';
import 'package:fide/widgets/compact_icon_button.dart';
import 'package:fide/widgets/compact_text_button.dart';
import 'package:fide/widgets/copy_button.dart';
import 'package:fide/widgets/message_box.dart';
import 'package:fide/widgets/path_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

/// The full path of a file, buttons copying the path or the file name, and
/// buttons revealing it in FIDE's Explorer, opening it in FIDE (unless it
/// is the open tab already, in view) or the OS's default app, and
/// revealing it in the file manager. Opened from a center view, closing
/// the file returns to the view.
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

    /// Runs [action], telling the user when it fails to [verb] the file.
    Future<void> runOrShowError(
      Future<void> Function() action,
      String verb,
    ) async {
      try {
        await action();
      } catch (e) {
        if (context.mounted) {
          MessageBox.showError(context, 'Failed to $verb the file: $e');
        }
      }
    }

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
            CopyButton(
              text: path,
              tooltip: 'Copy Full Path',
              confirmation: 'Full path copied to clipboard',
            ),
            CompactIconButton(
              icon: Icons.insert_drive_file_outlined,
              tooltip: 'Copy File Name',
              onPressed: () => MessageBox.copyToClipboard(
                context,
                p.basename(path),
                confirmation: 'File name copied to clipboard',
              ),
            ),
          ],
        ),
        Wrap(
          spacing: AppSpacing.small,
          runSpacing: AppSpacing.tiny,
          children: [
            CompactTextButton(
              icon: Icons.account_tree_outlined,
              label: 'Reveal in FIDE Explorer',
              onPressed: () => revealInExplorer(ref, path),
            ),
            if (!isShown)
              CompactTextButton(
                icon: Icons.open_in_new,
                label: 'Open in FIDE',
                onPressed: () => openFromCenterView(ref, path),
              ),
            CompactTextButton(
              icon: Icons.launch,
              label: 'Open in Default App',
              onPressed: () =>
                  runOrShowError(() => shell.openWithDefaultApp(path), 'open'),
            ),
            CompactTextButton(
              icon: Icons.folder_open,
              label: 'Reveal in ${shell.fileManagerName}',
              onPressed: () =>
                  runOrShowError(() => shell.revealFile(path), 'reveal'),
            ),
          ],
        ),
      ],
    );
  }
}
