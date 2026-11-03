import 'package:fide/models/file_system_item.dart';
import 'package:fide/panels/right/ai_panel.dart';
import 'package:fide/panels/right/image_details_panel.dart';
import 'package:fide/panels/right/info_panel.dart';
import 'package:fide/panels/right/localization/localization_panel.dart';
import 'package:fide/panels/right/outline_panel.dart';
import 'package:fide/providers/app_providers.dart';
import 'package:fide/providers/panel_actions.dart';
import 'package:fide/providers/panel_tab_badges.dart';
import 'package:fide/providers/right_panel_tab.dart';
import 'package:fide/providers/side_panel.dart';
import 'package:fide/providers/ui_state_providers.dart';
import 'package:fide/services/file_type_utils.dart';
import 'package:fide/widgets/empty_state.dart';
import 'package:fide/widgets/file_actions.dart';
import 'package:fide/widgets/header_bar.dart';
import 'package:fide/widgets/panel_tab_header.dart';
import 'package:fide/widgets/panel_tabs.dart';
import 'package:fide/widgets/svg_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Represents `RightPanel`.
class RightPanel extends ConsumerStatefulWidget {
  /// Creates the panel for [selectedFile].
  const RightPanel({super.key, this.selectedFile});

  /// The file whose outline the Outline tab shows.
  final FileSystemItem? selectedFile;

  @override
  ConsumerState<RightPanel> createState() => _RightPanelState();
}

class _RightPanelState extends ConsumerState<RightPanel>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController = TabController(
    length: RightPanelTab.values.length,
    initialIndex: ref.read(activeRightPanelTabProvider).index,
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
    ref.listen<RightPanelTab>(activeRightPanelTabProvider, (_, next) {
      if (_tabController.index != next.index) {
        _tabController.animateTo(next.index);
      }
    });

    return PanelTabs(
      controller: _tabController,
      onTap: (index) {
        ref.read(activeRightPanelTabProvider.notifier).state =
            RightPanelTab.values[index];
      },
      onReselect: () => togglePanelExpanded(ref, SidePanel.right),
      tabs: [
        for (final tab in RightPanelTab.values)
          PanelTabHeader(
            key: tab.key,
            tooltip: tab.tooltip,
            badgeCount: ref.watch(rightPanelTabBadgeProvider(tab)),
            icon: _buildTabIcon(tab),
          ),
      ],
      children: [for (final tab in RightPanelTab.values) _buildTab(tab)],
    );
  }

  /// The Outline tab: the details of the image at [iconPath] when given,
  /// else of the selected image, else the selected file's outline; the
  /// file's path and actions below.
  Widget _buildOutline(String? iconPath) {
    final file = widget.selectedFile;
    final path = iconPath ?? file?.path;
    if (path == null) {
      return const EmptyState(message: 'Select a file to view outline');
    }
    final viewKind = iconPath != null
        ? FileViewKind.image
        : FileTypeUtils.viewKindOf(path);
    return Column(
      children: [
        Expanded(
          child: switch (viewKind) {
            FileViewKind.image => ImageDetailsPanel(path: path),
            FileViewKind.code ||
            FileViewKind.unsupported => OutlinePanel(file: file!),
          },
        ),
        HeaderBar(isFooter: true, child: FileActions(path: path)),
      ],
    );
  }

  /// The panel shown under [tab].
  Widget _buildTab(RightPanelTab tab) {
    return switch (tab) {
      RightPanelTab.outline => Consumer(
        builder: (_, ref, _) {
          // The icon picked in the App Icons view, while it is open
          final icon = ref.watch(appIconsVisibleProvider)
              ? ref.watch(appIconSelectionProvider)
              : null;
          return _buildOutline(icon);
        },
      ),
      RightPanelTab.localize => const LocalizationPanel(),
      RightPanelTab.ai => const AIPanel(),
      RightPanelTab.info => const InfoPanel(),
    };
  }

  /// [tab]'s icon: its SVG tinted to the tab color, or its Material icon.
  Widget _buildTabIcon(RightPanelTab tab) {
    final svgAsset = tab.svgAsset;
    return svgAsset == null ? Icon(tab.icon) : SvgIcon(svgAsset);
  }
}
