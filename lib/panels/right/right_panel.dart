import 'package:fide/providers/ui_state_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

// Screens
import 'outline_panel.dart';
import 'ai_panel.dart';
import 'localization_panel.dart';

// Models
import '../../models/file_system_item.dart';

// New panels
import 'info_panel.dart';

class RightPanel extends StatefulWidget {
  const RightPanel({
    super.key,
    this.selectedFile,
    this.onOutlineUpdate,
    this.onOutlineNodeSelected,
  });

  final Function(int, int)? onOutlineNodeSelected;

  final Function(VoidCallback)? onOutlineUpdate;

  final FileSystemItem? selectedFile;

  @override
  State<RightPanel> createState() => _RightPanelState();
}

class _RightPanelState extends State<RightPanel>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, child) {
        final activeTab = ref.watch(activeRightPanelTabProvider);

        // Update TabController to match the provider
        if (_tabController.index != activeTab) {
          _tabController.animateTo(activeTab);
        }

        return Container(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          child: Column(
            children: [
              // Tab bar
              Container(
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: Theme.of(context).dividerColor,
                      width: 1.0,
                    ),
                  ),
                ),
                child: TabBar(
                  controller: _tabController,
                  onTap: (index) {
                    ref.read(activeRightPanelTabProvider.notifier).state =
                        index;
                  },
                  tabs: [
                    const Tab(
                      key: Key('keyTabOutline'),
                      icon: Icon(Icons.list),
                    ),
                    const Tab(
                      key: Key('keyTabLocalize'),
                      icon: Icon(Icons.translate),
                    ),
                    Tab(
                      key: const Key('keyTabAI'),
                      icon: Builder(
                        builder: (context) {
                          final iconColor = IconTheme.of(context).color!;
                          return SvgPicture.asset(
                            'assets/ollama.svg',
                            width: 24,
                            height: 24,
                            colorFilter: ColorFilter.mode(
                              iconColor,
                              BlendMode.srcIn,
                            ),
                          );
                        },
                      ),
                    ),
                    const Tab(
                      key: Key('keyTabInfo'),
                      icon: Icon(Icons.info_outline),
                    ),
                  ],
                  labelColor: Theme.of(context).colorScheme.primary,
                  unselectedLabelColor: Theme.of(
                    context,
                  ).colorScheme.onSurfaceVariant,
                  indicatorColor: Theme.of(context).colorScheme.primary,
                ),
              ),

              // Tab content
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  physics:
                      const NeverScrollableScrollPhysics(), // Disable swipe gestures
                  children: [
                    // Outline tab
                    widget.selectedFile != null
                        ? OutlinePanel(
                            file: widget.selectedFile!,
                            onOutlineUpdate: widget.onOutlineUpdate,
                            onNodeSelected: widget.onOutlineNodeSelected,
                          )
                        : const Center(
                            child: Text(
                              'Select a file to view outline',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                              ),
                            ),
                          ),

                    // ARB tab
                    LocalizationPanel(selectedFile: widget.selectedFile),

                    // AI tab
                    AIPanel(selectedFile: widget.selectedFile),

                    // Info tab
                    const InfoPanel(),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
