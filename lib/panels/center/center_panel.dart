import 'package:fide/models/document_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Providers
import '../../providers/app_providers.dart';

// Screens
import '../../screens/welcome_screen.dart';
import 'editor_screen.dart';

// Widgets
import 'terminal_panel.dart';
import '../../widgets/resizable_splitter.dart';

// Models
import '../../models/file_system_item.dart';

class CenterPanel extends ConsumerStatefulWidget {
  final FileSystemItem? selectedFile;
  final bool projectLoaded;
  final List<String> mruFolders;
  final bool terminalVisible;
  final VoidCallback? onOpenFolder;
  final Function(String)? onOpenMruProject;
  final Function(String)? onRemoveMruEntry;
  final VoidCallback? onContentChanged;
  final VoidCallback? onClose;

  const CenterPanel({
    super.key,
    this.selectedFile,
    required this.projectLoaded,
    required this.mruFolders,
    required this.terminalVisible,
    this.onOpenFolder,
    this.onOpenMruProject,
    this.onRemoveMruEntry,
    this.onContentChanged,
    this.onClose,
  });

  @override
  ConsumerState<CenterPanel> createState() => _CenterPanelState();
}

class _CenterPanelState extends ConsumerState<CenterPanel> {
  double _terminalHeight = 200.0;
  final double _minTerminalHeight = 100.0;
  final double _maxTerminalHeight = 400.0;

  void _onTerminalResize(double delta) {
    setState(() {
      _terminalHeight = (_terminalHeight - delta).clamp(
        _minTerminalHeight,
        _maxTerminalHeight,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final DocumentState? activeDocument = ref.watch(activeDocumentProvider);

    return Container(
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(color: Theme.of(context).dividerColor, width: 1.0),
        ),
      ),
      child: activeDocument != null
          ? Column(
              children: [
                // Editor takes remaining space
                Expanded(
                  child: EditorScreen(
                    documentState: activeDocument,
                    onContentChanged: widget.onContentChanged,
                    onClose: widget.onClose,
                  ),
                ),
                // Terminal section (only if visible)
                if (widget.terminalVisible) ...[
                  // Resizable splitter
                  ResizableSplitter(
                    onResize: _onTerminalResize,
                    isHorizontal: true,
                  ),

                  // Terminal at bottom
                  SizedBox(
                    height: _terminalHeight,
                    child: ColoredBox(
                      color: Theme.of(context).colorScheme.surfaceContainerLow,
                      child: const TerminalPanel(),
                    ),
                  ),
                ],
              ],
            )
          : !widget.projectLoaded
          ? WelcomeScreen(
              onOpenFolder: widget.onOpenFolder ?? () {},
              onCreateProject: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Create new project feature coming soon!'),
                  ),
                );
              },
              mruFolders: widget.mruFolders,
              onOpenMruProject: widget.onOpenMruProject ?? (String path) {},
              onRemoveMruEntry: widget.onRemoveMruEntry ?? (String path) {},
            )
          : const Center(
              child: Text(
                'Select a file to start editing',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            ),
    );
  }
}
