// ignore_for_file:  use_build_context_synchronously, avoid_print

import 'package:code_forge/code_forge.dart';
import 'package:fide/constants/constants.dart';
import 'package:fide/models/document_state.dart';
import 'package:fide/models/editor_search.dart';
import 'package:fide/models/text_offsets.dart';
import 'package:fide/panels/center/editor/editor_screen_header.dart';
import 'package:fide/panels/center/editor/editor_screen_image_view.dart';
import 'package:fide/panels/center/editor/editor_screen_search_bar.dart';
import 'package:fide/panels/center/editor/editor_screen_status_bar.dart';
import 'package:fide/panels/center/editor/editor_screen_unsupported_file_view.dart';
import 'package:fide/panels/center/editor/large_file_message.dart';
import 'package:fide/providers/active_editor.dart';
import 'package:fide/providers/app_providers.dart';
import 'package:fide/providers/code_formatter.dart';
import 'package:fide/providers/editor_commands.dart';
import 'package:fide/providers/file_type_utils.dart';
import 'package:fide/providers/git_service.dart';
import 'package:fide/providers/service_providers.dart';
import 'package:fide/providers/ui_state_providers.dart';
import 'package:fide/widgets/empty_state.dart';
import 'package:fide/widgets/loading_indicator.dart';
import 'package:fide/widgets/message_box.dart';
import 'package:fide/widgets/side_by_side_diff.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:re_highlight/styles/atom-one-dark.dart';
import 'package:re_highlight/styles/atom-one-light.dart';

/// Full-featured code editor widget with syntax highlighting, search, diff view, and file-save support.
class EditorScreen extends ConsumerStatefulWidget {
  const EditorScreen({
    super.key,
    this.documentState,
    this.onContentChanged,
    this.onClose,
    this.onSave,
  });

  final DocumentState? documentState;

  final VoidCallback? onClose;

  final VoidCallback? onContentChanged;

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

  final Map<String, GitDiffStats?> _allGitDiffStats = {};

  bool _appIsActive = true;

  late CodeForgeController _codeController;

  Map<String, TextStyle>? _codeTheme;

  ThemeData? _codeThemeSource;

  late String _currentFile;

  String? _diffNewText;

  String? _diffOldText;

  bool _editorHasFocus = false;

  double _fileSizeMB = 0.0;

  bool _isDirty = false;

  bool _isDisposed = false;

  bool _isLargeFile = false;

  bool _isLoading = false;

  late final AppLifecycleListener _lifecycleListener;

  final Logger _logger = Logger('EditorScreenState');

  bool _regionsExpanded = true;

  late String _savedText;

  final TextEditingController _searchController = TextEditingController();

  late FocusNode _searchFocusNode;

  /// Find-in-file query, options and matches.
  final EditorSearch _search = EditorSearch();

  bool _showDiffView = false;

  bool _showSearch = false;

  @override
  void initState() {
    super.initState();
    _currentFile = widget.documentState?.filePath ?? '';

    _codeController = CodeForgeController();
    _searchFocusNode = FocusNode();

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

    // Load git diff stats for the file
    _loadGitDiffStatsForFile(_currentFile);

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
    _codeController.dispose();
    _searchFocusNode.dispose();
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
          _isLargeFile = false; // Reset large file flag for new file
          _fileSizeMB = 0.0;
        });

        // Load git diff stats for the new file
        _loadGitDiffStatsForFile(_currentFile);

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
    // Check if file is too large to load
    if (_isLargeFile) {
      return LargeFileMessage(
        fileName: p.basename(_currentFile),
        fileSizeMB: _fileSizeMB,
      );
    }

    return Consumer(
      builder: (context, ref, _) {
        final openDocuments = ref.watch(openDocumentsProvider).documents;
        final activeIndex = ref.watch(openDocumentsProvider).activeIndex;

        // Load git stats for all documents if not already loaded
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _loadGitDiffStatsForAllDocuments(openDocuments);
        });

        return Column(
          children: [
            EditorScreenHeader(
              openDocuments: openDocuments,
              activeIndex: activeIndex,
              currentFile: _currentFile,
              allGitDiffStats: _allGitDiffStats,
              isDirty: _isDirty,
              showDiffView: _showDiffView,
              onDocumentSelected: (newIndex) {
                ref.read(openDocumentsProvider.notifier).activate(newIndex);
              },
              onToggleDiffView: () {
                _toggleDiffView();
              },
              onToggleSearch: _toggleSearch,
              onSave: () {
                _saveFile();
              },
              onClose: close,
            ),

            Expanded(
              child: _isLoading
                  ? const LoadingIndicator()
                  : _currentFile.isEmpty
                  ? const EmptyState(message: 'No file selected')
                  : !FileTypeUtils.isFileSupportedInEditor(_currentFile)
                  ? EditorScreenUnsupportedFileView(filePath: _currentFile)
                  : _isImageFile(_currentFile)
                  ? EditorScreenImageView(
                      filePath: _currentFile,
                      documentContentLength:
                          widget.documentState!.content.length,
                    )
                  : _showDiffView
                  ? _buildDiffView()
                  // ignore: deprecated_member_use
                  : KeyboardListener(
                      focusNode: FocusNode(),
                      onKeyEvent: _handleKeyEvent,
                      child: Column(
                        children: [
                          // Search bar (only visible when searching)
                          if (_showSearch)
                            EditorScreenSearchBar(
                              searchController: _searchController,
                              searchFocusNode: _searchFocusNode,
                              caseSensitive: _search.caseSensitive,
                              wholeWord: _search.wholeWord,
                              currentMatchIndex: _search.currentIndex,
                              matchCount: _search.matches.length,
                              onSearchChanged: _performSearch,
                              onClose: _closeSearch,
                              onPreviousMatch: _previousMatch,
                              onNextMatch: _nextMatch,
                              onCaseSensitiveChanged: (value) {
                                _search.caseSensitive = value;
                                _performSearch(_search.query);
                              },
                              onWholeWordChanged: (value) {
                                _search.wholeWord = value;
                                _performSearch(_search.query);
                              },
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
                                      FileTypeUtils.languageForFile(
                                        _currentFile,
                                      ),
                                  gutterStyle: GutterStyle(
                                    lineNumberStyle: AppTextStyle.lineNumber(
                                      context,
                                    ),
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
                            matchCount: _search.matches.length,
                            canFormat:
                                !_showDiffView &&
                                CodeFormatter.canFormat(_currentFile),
                            fileLanguage: _getFileLanguage(),
                            onToggleAllRegions: _toggleAllRegions,
                            onFormatFile: () {
                              _formatFile();
                            },
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }

  @override
  void close() => widget.onClose?.call();

  @override
  void findNext() => _nextMatch();

  @override
  void findPrevious() => _previousMatch();

  @override
  void navigateToLine(int lineNumber, {int column = 1}) =>
      _navigateToLine(lineNumber, column: column);

  @override
  void openSearch() => _openSearch();

  @override
  void save() => _saveFile();

  @override
  String get searchSeed {
    final selection = _codeController.selection;
    if (!selection.isValid) return '';
    return EditorSearch.seedFrom(selection.textInside(_codeController.text));
  }

  /// Builds syntax highlight styles from a full highlight.js theme with the
  /// app's own colors layered on top.
  Map<String, TextStyle> _buildCodeTheme(ThemeData theme) => {
    ...(theme.brightness == Brightness.dark
        ? atomOneDarkTheme
        : atomOneLightTheme),
    ...AppTextStyle.codeTokens(theme),
  };

  Widget _buildDiffView() {
    if (_diffOldText == null || _diffNewText == null) {
      return const EmptyState(message: 'No diff data available');
    }

    return SideBySideDiff(oldText: _diffOldText!, newText: _diffNewText!);
  }

  /// Closes the search UI and resets all in-memory search state.
  void _closeSearch() {
    if (!mounted) return;
    setState(() {
      _showSearch = false;
      _searchController.clear();
      _search.clear();
    });
    _searchFocusNode.unfocus();
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

  /// Folds every outermost foldable region, leaving nested regions inside.
  ///
  /// Replaces `CodeForgeController.foldAll`, which crashes in code_forge
  /// 11.4.0 on a null check whenever a scanned line has no fold range.
  void _foldTopLevelRegions() {
    final lineCount = _codeController.lineCount;
    var line = 0;
    while (line < lineCount) {
      final existing = _codeController.foldings[line];
      if (existing == null || !existing.isFolded) {
        _codeController.toggleFold(line);
      }
      final fold = _codeController.foldings[line];
      line = fold != null && fold.isFolded ? fold.endIndex + 1 : line + 1;
    }
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
      if (_showSearch) {
        if (event.logicalKey == LogicalKeyboardKey.escape) {
          _closeSearch();
        } else if (event.logicalKey == LogicalKeyboardKey.enter) {
          _nextMatch();
        }
      }
    }
  }

  bool _isImageFile(String filePath) {
    return FileTypeUtils.isImageFile(filePath);
  }

  /// Loads git diff counters for open documents not yet cached.
  ///
  /// Called after every build, so it must not trigger a rebuild when there is
  /// nothing new to load; otherwise it loops, spawning git processes forever.
  Future<void> _loadGitDiffStatsForAllDocuments(
    List<DocumentState> documents,
  ) async {
    final futures = <Future>[];
    for (final doc in documents) {
      if (!_allGitDiffStats.containsKey(doc.filePath)) {
        // Reserve the slot so overlapping frames don't start duplicate loads.
        _allGitDiffStats[doc.filePath] = null;
        futures.add(_loadGitDiffStatsForFile(doc.filePath));
      }
    }
    if (futures.isEmpty) {
      return;
    }
    await Future.wait(futures);
    if (mounted) {
      setState(() {});
    }
  }

  /// Loads git diff counters for a single file and caches the result.
  Future<void> _loadGitDiffStatsForFile(String filePath) async {
    if (filePath.isEmpty) {
      _allGitDiffStats[filePath] = null;
      return;
    }

    try {
      final gitService = ref.read(gitServiceProvider);
      final isGitRepo = await gitService.isGitRepository(p.dirname(filePath));
      if (!isGitRepo) {
        _allGitDiffStats[filePath] = null;
        return;
      }

      final stats = await gitService.getFileDiffStats(
        p.dirname(filePath),
        filePath,
      );
      _allGitDiffStats[filePath] = stats;
    } catch (e) {
      _logger.warning('Error loading git diff stats for $filePath: $e');
      _allGitDiffStats[filePath] = null;
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

  /// Selects and reveals the search match at the given match index.
  void _navigateToMatch(int index) {
    if (index < 0 || index >= _search.matches.length) return;

    final offset = _search.matches[index];

    // Set selection to highlight the found text
    _codeController.selection = TextSelection(
      baseOffset: offset,
      extentOffset: offset + _search.query.length,
    );

    setState(() {
      _search.currentIndex = index;
    });

    // Ensure the selection is visible and properly displayed
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      // Force a rebuild to ensure selection is displayed
      setState(() {});

      // Find the scrollable widget and ensure the selection is visible
      _ensureSelectionVisible();

      // Don't request focus on editor during search - keep focus on search field
      // Focus will only be requested when explicitly navigating with keyboard shortcuts
    });
  }

  /// Navigates to the next search match, wrapping at the end.
  void _nextMatch() {
    if (!_search.hasMatches) return;
    _navigateToMatch(_search.nextIndex);

    // Request focus on editor when navigating with keyboard shortcuts
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusEditor();
      }
    });
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

    // Notify outline panel to refresh when content changes
    widget.onContentChanged?.call();

    // Notify cursor position changes
    final currentLine = _getCurrentLineNumber();
    ref.read(editorCursorLineProvider.notifier).state = currentLine;
  }

  /// Recomputes search matches for [query] and selects the first one.
  void _performSearch(String query) {
    setState(
      () => _search.run(
        _codeController.text,
        query,
        fromOffset: _codeController.selection.start,
      ),
    );
    if (_search.hasMatches) _navigateToMatch(_search.currentIndex);
  }

  /// Navigates to the previous search match, wrapping at the start.
  void _previousMatch() {
    if (!_search.hasMatches) return;
    _navigateToMatch(_search.previousIndex);

    // Request focus on editor when navigating with keyboard shortcuts
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusEditor();
      }
    });
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
      if (_regionsExpanded) {
        _codeController.unfoldAll();
      } else {
        _foldTopLevelRegions();
      }
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
        _diffOldText = null;
        _diffNewText = null;
      });
      return;
    }

    if (_currentFile.isEmpty) {
      MessageBox.showError(context, 'No file selected');
      return;
    }

    try {
      final gitService = ref.read(gitServiceProvider);
      final isGitRepo = await gitService.isGitRepository(
        p.dirname(_currentFile),
      );
      if (!mounted) return;

      if (!isGitRepo) {
        MessageBox.showError(context, 'Not a Git repository');
        return;
      }

      final diff = await gitService.getFileDiff(
        p.dirname(_currentFile),
        _currentFile,
      );

      if (!mounted) return;

      if (diff.isEmpty) {
        MessageBox.showInfo(context, 'No changes to show');
        return;
      }

      // Committed content; empty for files not yet in HEAD
      final oldText = await gitService.getHeadContent(_currentFile);

      // Current file content for newText
      final newText = _codeController.text;

      // Switch to diff view
      setState(() {
        _diffOldText = oldText;
        _diffNewText = newText;
        _showDiffView = true;
      });
    } catch (e) {
      if (mounted) {
        MessageBox.showError(context, 'Error getting diff: $e');
      }
    }
  }

  /// Shows the search UI focused with its query selected, starting from the
  /// selected text when there is a [searchSeed].
  void _openSearch() {
    if (!mounted) return;
    final seed = searchSeed;
    setState(() => _showSearch = true);
    if (seed.isNotEmpty) {
      _searchController.text = seed;
      _performSearch(seed);
    } else if (_searchController.text.isEmpty) {
      _searchController.text = _search.query;
    }
    _searchController.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _searchController.text.length,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _searchFocusNode.requestFocus();
      }
    });
  }

  /// Toggles the search UI.
  void _toggleSearch() => _showSearch ? _closeSearch() : _openSearch();
}
