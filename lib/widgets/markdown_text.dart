import 'package:fide/constants/constants.dart';
import 'package:fide/widgets/open_url.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

/// Renders Markdown [data] as selectable rich text in [color].
///
/// Code spans and fenced blocks use [AppTextStyle.monospace] on a tinted
/// background; links open in the system browser.
class MarkdownText extends StatelessWidget {
  /// Creates a Markdown view of [data] drawn in [color].
  const MarkdownText({super.key, required this.data, required this.color});

  /// The base text color; headings, lists and code inherit it.
  final Color color;

  /// The Markdown source to render.
  final String data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final codeBackground = theme.colorScheme.surface;
    final baseStyle = AppTextStyle.label.copyWith(color: color);
    final codeStyle = AppTextStyle.code.copyWith(
      color: color,
      backgroundColor: codeBackground,
    );
    return MarkdownBody(
      data: data,
      selectable: true,
      onTapLink: (_, href, _) {
        if (href != null) openUrl(context, href);
      },
      styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
        p: baseStyle,
        listBullet: baseStyle,
        tableBody: baseStyle,
        tableHead: baseStyle.merge(AppTextStyle.strong),
        h1: AppTextStyle.headline.copyWith(color: color),
        h2: AppTextStyle.title.copyWith(color: color),
        h3: AppTextStyle.title.copyWith(color: color),
        strong: AppTextStyle.strong,
        code: codeStyle,
        codeblockPadding: const EdgeInsets.all(AppSpacing.medium),
        codeblockDecoration: BoxDecoration(
          color: codeBackground,
          borderRadius: BorderRadius.circular(AppSpacing.tiny),
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
  }
}
