import 'package:fide/constants/constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:url_launcher/url_launcher.dart';

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
    final baseStyle = theme.textTheme.bodyMedium!.copyWith(color: color);
    final codeStyle = AppTextStyle.monospace.copyWith(
      color: color,
      fontSize: AppFontSize.caption,
      backgroundColor: codeBackground,
    );
    return MarkdownBody(
      data: data,
      selectable: true,
      onTapLink: (_, href, _) => _openLink(href),
      styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
        p: baseStyle,
        listBullet: baseStyle,
        tableBody: baseStyle,
        tableHead: baseStyle.copyWith(fontWeight: FontWeight.bold),
        h1: theme.textTheme.titleLarge!.copyWith(color: color),
        h2: theme.textTheme.titleMedium!.copyWith(color: color),
        h3: theme.textTheme.titleSmall!.copyWith(color: color),
        strong: const TextStyle(fontWeight: FontWeight.bold),
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

  /// Opens [href] in the system browser when it parses as a URI.
  Future<void> _openLink(String? href) async {
    final uri = href == null ? null : Uri.tryParse(href);
    if (uri != null) await launchUrl(uri);
  }
}
