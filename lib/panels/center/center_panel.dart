import 'package:fide/constants/constants.dart';
import 'package:fide/models/document_state.dart';
import 'package:fide/models/file_system_item.dart';
import 'package:fide/panels/center/editor/editor_screen.dart';
import 'package:fide/panels/center/terminal_panel.dart';
import 'package:fide/providers/app_providers.dart';
import 'package:fide/widgets/panel_island.dart';
import 'package:fide/widgets/resizable_splitter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The center panel host widget that displays the active editor, welcome screen, or create-project flow.
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
  double _terminalHeight = AppSize.terminalDefaultHeight;

  /// Tallest the terminal may be in the last layout, leaving the editor
  /// [AppSize.editorMinHeight].
  double _maxTerminalHeight = AppSize.bottomPanelMaxHeight;

  void _onTerminalResize(double delta) {
    setState(() {
      _terminalHeight = (_terminalHeight - delta).clamp(
        AppSize.terminalMinHeight,
        _maxTerminalHeight,
      );
    });
  }

  /// The terminal's height in a center panel [availableHeight] tall: the
  /// dragged height, shrunk so the editor keeps [AppSize.editorMinHeight].
  double _fitTerminalHeight(double availableHeight) {
    _maxTerminalHeight = (availableHeight - AppSize.editorMinHeight).clamp(
      AppSize.terminalMinHeight,
      AppSize.bottomPanelMaxHeight,
    );
    return _terminalHeight.clamp(AppSize.terminalMinHeight, _maxTerminalHeight);
  }

  @override
  Widget build(BuildContext context) {
    final DocumentState? activeDocument = ref.watch(activeDocumentProvider);

    // Determine the main content to display
    Widget mainContent;
    if (activeDocument != null) {
      mainContent = EditorScreen(
        documentState: activeDocument,
        onContentChanged: widget.onContentChanged,
        onClose: widget.onClose,
      );
    } else {
      mainContent = const Center(
        child: Text(
          'Select a file to start editing',
          style: TextStyle(fontSize: AppFontSize.title, color: Colors.grey),
        ),
      );
    }

    return LayoutBuilder(
      builder: (_ /*context*/, constraints) => Column(
        children: [
          // Main content takes remaining space
          Expanded(child: PanelIsland(child: mainContent)),
          // Terminal section (always shown if visible, independent of editor state)
          if (widget.terminalVisible) ...[
            // Resizable splitter
            ResizableSplitter(onResize: _onTerminalResize, isHorizontal: true),

            // Terminal at bottom
            SizedBox(
              height: _fitTerminalHeight(constraints.maxHeight),
              child: PanelIsland(
                child: ColoredBox(
                  color: Theme.of(context).colorScheme.surfaceContainerLow,
                  child: const TerminalPanel(),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
