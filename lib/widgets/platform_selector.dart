import 'package:fide/constants/constants.dart';
import 'package:fide/models/flutter_platform.dart';
import 'package:fide/widgets/icon_label_tab.dart';
import 'package:fide/widgets/icon_tab_bar.dart';
import 'package:fide/widgets/platform_icon.dart';
import 'package:flutter/material.dart';

/// Represents `PlatformSelector`.
class PlatformSelector extends StatefulWidget {
  const PlatformSelector({
    super.key,
    required this.supportedPlatforms,
    required this.selectedPlatform,
    required this.onPlatformSelected,
  });

  /// Called when the user picks a configured platform.
  final ValueChanged<FlutterPlatform> onPlatformSelected;

  /// The platform currently selected.
  final FlutterPlatform selectedPlatform;

  /// Platforms the project has a folder for; only these can be picked.
  final Set<FlutterPlatform> supportedPlatforms;

  @override
  State<PlatformSelector> createState() => _PlatformSelectorState();
}

class _PlatformSelectorState extends State<PlatformSelector>
    with TickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _setupTabController();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(PlatformSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedPlatform != widget.selectedPlatform ||
        oldWidget.supportedPlatforms != widget.supportedPlatforms) {
      _updateTabController();
    }
  }

  @override
  Widget build(BuildContext context) {
    const platforms = FlutterPlatform.values;

    return IconTabBar(
      controller: _tabController,
      labelBreakpoint: AppSize.platformSelectorLabelBreakpoint,
      tabsBuilder: (showLabels) => platforms.map((p) {
        final isSupported = widget.supportedPlatforms.contains(p);
        return IconLabelTab(
          height: showLabels ? AppIconSize.emptyState : AppSize.titleBarHeight,
          showLabel: showLabels,
          label: p.displayName,
          tooltip: isSupported
              ? p.displayName
              : '${p.displayName} (not configured)',
          icon: PlatformIcon(
            platform: p,
            size: showLabels ? AppIconSize.large : AppIconSize.mediumLarge,
            isSupported: isSupported,
            isSelected: widget.selectedPlatform == p,
          ),
        );
      }).toList(),
    );
  }

  /// Creates and configures the [TabController] based on the ordered list of supported platforms.
  void _setupTabController() {
    _tabController = TabController(
      length: FlutterPlatform.values.length,
      vsync: this,
      initialIndex: widget.selectedPlatform.index,
    );

    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return;
      final platform = FlutterPlatform.values[_tabController.index];
      if (widget.supportedPlatforms.contains(platform)) {
        widget.onPlatformSelected(platform);
      }
    });
  }

  /// Recreates the [TabController] when the set of supported platforms changes.
  void _updateTabController() {
    final targetIndex = widget.selectedPlatform.index;
    if (_tabController.index != targetIndex) {
      _tabController.animateTo(targetIndex);
    }
  }
}
