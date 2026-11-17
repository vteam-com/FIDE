import 'package:fide/constants/constants.dart';
import 'package:fide/widgets/header_bar.dart';
import 'package:fide/widgets/truncated_text.dart';
import 'package:material_ui/material_ui.dart';

/// The strip atop a side panel's content naming what it shows: its
/// [title], an optional [subtitle] under it, and its [actions] at the
/// end, such as a `RefreshButton`.
class PanelHeader extends StatelessWidget {
  /// Creates the header titled [title].
  const PanelHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const [],
  });

  /// Buttons at the end of the strip.
  final List<Widget> actions;

  /// A line under [title], such as a count or a version; none when null.
  final String? subtitle;

  /// What the panel shows.
  final String title;

  @override
  Widget build(BuildContext context) {
    final subtitle = this.subtitle;
    return HeaderBar(
      child: Row(
        spacing: AppSpacing.tiny,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TruncatedText(title, style: AppTextStyle.captionStrong),
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
