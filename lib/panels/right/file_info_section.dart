import 'package:fide/panels/right/image_details_panel.dart';
import 'package:fide/services/file_type_utils.dart';
import 'package:fide/widget_services/file_actions.dart';
import 'package:fide/widgets/section_panel.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;

/// The Info tab's section about one file, titled by its name: its path
/// and actions, then for an image everything FIDE reads from it.
class FileInfoSection extends StatelessWidget {
  /// Creates the section about the file at [path].
  const FileInfoSection({super.key, required this.path});

  /// The file described, as an absolute path.
  final String path;

  @override
  Widget build(BuildContext context) {
    return SectionPanel(
      title: p.basename(path),
      isExpanded: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FileActions(path: path),
          if (FileTypeUtils.isImageFile(path)) ImageDetailsPanel(path: path),
        ],
      ),
    );
  }
}
