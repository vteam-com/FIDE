import 'package:fide/widgets/header_bar.dart';
import 'package:flutter/material.dart';

/// The tabbed shell shared by the side panels: an icon [TabBar] above a
/// divider, and the selected tab's content filling the rest.
///
/// Owning the tab bar styling here keeps every side panel's tabs identical.
class PanelTabs extends StatelessWidget {
  /// Creates a tabbed panel driven by [controller].
  const PanelTabs({
    super.key,
    required this.controller,
    required this.tabs,
    required this.children,
    this.onTap,
    this.onReselect,
    this.showTabBar = true,
  });

  /// The content shown under each tab, in [tabs] order.
  final List<Widget> children;

  /// Selects which of [children] is shown; its length matches [tabs].
  final TabController controller;

  /// Called when the already selected tab is tapped again, such as to
  /// expand or contract the panel.
  final VoidCallback? onReselect;

  /// Called with the tapped tab's index.
  final ValueChanged<int>? onTap;

  /// Whether the tab bar is drawn above the content.
  final bool showTabBar;

  /// The tab headers, one per entry in [children].
  final List<Widget> tabs;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ColoredBox(
      color: theme.colorScheme.surfaceContainerLow,
      child: Column(
        children: [
          if (showTabBar)
            HeaderBar.top(
              child: TabBar(
                controller: controller,
                onTap: _handleTap,
                tabs: tabs,
                labelPadding: EdgeInsets.zero,
              ),
            ),
          Expanded(
            child: TabBarView(
              controller: controller,
              physics: const NeverScrollableScrollPhysics(), // Disable swipe gestures
              children: children,
            ),
          ),
        ],
      ),
    );
  }

  /// Reports a tap on tab [index], and a tap on the selected tab as a
  /// reselect: the [TabBar] has already moved to a newly tapped tab, but
  /// its move is still animating, while a reselected tab doesn't move.
  void _handleTap(int index) {
    if (index == controller.index && !controller.indexIsChanging) {
      onReselect?.call();
    }
    onTap?.call(index);
  }
}
