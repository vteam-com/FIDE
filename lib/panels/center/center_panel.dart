import 'package:fide/constants/constants.dart';
import 'package:fide/models/document_state.dart';
import 'package:fide/panels/center/app_icons_panel.dart';
import 'package:fide/panels/center/architecture/architecture_panel.dart';
import 'package:fide/panels/center/editor/editor_screen.dart';
import 'package:fide/panels/center/project_overview_panel.dart';
import 'package:fide/panels/center/terminal_panel.dart';
import 'package:fide/providers/app_providers.dart';
import 'package:fide/providers/center_view.dart';
import 'package:fide/providers/ui_state_providers.dart';
import 'package:fide/widgets/panel_island.dart';
import 'package:fide/widgets/resizable_splitter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The center panel host widget: a center view (App Icons, Architecture),
/// else the active editor, else the project overview; the terminal below.
class CenterPanel extends ConsumerStatefulWidget {
  /// Whether the terminal shows below the main content.
  final bool terminalVisible;

  /// Closes the active editor tab.
  final VoidCallback? onClose;

  /// Creates the center panel.
  const CenterPanel({super.key, required this.terminalVisible, this.onClose});

  @override
  ConsumerState<CenterPanel> createState() => _CenterPanelState();
}

class _CenterPanelState extends ConsumerState<CenterPanel> {
  double _terminalHeight = AppSize.terminalDefaultHeight;

  /// Tallest the terminal may be in the last layout, leaving the editor
  /// [AppSize.editorMinHeight].
  double _maxTerminalHeight = AppSize.bottomPanelMaxHeight;

  /// Resizes the terminal by its splitter's [delta]; an expanded terminal
  /// stops being expanded and resizes from its expanded height.
  void _onTerminalResize(double delta) {
    final expanded = bottomPanelExpandedProvider;
    if (ref.read(expanded)) {
      ref.read(expanded.notifier).state = false;
      _terminalHeight = _maxTerminalHeight;
    }
    setState(() {
      _terminalHeight = (_terminalHeight - delta).clamp(
        AppSize.terminalMinHeight,
        _maxTerminalHeight,
      );
    });
  }

  /// The terminal's height in a center panel [availableHeight] tall: the
  /// dragged height, or the tallest when [expanded], shrunk so the editor
  /// keeps [AppSize.editorMinHeight].
  double _fitTerminalHeight(double availableHeight, {required bool expanded}) {
    _maxTerminalHeight = (availableHeight - AppSize.editorMinHeight).clamp(
      AppSize.terminalMinHeight,
      AppSize.bottomPanelMaxHeight,
    );
    if (expanded) return _maxTerminalHeight;
    return _terminalHeight.clamp(AppSize.terminalMinHeight, _maxTerminalHeight);
  }

  @override
  Widget build(BuildContext context) {
    final DocumentState? activeDocument = ref.watch(activeDocumentProvider);
    final terminalExpanded = ref.watch(bottomPanelExpandedProvider);
    // Opening or switching files leaves the center view; closing a file
    // opened from it goes back to it
    ref.listen(activeDocumentProvider.select((doc) => doc?.filePath), (
      previous,
      next,
    ) {
      final view = ref.read(centerViewProvider.notifier);
      final opened = ref.read(centerViewOpenedFileProvider.notifier);
      final openedFile = opened.state;
      final returnTo =
          next == null && previous != null && previous == openedFile?.path
          ? openedFile?.view
          : null;
      if (view.state case final showing?) {
        opened.state = next == null ? null : (view: showing, path: next);
      } else if (returnTo != null || next != openedFile?.path) {
        opened.state = null;
      }
      view.state = returnTo;
    });

    // Determine the main content to display
    final Widget mainContent = switch (ref.watch(centerViewProvider)) {
      CenterView.appIcons => const AppIconsPanel(),
      CenterView.architecture => const ArchitecturePanel(),
      null when activeDocument != null => EditorScreen(
        documentState: activeDocument,
        onClose: widget.onClose,
      ),
      null => const ProjectOverviewPanel(),
    };

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
              height: _fitTerminalHeight(
                constraints.maxHeight,
                expanded: terminalExpanded,
              ),
              child: const PanelIsland(child: TerminalPanel()),
            ),
          ],
        ],
      ),
    );
  }
}
