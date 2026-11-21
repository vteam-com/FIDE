import 'dart:io';

import 'package:fide/constants/constants.dart';
import 'package:fide/providers/editor_navigation.dart';
import 'package:fide/services/file_type_utils.dart';
import 'package:fide/widgets/markdown_text.dart';
import 'package:fide/widgets/open_url.dart';
import 'package:fide/widgets/page_scroll_view.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;

/// Shows a Markdown file rendered, as the editor's Markdown toggle asks:
/// its images read beside the file, its links to other files opening them
/// in the editor and its web links in the system browser.
class EditorScreenMarkdownView extends ConsumerWidget {
  /// Creates the rendered view of [text], the content of [filePath].
  const EditorScreenMarkdownView({
    super.key,
    required this.filePath,
    required this.text,
  });

  /// The Markdown file shown, whose folder relative paths start from.
  final String filePath;

  /// The file's content, unsaved edits included.
  final String text;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PageScrollView(
      maxWidth: AppSize.documentMaxWidth,
      children: [
        MarkdownText(
          data: text,
          color: Theme.of(context).colorScheme.onSurface,
          imageDirectory: p.dirname(filePath),
          onTapLink: (href) => _openLink(context, ref, href),
        ),
      ],
    );
  }

  /// Opens [href]: a file the editor opens, given relative to [filePath],
  /// in the editor; any other link in the system browser, which says when
  /// it can't; a link to a heading of this file does nothing.
  Future<void> _openLink(
    BuildContext context,
    WidgetRef ref,
    String href,
  ) async {
    final uri = Uri.tryParse(href);
    if (uri != null && !uri.hasScheme) {
      if (uri.path.isEmpty) return;
      final target = p.normalize(
        p.join(p.dirname(filePath), Uri.decodeComponent(uri.path)),
      );
      if (FileTypeUtils.isFileSupportedInEditor(target) &&
          await File(target).exists()) {
        openFile(ref, target);
        return;
      }
    }
    if (context.mounted) await openUrl(context, href);
  }
}
