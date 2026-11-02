import 'package:fide/constants/constants.dart';
import 'package:fide/providers/app_providers.dart';
import 'package:fide/providers/editor_navigation.dart';
import 'package:fide/providers/panel_actions.dart';
import 'package:fide/providers/process_runner.dart';
import 'package:fide/providers/service_providers.dart';
import 'package:fide/widgets/compact_icon_button.dart';
import 'package:fide/widgets/compact_text_button.dart';
import 'package:fide/widgets/full_path_widget.dart';
import 'package:fide/widgets/header_bar.dart';
import 'package:fide/widgets/message_box.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

/// The footer of the Outline tab: the full path of the file it describes,
/// buttons copying the path or the file name, and buttons revealing it in
/// FIDE's Explorer, opening it in FIDE (unless it is the open tab already) or
/// the OS's default app, and revealing it in the file manager.
class FileActionsBar extends ConsumerWidget {
  /// Creates the footer of the file at [path].
  const FileActionsBar({super.key, required this.path});

  /// The file, as an absolute path.
  final String path;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isActive = ref.watch(
      activeDocumentProvider.select((doc) => doc?.filePath == path),
    );
    final processRunner = ref.read(processRunnerProvider);

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

    return HeaderBar(
      isFooter: true,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.medium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: AppSpacing.small,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: AppSpacing.tiny,
              children: [
                Expanded(
                  child: FullPathWidget(
                    path: path,
                    style: AppTextStyle.caption,
                  ),
                ),
                CompactIconButton(
                  icon: Icons.content_copy,
                  tooltip: 'Copy Full Path',
                  onPressed: () => MessageBox.copyToClipboard(
                    context,
                    path,
                    confirmation: 'Path copied to clipboard',
                  ),
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
                if (!isActive)
                  CompactTextButton(
                    icon: Icons.open_in_new,
                    label: 'Open in FIDE',
                    onPressed: () => openFile(ref, path),
                  ),
                CompactTextButton(
                  icon: Icons.launch,
                  label: 'Open in Default App',
                  onPressed: () => runOrShowError(
                    () => processRunner.openWithDefaultApp(path),
                    'open',
                  ),
                ),
                CompactTextButton(
                  icon: Icons.folder_open,
                  label: 'Reveal in ${ProcessRunner.fileManagerName}',
                  onPressed: () => runOrShowError(
                    () => processRunner.revealFile(path),
                    'reveal',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
