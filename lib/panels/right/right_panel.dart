import 'package:flutter/material.dart';

// Screens
import 'outline_panel.dart';
import 'ai_panel.dart';

// Models
import '../../models/file_system_item.dart';

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
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
              tabs: const [
                Tab(icon: Icon(Icons.list)),
                Tab(icon: Icon(Icons.air)),
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
                          style: TextStyle(fontSize: 14, color: Colors.grey),
                        ),
                      ),

                // AI tab
                AIPanel(selectedFile: widget.selectedFile),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
