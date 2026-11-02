// ignore_for_file:  use_build_context_synchronously, avoid_print

import 'package:code_forge/code_forge.dart';
import 'package:fide/constants/constants.dart';
import 'package:fide/models/document_state.dart';
import 'package:fide/models/editor_search.dart';
import 'package:fide/models/text_offsets.dart';
import 'package:fide/panels/center/editor/code_folding.dart';
import 'package:fide/panels/center/editor/editor_screen_header.dart';
import 'package:fide/panels/center/editor/editor_screen_image_view.dart';
import 'package:fide/panels/center/editor/editor_screen_search_bar.dart';
import 'package:fide/panels/center/editor/editor_screen_status_bar.dart';
import 'package:fide/panels/center/editor/editor_screen_unsupported_file_view.dart';
import 'package:fide/panels/center/editor/editor_search_controller.dart';
import 'package:fide/providers/active_editor.dart';
import 'package:fide/providers/app_providers.dart';
import 'package:fide/providers/service_providers.dart';
import 'package:fide/providers/ui_state_providers.dart';
import 'package:fide/services/code_formatter.dart';
import 'package:fide/services/editor_commands.dart';
import 'package:fide/services/file_type_utils.dart';
import 'package:fide/widgets/empty_state.dart';
import 'package:fide/widgets/loading_indicator.dart';
import 'package:fide/widgets/message_box.dart';
import 'package:fide/widgets/side_by_side_diff.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:re_highlight/styles/atom-one-dark.dart';
import 'package:re_highlight/styles/atom-one-light.dart';

/// Full-featured code editor widget with syntax highlighting, search, diff view, and file-save support.
class EditorScreen extends ConsumerStatefulWidget {
  const EditorScreen({
    super.key,
    this.documentState,
    this.onClose,
    this.onSave,
  });

  final DocumentState? documentState;

  final VoidCallback? onClose;

  final VoidCallback? onSave;

  @override
  ConsumerState<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends ConsumerState<EditorScreen>
    implements EditorCommands {
  late final ActiveEditor _activeEditor;

  /// Where edits, saves and formatting are published for the open tabs.
  late final OpenDocumentsNotifier _documents = ref.read(
    openDocumentsProvider.notifier,
  );

  bool _appIsActive = true;

  late CodeForgeController _codeController;

  Map<String, TextStyle>? _codeTheme;

  ThemeData? _codeThemeSource;

  late String _currentFile;

  /// The sides of the diff view: the committed text and the editor's.
  ({String oldText, String newText})? _diff;

  bool _editorHasFocus = false;

  bool _isDirty = false;

  bool _isDisposed = false;

  bool _isLoading = false;

  late final AppLifecycleListener _lifecycleListener;

  final Logger _logger = Logger('EditorScreenState');

  bool _regionsExpanded = true;

  late String _savedText;

  /// Find and replace in the editor's text.
  late final EditorSearchController _search = EditorSearchController(
    _codeController,
    onMatchSelected: _revealSelectionAfterFrame,
  )..addListener(_onSearchChanged);

  /// Receives the find bar's Escape and Enter keys.
  final FocusNode _searchKeysFocusNode = FocusNode();

  bool _showDiffView = false;

  @override
  void initState() {
    super.initState();
    _currentFile = widget.documentState?.filePath ?? '';

    _codeController = CodeForgeController();

    // Initialize from document state (always provided by CenterPanel)
    _codeController.text = widget.documentState!.content;
    _codeController.selection = widget.documentState!.selection;
    _isDirty = widget.documentState!.isDirty;
    _savedText = widget.documentState!.content;

    _codeController.addListener(_onCodeChanged);

    _lifecycleListener = AppLifecycleListener(
      onStateChange: (state) {
        final isActive = state == AppLifecycleState.resumed;
        if (mounted && isActive != _appIsActive) {
          setState(() => _appIsActive = isActive);
        }
      },
    );

    // Receive menu and shortcut commands while mounted
    _activeEditor = ref.read(activeEditorProvider)..attach(this);
  }

  @override
  void dispose() {
    // Mark as disposed to prevent further operations
    _isDisposed = true;

    // Remove listener first to prevent notifications during disposal
    _codeController.removeListener(_onCodeChanged);

    // Auto-save file if there are unsaved changes
    if (_isDirty && _currentFile.isNotEmpty) {
      try {
        _documents.saveOnClose(_currentFile, _codeController.text);
      } catch (e) {
        // Silently handle save errors during dispose
        _logger.warning('Error auto-saving file on close: $e');
      }
    }

    _activeEditor.detach(this);

    _lifecycleListener.dispose();

    // Dispose controller
    _search
      ..removeListener(_onSearchChanged)
      ..dispose();
    _searchKeysFocusNode.dispose();
    _codeController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(EditorScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Each keystroke publishes a new document object, so only a different
    // file means the editor must load new content
    if (widget.documentState?.filePath != oldWidget.documentState?.filePath) {
      if (widget.documentState != null) {
        // Temporarily remove listener to prevent notifications during programmatic update
        _codeController.removeListener(_onCodeChanged);

        // Update to new document state
        _currentFile = widget.documentState!.filePath;

        _codeController.text = widget.documentState!.content;

        // Re-add listener after updates
        _codeController.addListener(_onCodeChanged);

        setState(() {
          _isDirty = widget.documentState!.isDirty;
          _savedText = widget.documentState!.content;
          _isLoading = false;
        });

        // Set selection safely after the build cycle, checking mounted status and not disposed
        if (mounted && !_isDisposed) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && !_isDisposed && widget.documentState != null) {
              // Remove and re-add listener around selection change to prevent notifications
              _codeController.removeListener(_onCodeChanged);
              _codeController.selection = widget.documentState!.selection;
              _codeController.addListener(_onCodeChanged);
            }
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (_, ref, _) {
        final openDocuments = ref.watch(openDocumentsProvider).documents;
        final activeIndex = ref.watch(openDocumentsProvider).activeIndex;

        return Column(
          children: [
            EditorScreenHeader(
              openDocuments: openDocuments,
              activeIndex: activeIndex,
              currentFile: _currentFile,
              isDirty: _isDirty,
              showDiffView: _showDiffView,
              onDocumentSelected: (newIndex) {
                ref.read(openDocumentsProvider.notifier).activate(newIndex);
              },
              onToggleDiffView: () {
                _toggleDiffView();
              },
              onToggleSearch: _search.toggle,
              onSave: () {
                _saveFile();
              },
              onClose: close,
            ),

            Expanded(child: _buildContent()),
          ],
        );
      },
    );
  }

  /// The editor's body: a loading or empty state while there is no
  /// content, else the view [_currentFile]'s kind calls for.
  Widget _buildContent() {
    if (_isLoading) return const LoadingIndicator();
    if (_currentFile.isEmpty) {
      return const EmptyState(message: 'No file selected');
    }
    return switch (FileTypeUtils.viewKindOf(_currentFile)) {
      FileViewKind.unsupported => EditorScreenUnsupportedFileView(
        filePath: _currentFile,
      ),
      FileViewKind.image => EditorScreenImageView(filePath: _currentFile),
      FileViewKind.code => _showDiffView ? _buildDiffView() : _buildCodeView(),
    };
  }

  /// The code editor with its find bar and status bar.
  Widget _buildCodeView() {
    // ignore: deprecated_member_use
    return KeyboardListener(
      focusNode: _searchKeysFocusNode,
      onKeyEvent: _handleKeyEvent,
      child: Column(
        children: [
          // Search bar (only visible when searching)
          if (_search.isOpen)
            EditorScreenSearchBar(
              controller: _search,
              onPreviousMatch: findPrevious,
              onNextMatch: findNext,
              onReplaceAll: _replaceAllMatches,
            ),
          // Editor content
          Expanded(
            child: Focus(
              canRequestFocus: false,
              skipTraversal: true,
              onFocusChange: (hasFocus) {
                setState(() => _editorHasFocus = hasFocus);
              },
              // CodeForge's caret blink never stops and
              // repaints the whole editor every frame; pause
              // its tickers while the caret isn't visible.
              child: TickerMode(
                enabled: _editorHasFocus && _appIsActive,
                child: CodeForge(
                  controller: _codeController,
                  language:
                      widget.documentState?.language ??
                      FileTypeUtils.languageForFile(_currentFile),
                  gutterStyle: GutterStyle(
                    lineNumberStyle: AppTextStyle.lineNumber(context),
                  ),
                  editorTheme: _getCodeTheme(),
                ),
              ),
            ),
          ),
          // Status bar
          EditorScreenStatusBar(
            showDiffView: _showDiffView,
            regionsExpanded: _regionsExpanded,
            currentLineNumber: _getCurrentLineNumber(),
            currentColumnNumber: _getCurrentColumnNumber(),
            currentMatchIndex: _search.currentIndex,
            matchCount: _search.matchCount,
            canFormat: !_showDiffView && CodeFormatter.canFormat(_currentFile),
            fileLanguage: _getFileLanguage(),
            onToggleAllRegions: _toggleAllRegions,
            onFormatFile: () {
              _formatFile();
            },
          ),
        ],
      ),
    );
  }

  @override
  void close() => widget.onClose?.call();

  @override
  void findNext() {
    if (_search.findNext()) _focusEditorAfterFrame();
  }

  @override
  void findPrevious() {
    if (_search.findPrevious()) _focusEditorAfterFrame();
  }

  @override
  void navigateToLine(int lineNumber, {int column = 1}) =>
      _navigateToLine(lineNumber, column: column);

  @override
  void openSearch() => _search.open();

  @override
  Future<void> save() => _saveFile();

  @override
  String get searchSeed => _search.seed;

  /// Builds syntax highlight styles from a full highlight.js theme with the
  /// app's own colors layered on top.
  Map<String, TextStyle> _buildCodeTheme(ThemeData theme) => {
    ...(theme.brightness == Brightness.dark
        ? atomOneDarkTheme
        : atomOneLightTheme),
    ...AppTextStyle.codeTokens(theme),
  };

  Widget _buildDiffView() {
    final diff = _diff;
    if (diff == null) {
      return const EmptyState(message: 'No diff data available');
    }

    return SideBySideDiff(oldText: diff.oldText, newText: diff.newText);
  }

  /// Scrolls the editor so the current text selection is visible.
  void _ensureSelectionVisible() {
    if (!mounted) return;

    try {
      final selectionStart = _codeController.selection.baseOffset;
      if (selectionStart < 0) return;
      _codeController.scrollToLine(
        _codeController.getLineAtOffset(selectionStart),
      );
    } catch (e) {
      _logger.severe('Scrolling error: $e');
    }
  }

  /// Requests keyboard focus for the mounted code editor.
  ///
  /// CodeForge never removes its focus listener on dispose, so each mount
  /// must own its focus node; it is reached through the controller instead.
  void _focusEditor() {
    _codeController.focusNode?.requestFocus();
  }

  /// Formats the editor's text, unsaved edits included, without saving it.
  Future<void> _formatFile() async {
    if (_currentFile.isEmpty) return;

    if (!CodeFormatter.canFormat(_currentFile)) {
      MessageBox.showInfo(
        context,
        'Formatting is currently only supported for ${CodeFormatter.supportedDescription} files',
      );
      return;
    }

    try {
      setState(() => _isLoading = true);

      final formattedContent = await ref
          .read(codeFormatterProvider)
          .format(_currentFile, _codeController.text);

      if (mounted) {
        // Use addPostFrameCallback to ensure we're not in the middle of a build/layout
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            // An edit like any other: the change listener marks the buffer
            // dirty (unless formatting changed nothing) and publishes it
            _codeController.text = formattedContent;
            MessageBox.showSuccess(context, 'File formatted successfully');
          }
        });
      }
    } catch (e) {
      if (mounted) {
        MessageBox.showError(context, 'Error formatting file: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Returns syntax highlight styles for the code editor based on active theme.
  ///
  /// The map is cached per app theme: CodeForge restarts its background
  /// highlighter whenever it receives a new map, so rebuilding it on every
  /// frame would discard highlighting before it ever completes.
  Map<String, TextStyle> _getCodeTheme() {
    final theme = Theme.of(context);
    if (_codeTheme != null && theme == _codeThemeSource) {
      return _codeTheme!;
    }
    _codeThemeSource = theme;
    _codeTheme = _buildCodeTheme(theme);

    return _codeTheme!;
  }

  /// 1-based column of the cursor.
  int _getCurrentColumnNumber() => _cursorPosition.column;

  /// 1-based line of the cursor.
  int _getCurrentLineNumber() => _cursorPosition.line;

  /// Line and column of the cursor in the editor text.
  ({int line, int column}) get _cursorPosition => TextOffsets.positionOf(
    _codeController.text,
    _codeController.selection.base.offset,
  );

  /// Human-readable language label from the current file extension.
  String _getFileLanguage() => FileTypeUtils.languageLabel(_currentFile);

  /// Handles editor keyboard shortcuts while search UI is active.
  void _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      if (_search.isOpen) {
        if (event.logicalKey == LogicalKeyboardKey.escape) {
          _search.close();
        } else if (event.logicalKey == LogicalKeyboardKey.enter) {
          findNext();
        }
      }
    }
  }

  /// Moves the cursor to a specific line and column in the editor.
  void _navigateToLine(int lineNumber, {int column = 1}) {
    // Don't navigate if file is still loading or not loaded
    if (_isLoading ||
        _currentFile.isEmpty ||
        _codeController.text.startsWith('// Loading')) {
      return;
    }

    final offset = TextOffsets.offsetOf(
      _codeController.text,
      lineNumber,
      column: column,
    );
    if (_codeController.text.isEmpty || offset == null) return;

    _codeController.selection = TextSelection.fromPosition(
      TextPosition(offset: offset),
    );

    // Force a rebuild to ensure the selection is visible
    if (mounted) {
      setState(() {});
    }

    // Ensure the editor gets focus
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _ensureSelectionVisible();
      _focusEditor();
    });
  }

  /// Scrolls the selected search match into view once laid out; focus
  /// stays in the find bar.
  void _revealSelectionAfterFrame() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _ensureSelectionVisible();
    });
  }

  /// Focuses the editor after a match is selected from a shortcut or the
  /// find bar's arrows.
  void _focusEditorAfterFrame() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusEditor();
    });
  }

  /// Rebuilds for the find bar's visibility, query and matches.
  void _onSearchChanged() {
    if (mounted && !_isDisposed) setState(() {});
  }

  /// Handles editor content changes and syncs document state.
  void _onCodeChanged() {
    // Check if widget is still mounted and not disposed before calling setState
    if (!mounted || _isDisposed) return;

    final currentText = _codeController.text;

    // Always trigger a rebuild when selection or text changes
    setState(() {
      // Mark as dirty if current text differs from saved text
      _isDirty = currentText != _savedText;
    });

    _documents.update(
      _currentFile,
      content: _codeController.text,
      selection: _codeController.selection,
      isDirty: _isDirty,
    );

    // Notify cursor position changes
    final currentLine = _getCurrentLineNumber();
    ref.read(editorCursorLineProvider.notifier).state = currentLine;
  }

  /// Replaces every search match in one undoable edit and confirms how
  /// many.
  void _replaceAllMatches() {
    final count = _search.replaceAll();
    if (count == 0) return;
    MessageBox.showSuccess(context, EditorSearch.replacedMessage(count));
  }

  /// Persists current editor content to disk and clears dirty state.
  Future<void> _saveFile() async {
    if (_currentFile.isEmpty) return;

    try {
      final text = _codeController.text;
      await _documents.save(_currentFile, text);

      if (mounted) {
        setState(() {
          _savedText = text;
          _isDirty = text != _codeController.text;
        });

        MessageBox.showSuccess(context, 'File saved successfully');
      }
    } catch (e) {
      if (mounted) {
        MessageBox.showError(context, 'Error saving file: $e');
      }
    }
  }

  /// Toggles global folded-region UI state for the editor.
  void _toggleAllRegions() {
    setState(() {
      _regionsExpanded = !_regionsExpanded;
    });

    try {
      _codeController.setAllRegionsExpanded(_regionsExpanded);
    } on StateError catch (e) {
      _logger.warning('Folding unavailable: $e');
    }

    _logger.info(
      'Toggle all regions requested: ${_regionsExpanded ? "expanded" : "collapsed"}',
    );
  }

  /// Toggles side-by-side git diff mode for the current file.
  Future<void> _toggleDiffView() async {
    if (_showDiffView) {
      // Back to editor view
      setState(() {
        _showDiffView = false;
        _diff = null;
      });
      return;
    }

    if (_currentFile.isEmpty) {
      MessageBox.showError(context, 'No file selected');
      return;
    }

    try {
      final diff = await ref
          .read(gitServiceProvider)
          .diffAgainstHead(_currentFile, newText: _codeController.text);
      if (!mounted) return;

      if (diff == null) {
        MessageBox.showError(context, 'Not a Git repository');
        return;
      }
      if (diff.oldText == diff.newText) {
        MessageBox.showInfo(context, 'No changes to show');
        return;
      }

      setState(() {
        _diff = diff;
        _showDiffView = true;
      });
    } catch (e) {
      if (mounted) {
        MessageBox.showError(context, 'Error getting diff: $e');
      }
    }
  }
}
