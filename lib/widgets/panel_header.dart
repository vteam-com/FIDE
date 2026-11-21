import 'package:fide/constants/constants.dart';
import 'package:fide/widgets/header_bar.dart';
import 'package:fide/widgets/header_title.dart';
import 'package:material_ui/material_ui.dart';

/// The strip atop a side panel's content naming what it shows: its
/// [title] with an optional [subtitle] under it, as a [HeaderTitle], and
/// its [actions] at the end, such as a `RefreshButton`.
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

  /// A line under [title], such as a count; none when null.
  final String? subtitle;

  /// What the panel shows.
  final String title;

  @override
  Widget build(BuildContext context) {
    return HeaderBar(
      child: Row(
        spacing: AppSpacing.tiny,
        children: [
          Expanded(
            child: HeaderTitle(title: title, subtitle: subtitle),
          ),
          ...actions,
        ],
      ),
    );
  }
}
