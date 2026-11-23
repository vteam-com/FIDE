// ignore_for_file: use_build_context_synchronously

import 'package:fide/constants/constants.dart';
import 'package:fide/models/file_system_item.dart';
import 'package:fide/models/side_panel_widths.dart';
import 'package:fide/panels/center/center_panel.dart';
import 'package:fide/panels/left/left_panel.dart';
import 'package:fide/panels/right/right_panel.dart';
import 'package:fide/providers/app_providers.dart';
import 'package:fide/providers/editor_navigation.dart';
import 'package:fide/providers/side_panel.dart';
import 'package:fide/providers/ui_state_providers.dart';
import 'package:fide/widget_services/panel_island.dart';
import 'package:fide/widgets/resizable_splitter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:material_ui/material_ui.dart';

/// The window's layout once a project is open: the left and right side
/// panels around the center panel, each resizable by its splitter.
class MainLayout extends ConsumerStatefulWidget {
  /// Creates the layout.
  const MainLayout({super.key});

  @override
  ConsumerState<MainLayout> createState() => _MainLayoutState();
}

/// [MainLayout]'s state: the side panels' widths and the file last
/// selected.
class _MainLayoutState extends ConsumerState<MainLayout> {
  double _explorerWidth = AppSize.initialSidePanelWidth;
  double _outlineWidth = AppSize.initialSidePanelWidth;

  /// Widths the side panels had in the last layout, expanded or not.
  double _shownExplorerWidth = AppSize.initialSidePanelWidth;
  double _shownOutlineWidth = AppSize.initialSidePanelWidth;

  String? _lastSelectedFilePath;

  @override
  void initState() {
    super.initState();
    // The layout mounts once a project has loaded; restore its last file now
    // that the selection listener in build is about to be registered
    final projectPath = ref.read(currentProjectPathProvider);
    if (projectPath != null) {
      ref.read(lastOpenedFileProvider.notifier).tryReopen(projectPath);
    }
  }

  /// Resizes the left panel as its splitter moves [delta] right.
  void _onResize(double delta) {
    setState(() {
      _explorerWidth = _dragged(
        _shownExplorerWidth,
        leftPanelExpandedProvider,
        delta,
      );
    });
  }

  /// Resizes the right panel as its splitter moves [delta] right.
  void _onOutlineResize(double delta) {
    setState(() {
      _outlineWidth = _dragged(
        _shownOutlineWidth,
        rightPanelExpandedProvider,
        -delta,
      );
    });
  }

  /// A side panel's width after its splitter moves [delta] wider: it
  /// grows from the [shownWidth] it had in the last layout, and an
  /// [expanded] panel stops being expanded.
  double _dragged(
    double shownWidth,
    StateProvider<bool> expanded,
    double delta,
  ) {
    if (ref.read(expanded)) {
      ref.read(expanded.notifier).state = false;
    }
    return (shownWidth + delta).clamp(
      AppSize.minSidePanelWidth,
      AppSize.maxSidePanelWidth,
    );
  }

  /// Lays out the side panels in [availableWidth] with
  /// [SidePanelWidths.fit], keeping [AppSize.editorMinWidth] for the
  /// editor. A hidden panel is neither shown nor expanded.
  void _fitSidePanels(
    double availableWidth, {
    required bool leftShown,
    required bool rightShown,
    required bool leftExpanded,
    required bool rightExpanded,
  }) {
    final widths = SidePanelWidths.fit(
      availableWidth,
      left: (shown: leftShown, expanded: leftExpanded, width: _explorerWidth),
      right: (shown: rightShown, expanded: rightExpanded, width: _outlineWidth),
    );
    _shownExplorerWidth = widths.left;
    _shownOutlineWidth = widths.right;
  }

  @override
  Widget build(BuildContext context) {
    final projectLoaded = ref.watch(projectLoadedProvider);

    ref.listen<FileSystemItem?>(selectedFileProvider, (_, next) {
      if (next != null && next.path != _lastSelectedFilePath) {
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          await _handleFileSelection(next);
        });
      }
    });

    // Switching editor tabs selects the tab's file, so the tree and the
    // Outline follow it
    ref.listen(activeDocumentProvider.select((doc) => doc?.filePath), (
      _,
      path,
    ) {
      if (path != null && path != ref.read(selectedFileProvider)?.path) {
        openFile(ref, path);
      }
    });

    final leftShown = projectLoaded && ref.watch(leftPanelVisibleProvider);
    final rightShown = ref.watch(rightPanelVisibleProvider);
    final leftExpanded = leftShown && ref.watch(leftPanelExpandedProvider);
    final rightExpanded = rightShown && ref.watch(rightPanelExpandedProvider);

    // Panels float as islands on the window-wide workspace gradient; the
    // splitters between them double as the gaps
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSize.islandGap,
          0,
          AppSize.islandGap,
          AppSize.islandGap,
        ),
        child: LayoutBuilder(
          builder: (_ /*context*/, constraints) {
            _fitSidePanels(
              constraints.maxWidth,
              leftShown: leftShown,
              rightShown: rightShown,
              leftExpanded: leftExpanded,
              rightExpanded: rightExpanded,
            );
            return Row(
              children: [
                if (leftShown) ...[
                  SizedBox(
                    width: _shownExplorerWidth,
                    child: const PanelIsland(
                      panel: SidePanel.left,
                      child: LeftPanel(),
                    ),
                  ),
                  ResizableSplitter(onResize: _onResize),
                ],
                Expanded(
                  child: CenterPanel(
                    terminalVisible: ref.watch(bottomPanelVisibleProvider),
                    onClose: _closeActiveDocument,
                  ),
                ),
                if (rightShown) ...[
                  ResizableSplitter(onResize: _onOutlineResize),
                  SizedBox(
                    width: _shownOutlineWidth,
                    child: const PanelIsland(
                      panel: SidePanel.right,
                      child: RightPanel(),
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  /// Closes the showing document; the next tab's file becomes the
  /// selected one, or none when no tab is left.
  Future<void> _closeActiveDocument() async {
    final documents = ref.read(openDocumentsProvider.notifier);
    await documents.closeActive();
    if (!mounted || ref.read(activeDocumentProvider) != null) return;
    ref.read(selectedFileProvider.notifier).state = null;
    // Selecting the closed file again must reopen it
    _lastSelectedFilePath = null;
  }

  Future<void> _handleFileSelection(FileSystemItem file) async {
    await ref.read(lastOpenedFileProvider.notifier).save(file.path);
    await ref.read(openDocumentsProvider.notifier).open(file.path);

    ref.read(rightPanelVisibleProvider.notifier).state = true;
    _lastSelectedFilePath = file.path;
  }
}
