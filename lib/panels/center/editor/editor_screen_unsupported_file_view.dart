import 'package:fide/constants/constants.dart';
import 'package:fide/services/file_type_utils.dart';
import 'package:fide/widgets/clickable.dart';
import 'package:fide/widgets/empty_state.dart';
import 'package:fide/widgets/open_url.dart';
import 'package:fide/widgets/primary_button.dart';
import 'package:material_ui/material_ui.dart';

/// Renders the placeholder shown for unsupported file types.
class EditorScreenUnsupportedFileView extends StatelessWidget {
  /// Creates the unsupported-file placeholder.
  const EditorScreenUnsupportedFileView({
    super.key,
    required this.filePath,
    required this.onOpenAsPlainText,
  });

  /// Where users ask for support of new file types.
  static const String _issuesUrl =
      'https://github.com/${AppName.repository}/issues';

  /// The file that can't be shown.
  final String filePath;

  /// Opens [filePath] in the code editor as plain text instead.
  final VoidCallback onOpenAsPlainText;

  @override
  Widget build(BuildContext context) {
    final extension = FileTypeUtils.extensionOf(filePath).toUpperCase();
    return EmptyState(
      icon: Icons.insert_drive_file_outlined,
      title: extension.isEmpty
          ? 'Files without an extension are not yet supported'
          : 'The file type .$extension is not yet supported',
      message: 'Open it as plain text to view and edit it without highlighting',
      child: Column(
        spacing: AppSpacing.xLarge,
        children: [
          PrimaryButton(
            label: 'Open as Plain Text',
            icon: Icons.notes,
            onPressed: onOpenAsPlainText,
          ),
          Clickable(
            onTap: () => openUrl(context, _issuesUrl),
            child: Text(
              'Request support for this type at $_issuesUrl',
              textAlign: TextAlign.center,
              style: AppTextStyle.link(context),
            ),
          ),
        ],
      ),
    );
  }
}
