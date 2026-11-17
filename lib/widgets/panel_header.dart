import 'package:fide/constants/constants.dart';
import 'package:fide/widgets/header_bar.dart';
import 'package:fide/widgets/truncated_text.dart';
import 'package:material_ui/material_ui.dart';

/// The strip atop a side panel's content naming what it shows: an
/// optional [leading] picture, its [title], an optional [badge] beside it, an optional [subtitle] under
/// it, and its [actions] at the end, such as a `RefreshButton`.
class PanelHeader extends StatelessWidget {
  /// Creates the header titled [title].
  const PanelHeader({
    super.key,
    required this.title,
    this.badge,
    this.leading,
    this.subtitle,
    this.actions = const [],
  });

  /// Buttons at the end of the strip.
  final List<Widget> actions;

  /// A chip right of [title], such as a version; none when null.
  final Widget? badge;

  /// A picture at the start of the strip, such as the project's app icon,
  /// sized [AppIconSize.panelHeaderLeading]; none when null.
  final Widget? leading;

  /// A line under [title], such as a count or a description; none when
  /// null.
  final String? subtitle;

  /// What the panel shows.
  final String title;

  @override
  Widget build(BuildContext context) {
    final subtitle = this.subtitle;
    final badge = this.badge;
    final leading = this.leading;
    return HeaderBar(
      child: Row(
        spacing: AppSpacing.tiny,
        children: [
          ?leading,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  spacing: AppSpacing.tiny,
                  children: [
                    Flexible(
                      child: TruncatedText(
                        title,
                        style: AppTextStyle.captionStrong,
                      ),
                    ),
                    ?badge,
                  ],
                ),
                if (subtitle != null)
                  TruncatedText(
                    subtitle,
                    style: AppTextStyle.secondary(context),
                  ),
              ],
            ),
          ),
          ...actions,
        ],
      ),
    );
  }
}
