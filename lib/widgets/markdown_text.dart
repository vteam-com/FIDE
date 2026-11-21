import 'package:fide/constants/constants.dart';
import 'package:fide/widgets/open_url.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;

/// Renders Markdown [data] as selectable rich text in [color]; inside a
/// `SelectionArea` it is part of that area's selection.
///
/// Code spans and fenced blocks use [AppTextStyle.monospace] on a tinted
/// background; links open in the system browser unless [onTapLink] opens
/// them.
class MarkdownText extends StatelessWidget {
  /// Creates a Markdown view of [data] drawn in [color], its relative
  /// image paths read from [imageDirectory].
  const MarkdownText({
    super.key,
    required this.data,
    required this.color,
    this.imageDirectory,
    this.onTapLink,
  });

  /// The base text color; headings, lists and code inherit it.
  final Color color;

  /// The Markdown source to render.
  final String data;

  /// The folder relative image paths are read from, such as a Markdown
  /// file's own; null when [data] isn't read from a file.
  final String? imageDirectory;

  /// Opens a link's target; null to open it in the system browser.
  final ValueChanged<String>? onTapLink;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final codeBackground = theme.colorScheme.surface;
    final baseStyle = AppTextStyle.label.copyWith(color: color);
    final codeStyle = AppTextStyle.code.copyWith(
      color: color,
      backgroundColor: codeBackground,
    );
    final headingStyle = AppTextStyle.title.copyWith(color: color);
    final divider = BorderSide(color: theme.dividerColor);
    // The package's own fallback reads the SDK material Theme, which a
    // material_ui app doesn't provide: every theme-colored field is set here
    final imageDirectory = this.imageDirectory;
    final body = MarkdownBody(
      data: data,
      // Joined to each image's path as is, so it ends with a separator
      imageDirectory: imageDirectory == null
          ? null
          : '$imageDirectory${p.separator}',
      onTapLink: (_, href, _) {
        if (href == null) return;
        final onTapLink = this.onTapLink;
        onTapLink == null ? openUrl(context, href) : onTapLink(href);
      },
      styleSheet: MarkdownStyleSheet(
        p: baseStyle,
        blockquote: baseStyle,
        img: baseStyle,
        checkbox: baseStyle.copyWith(color: theme.colorScheme.primary),
        listBullet: baseStyle,
        tableBody: baseStyle,
        tableHead: baseStyle.merge(AppTextStyle.strong),
        tableBorder: TableBorder.all(color: divider.color),
        horizontalRuleDecoration: BoxDecoration(border: Border(top: divider)),
        h1: AppTextStyle.headline.copyWith(color: color),
        h2: headingStyle,
        h3: headingStyle,
        h4: headingStyle,
        h5: headingStyle,
        h6: headingStyle,
        strong: AppTextStyle.strong,
        code: codeStyle,
        codeblockPadding: const EdgeInsets.all(AppSpacing.medium),
        codeblockDecoration: BoxDecoration(
          color: codeBackground,
          borderRadius: BorderRadius.circular(AppRadius.tiny),
        ),
        blockquoteDecoration: BoxDecoration(
          border: Border(
            left: BorderSide(
              color: theme.colorScheme.outline,
              width: AppSpacing.micro,
            ),
          ),
        ),
      ),
    );
    // Inside a SelectionArea, such as the AI transcript, it joins that
    // selection so one drag spans several messages
    return SelectionContainer.maybeOf(context) == null
        ? SelectionArea(child: body)
        : body;
  }
}
