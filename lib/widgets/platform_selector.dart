// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class PlatformSelector extends StatefulWidget {
  const PlatformSelector({
    super.key,
    required this.supportedPlatforms,
    required this.selectedPlatform,
    required this.onPlatformSelected,
  });

  final Function(String) onPlatformSelected;

  final String selectedPlatform;

  final Set<String> supportedPlatforms;

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

    final platforms = [
      {
        'name': 'Android',
        'id': 'android',
        'asset': 'assets/platform_android.svg',
      },
      {'name': 'iOS', 'id': 'ios', 'asset': 'assets/platform_ios.svg'},
      {'name': 'Web', 'id': 'web', 'asset': 'assets/platform_web.svg'},
      {'name': 'macOS', 'id': 'macos', 'asset': 'assets/platform_macos.svg'},
      {'name': 'Linux', 'id': 'linux', 'asset': 'assets/platform_linux.svg'},
      {
        'name': 'Windows',
        'id': 'windows',
        'asset': 'assets/platform_windows.svg',
      },
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final showLabels =
            constraints.maxWidth > 300; // Show labels if wider than 240px

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: TabBar(
            controller: _tabController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelColor: colorScheme.primary,
            unselectedLabelColor: colorScheme.onSurface.withValues(alpha: 0.6),
            indicatorColor: colorScheme.primary,
            indicatorSize: TabBarIndicatorSize.tab,
            dividerColor: Colors.transparent,
            labelStyle: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
            unselectedLabelStyle: const TextStyle(fontSize: 12),
            tabs: platforms.map((p) {
              final isSupported = widget.supportedPlatforms.contains(p['id']);
              final isSelected = widget.selectedPlatform == p['id'];
              final needsTooltip = !showLabels;

              final tab = Tab(
                height: showLabels ? 48 : 40,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ColorFiltered(
                      colorFilter: ColorFilter.mode(
                        isSelected
                            ? colorScheme.primary
                            : isSupported
                            ? colorScheme.onSurface.withValues(alpha: 0.8)
                            : colorScheme.onSurface.withValues(alpha: 0.4),
                        BlendMode.srcIn,
                      ),
                      child: SvgPicture.asset(
                        p['asset'] as String,
                        width: showLabels ? 20 : 18,
                        height: showLabels ? 20 : 18,
                      ),
                    ),
                    if (showLabels) ...[
                      const SizedBox(height: 4),
                      Text(
                        (p['name'] as String)
                            .replaceAll('macOS', 'macOS')
                            .replaceAll('iOS', 'iOS'),
                        style: TextStyle(
                          fontSize: 10,
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
                      ? p['name'] as String
                      : '${p['name']} (not configured)',
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

  void _setupTabController() {
    final platformOrder = [
      'android',
      'ios',
      'web',
      'macos',
      'linux',
      'windows',
    ];
    final allPlatforms = platformOrder;

    _tabController = TabController(
      length: allPlatforms.length,
      vsync: this,
      initialIndex: allPlatforms.indexOf(widget.selectedPlatform),
    );

    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return;
      final platformId = allPlatforms[_tabController.index];
      if (widget.supportedPlatforms.contains(platformId)) {
        widget.onPlatformSelected(platformId);
      }
    });
  }

  void _updateTabController() {
    final platformOrder = [
      'android',
      'ios',
      'web',
      'macos',
      'linux',
      'windows',
    ];
    final targetIndex = platformOrder.indexOf(widget.selectedPlatform);
    if (targetIndex >= 0 && _tabController.index != targetIndex) {
      _tabController.animateTo(targetIndex);
    }
  }
}
