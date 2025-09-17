import 'package:flutter/material.dart';

// Screens
import '../screens/outline_panel.dart';

// Models
import '../models/file_system_item.dart';

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

class _RightPanelState extends State<RightPanel> {
  @override
  Widget build(BuildContext context) {
    return Container(
      child: widget.selectedFile != null
          ? OutlinePanel(
              file: widget.selectedFile!,
              onOutlineUpdate: widget.onOutlineUpdate,
              onNodeSelected: widget.onOutlineNodeSelected,
            )
          : Container(
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              child: const Center(
                child: Text(
                  'Select a file to view outline',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ),
            ),
    );
  }
}
