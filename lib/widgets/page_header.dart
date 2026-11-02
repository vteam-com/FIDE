import 'package:fide/widgets/hero_title_widget.dart';
import 'package:flutter/material.dart';

/// The top row of a full page in the center area or a screen: its hero
/// title filling the width, then compact [actions] such as refresh and
/// close.
class PageHeader extends StatelessWidget {
  /// Creates the header for the page titled [title].
  const PageHeader({
    super.key,
    required this.title,
    required this.logo,
    this.subTitle,
    this.actions = const [],
  });

  /// Buttons at the end of the row, usually `CompactIconButton`s.
  final List<Widget> actions;

  /// Shown left of [title].
  final Widget logo;

  /// Line under [title]; none when null.
  final String? subTitle;

  /// The page name.
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: HeroTitleWidget(title: title, subTitle: subTitle, logo: logo),
        ),
        ...actions,
      ],
    );
  }
}
