import 'package:fide/providers/panel_actions.dart';
import 'package:fide/providers/panel_tab.dart';
import 'package:fide/providers/side_panel.dart';
import 'package:fide/widgets/panel_tab_header.dart';
import 'package:fide/widgets/panel_tab_spec.dart';
import 'package:fide/widgets/panel_tabs.dart';
import 'package:fide/widgets/svg_icon.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:material_ui/material_ui.dart';

/// A side panel's tabs, the left one's and the right one's alike: one
/// header per spec of [tabs] and its content under it, showing the tab
/// [selected] holds. Tapping a tab selects it; tapping the selected one
/// again expands or contracts the panel.
class SidePanelTabs<T extends PanelTab> extends ConsumerStatefulWidget {
  /// Creates the tabs of [side].
  const SidePanelTabs({
    super.key,
    required this.side,
    required this.tabs,
    required this.selected,
    this.showTabBar = true,
  });

  /// The tab showing, which menus and shortcuts select too.
  final StateProvider<T> selected;

  /// Whether the tab bar is drawn above the content.
  final bool showTabBar;

  /// The panel the tabs belong to.
  final SidePanel side;

  /// The tabs, in display order.
  final List<PanelTabSpec<T>> tabs;

  @override
  ConsumerState<SidePanelTabs<T>> createState() => _SidePanelTabsState<T>();
}

class _SidePanelTabsState<T extends PanelTab>
    extends ConsumerState<SidePanelTabs<T>>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController = TabController(
    length: widget.tabs.length,
    initialIndex: _indexOf(ref.read(widget.selected)),
    vsync: this,
  );

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Show the tab the provider selects, such as one a menu opened
    ref.listen<T>(widget.selected, (_, next) {
      final index = _indexOf(next);
      if (_tabController.index != index) _tabController.animateTo(index);
    });

    return PanelTabs(
      controller: _tabController,
      showTabBar: widget.showTabBar,
      onTap: (index) =>
          ref.read(widget.selected.notifier).state = widget.tabs[index].tab,
      onReselect: () => togglePanelExpanded(ref, widget.side),
      tabs: [
        for (final spec in widget.tabs)
          PanelTabHeader(
            key: spec.tab.key,
            tooltip: spec.tab.tooltip,
            badgeCount: spec.badgeCount(ref),
            busy: spec.isBusy(ref),
            icon: _glyph(spec.tab),
          ),
      ],
      children: [for (final spec in widget.tabs) spec.build()],
    );
  }

  /// Where [tab] is in the tab bar.
  int _indexOf(T tab) => widget.tabs.indexWhere((spec) => spec.tab == tab);

  /// [tab]'s icon: its SVG tinted to the tab color, or its Material icon.
  static Widget _glyph(PanelTab tab) {
    final svgAsset = tab.svgAsset;
    return svgAsset == null ? Icon(tab.icon) : SvgIcon(svgAsset);
  }
}
