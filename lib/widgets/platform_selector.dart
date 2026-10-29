// ignore_for_file: deprecated_member_use

import 'package:fide/constants/constants.dart';
import 'package:fide/models/flutter_platform.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

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
    final colorScheme = Theme.of(context).colorScheme;

    const platforms = FlutterPlatform.values;

    return LayoutBuilder(
      builder: (_, constraints) {
        final showLabels =
            constraints.maxWidth > AppSize.platformSelectorLabelBreakpoint; // Show labels if wider than 240px

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: TabBar(
            controller: _tabController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelColor: colorScheme.primary,
            unselectedLabelColor: colorScheme.onSurface.withValues(
              alpha: AppOpacity.muted,
            ),
            indicatorColor: colorScheme.primary,
            indicatorSize: TabBarIndicatorSize.tab,
            dividerColor: Colors.transparent,
            labelStyle: const TextStyle(
              fontSize: AppFontSize.caption,
              fontWeight: FontWeight.w600,
            ),
            unselectedLabelStyle: const TextStyle(
              fontSize: AppFontSize.caption,
            ),
            tabs: platforms.map((p) {
              final isSupported = widget.supportedPlatforms.contains(p);
              final isSelected = widget.selectedPlatform == p;
              final needsTooltip = !showLabels;

              final tab = Tab(
                height: showLabels
                    ? AppIconSize.emptyState
                    : AppSize.titleBarHeight,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ColorFiltered(
                      colorFilter: ColorFilter.mode(
                        isSelected
                            ? colorScheme.primary
                            : isSupported
                            ? colorScheme.onSurface.withValues(
                                alpha: AppOpacity.emphasis,
                              )
                            : colorScheme.onSurface.withValues(
                                alpha: AppOpacity.faint,
                              ),
                        BlendMode.srcIn,
                      ),
                      child: SvgPicture.asset(
                        p.iconAsset,
                        width: showLabels
                            ? AppIconSize.large
                            : AppIconSize.mediumLarge,
                        height: showLabels
                            ? AppIconSize.large
                            : AppIconSize.mediumLarge,
                      ),
                    ),
                    if (showLabels) ...[
                      const SizedBox(height: AppSpacing.tiny),
                      Text(
                        p.displayName,
                        style: TextStyle(
                          fontSize: AppFontSize.badge,
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ],
                ),
              );

              // Only wrap with Tooltip when needed (when labels are not shown)
              if (needsTooltip) {
                return Tooltip(
                  message: isSupported
                      ? p.displayName
                      : '${p.displayName} (not configured)',
                  child: tab,
                );
              } else {
                return tab;
              }
            }).toList(),
          ),
        );
      },
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
