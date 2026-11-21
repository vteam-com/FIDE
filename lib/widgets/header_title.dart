import 'package:fide/constants/constants.dart';
import 'package:fide/widgets/truncated_text.dart';
import 'package:material_ui/material_ui.dart';

/// A header's name, the same in every header: [title] on one line, an
/// optional [badge] beside it and an optional [subtitle] under it, wrapped,
/// as a narrow panel has height to spare but little width; [isHero] draws
/// the title at a page's size.
class HeaderTitle extends StatelessWidget {
  /// Creates the name [title].
  const HeaderTitle({
    super.key,
    required this.title,
    this.badge,
    this.subtitle,
    this.isHero = false,
  });

  /// A chip right of [title], such as a version; none when null.
  final Widget? badge;

  /// Whether [title] is a page's, drawn large, rather than a panel's.
  final bool isHero;

  /// A line under [title], such as a count or a description; none when
  /// null.
  final String? subtitle;

  /// What the header shows.
  final String title;

  @override
  Widget build(BuildContext context) {
    final subtitle = this.subtitle;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: AppSpacing.micro,
      children: [
        Row(
          spacing: AppSpacing.medium,
          children: [
            Flexible(
              child: TruncatedText(
                title,
                style: isHero
                    ? AppTextStyle.display
                    : AppTextStyle.captionStrong,
              ),
            ),
            ?badge,
          ],
        ),
        if (subtitle != null)
          TruncatedText(
            subtitle,
            style: AppTextStyle.secondary(context),
            maxLines: AppMetric.panelHeaderSubtitleMaxLines,
          ),
      ],
    );
  }
}
