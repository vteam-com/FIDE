import 'package:fide/constants/constants.dart';
import 'package:fide/services/file_type_utils.dart';
import 'package:fide/widgets/clickable.dart';
import 'package:fide/widgets/empty_state.dart';
import 'package:fide/widgets/open_url.dart';
import 'package:flutter/material.dart';

/// Renders the placeholder shown for unsupported file types.
class EditorScreenUnsupportedFileView extends StatelessWidget {
  /// Creates the unsupported-file placeholder.
  const EditorScreenUnsupportedFileView({super.key, required this.filePath});

  /// Where users ask for support of new file types.
  static const String _issuesUrl = 'https://github.com/vteam-com/FIDE/issues';

  /// The file that can't be shown.
  final String filePath;

  @override
  Widget build(BuildContext context) {
    final extension = FileTypeUtils.extensionOf(filePath).toUpperCase();
    return EmptyState(
      icon: Icons.insert_drive_file_outlined,
      title: extension.isEmpty
          ? 'Files without an extension are not yet supported'
          : 'The file type .$extension is not yet supported',
      message:
          'Currently supported: most text files including programming '
          'languages, web files, configs, scripts, and images',
      child: Clickable(
        onTap: () => openUrl(context, _issuesUrl),
        child: Text(
          'Request this feature at $_issuesUrl',
          textAlign: TextAlign.center,
          style: AppTextStyle.link(context),
        ),
      ),
    );
  }
}
