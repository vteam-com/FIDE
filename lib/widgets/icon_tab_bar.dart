import 'package:fide/constants/constants.dart';
import 'package:flutter/material.dart';

/// A scrollable, start-aligned bar of icon tabs (usually `IconLabelTab`)
/// whose labels hide, leaving tooltips, once the bar is no wider than
/// [labelBreakpoint].
class IconTabBar extends StatelessWidget {
  /// Creates a bar driven by [controller] with the tabs from [tabsBuilder].
  const IconTabBar({
    super.key,
    required this.controller,
    required this.tabsBuilder,
    this.labelBreakpoint = AppSize.tabLabelBreakpoint,
  });

  /// Selects the tab.
  final TabController controller;

  /// Width above which the tabs show their labels.
  final double labelBreakpoint;

  /// Builds the tabs, with labels when `showLabels` is true.
  final List<Widget> Function(bool showLabels) tabsBuilder;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, constraints) {
        final showLabels = constraints.maxWidth > labelBreakpoint;
        return TabBar(
          controller: controller,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          labelPadding: showLabels
              ? AppPadding.actionTabLabelExpanded
              : AppPadding.actionTabLabelCompact,
          tabs: tabsBuilder(showLabels),
        );
      },
    );
  }
}
