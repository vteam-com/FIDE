import 'package:fide/panels/right/image_details_panel.dart';
import 'package:fide/panels/right/outline_panel.dart';
import 'package:fide/providers/app_providers.dart';
import 'package:fide/providers/center_view.dart';
import 'package:fide/services/file_type_utils.dart';
import 'package:fide/widgets/empty_state.dart';
import 'package:fide/widgets/file_actions.dart';
import 'package:fide/widgets/header_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The Outline tab: the details of the icon picked in the App Icons view
/// while it is open, else of the selected image, else the selected file's
/// outline; the file's path and actions below.
class OutlineTab extends ConsumerWidget {
  /// Creates the tab.
  const OutlineTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final file = ref.watch(selectedFileProvider);
    final iconPath = ref.watch(centerViewProvider) == CenterView.appIcons
        ? ref.watch(appIconSelectionProvider)
        : null;
    final path = iconPath ?? file?.path;
    if (path == null) {
      return const EmptyState(message: 'Select a file to view outline');
    }
    final viewKind = iconPath != null
        ? FileViewKind.image
        : FileTypeUtils.viewKindOf(path);
    return Column(
      children: [
        Expanded(
          child: switch (viewKind) {
            FileViewKind.image => ImageDetailsPanel(path: path),
            FileViewKind.code ||
            FileViewKind.unsupported => OutlinePanel(file: file!),
          },
        ),
        HeaderBar(isFooter: true, child: FileActions(path: path)),
      ],
    );
  }
}
