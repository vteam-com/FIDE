// ignore_for_file:  use_build_context_synchronously, avoid_print

import 'dart:convert';
import 'dart:io';

import 'package:fide/constants/constants.dart';
import 'package:fide/models/document_state.dart';
import 'package:fide/panels/center/editor/editor_screen_header.dart';
import 'package:fide/panels/center/editor/editor_screen_image_view.dart';
import 'package:fide/panels/center/editor/editor_screen_search_bar.dart';
import 'package:fide/panels/center/editor/editor_screen_status_bar.dart';
import 'package:fide/panels/center/editor/editor_screen_unsupported_file_view.dart';
import 'package:fide/panels/center/editor/large_file_message.dart';
import 'package:fide/providers/app_providers.dart';
import 'package:fide/providers/file_type_utils.dart';
import 'package:fide/providers/git_service.dart';
import 'package:fide/widgets/message_box.dart';
import 'package:fide/widgets/side_by_side_diff.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_code_crafter/code_crafter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as path;

/// Full-featured code editor widget with syntax highlighting, search, diff view, and file-save support.
class EditorScreen extends StatefulWidget {
  const EditorScreen({
    super.key,
    this.documentState,
    this.onContentChanged,
    this.onClose,
    this.onSave,
  });

  static _EditorScreenState? _currentEditor;

  final DocumentState? documentState;

  final VoidCallback? onClose;

  final VoidCallback? onContentChanged;

  static void Function(int)? onCursorPositionChanged;

  final VoidCallback? onSave;

  /// Handles `EditorScreen.closeCurrentEditor`.
  static void closeCurrentEditor() {
    _currentEditor?.widget.onClose?.call();
  }

  @override
  State<EditorScreen> createState() => _EditorScreenState();

  /// Handles `EditorScreen.findNext`.
  static void findNext() {
    _currentEditor?._nextMatch();
  }

  /// Handles `EditorScreen.findPrevious`.
  static void findPrevious() {
    _currentEditor?._previousMatch();
  }

  /// Handles `EditorScreen.navigateToLine`.
  static void navigateToLine(int lineNumber, {int column = 1}) {
    _currentEditor?._navigateToLine(lineNumber, column: column);
  }

  /// Handles `EditorScreen.saveCurrentEditor`.
  static void saveCurrentEditor() {
    _currentEditor?._saveFile();
  }

  /// Handles `EditorScreen.toggleSearch`.
  static void toggleSearch() {
    _currentEditor?._toggleSearch();
  }
}

class _EditorScreenState extends State<EditorScreen> {
  final Map<String, GitDiffStats?> _allGitDiffStats = {};

  bool _caseSensitive = false;

  late CodeCrafterController _codeController;

  late GlobalKey _codeCrafterKey;

  late String _currentFile;

  int _currentMatchIndex = -1;

  String? _diffNewText;

  String? _diffOldText;

  double _fileSizeMB = 0.0;

  bool _isDirty = false;

  bool _isDisposed = false;

  bool _isLargeFile = false;

  bool _isLoading = false;

  final Logger _logger = Logger('EditorScreenState');

  bool _regionsExpanded = true;

  late String _savedText;

  final TextEditingController _searchController = TextEditingController();

  late FocusNode _searchFocusNode;

  List<int> _searchMatches = [];

  String _searchQuery = '';

  bool _showDiffView = false;

  bool _showSearch = false;

  bool _wholeWord = false;

  @override
  void initState() {
    super.initState();
    _currentFile = widget.documentState?.filePath ?? '';

    // Create unique key for this editor instance
    _codeCrafterKey = GlobalKey(
      debugLabel: 'CodeCrafter-${_currentFile.hashCode}',
    );

    _codeController = CodeCrafterController();
    _searchFocusNode = FocusNode();

    // Initialize from document state (always provided by CenterPanel)
    _codeController.text = widget.documentState!.content;
    _codeController.selection = widget.documentState!.selection;
    if (widget.documentState!.language != null) {
      _codeController.language = widget.documentState!.language;
    }
    _isDirty = widget.documentState!.isDirty;
    _savedText = widget.documentState!.content;

    _codeController.addListener(_onCodeChanged);

    // Load git diff stats for the file
    _loadGitDiffStatsForFile(_currentFile);

    // Register this editor as the current editor for global save access
    EditorScreen._currentEditor = this;
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
        final file = File(_currentFile);
        file.writeAsStringSync(_codeController.text);
        // Note: We don't show a snackbar here since the widget is being disposed
      } catch (e) {
        // Silently handle save errors during dispose
        _logger.warning('Error auto-saving file on close: $e');
      }
    }

    // Unregister this editor if it's the current one
    if (EditorScreen._currentEditor == this) {
      EditorScreen._currentEditor = null;
    }

    // Dispose controller
    _codeController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(EditorScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Check if document state changed
    if (widget.documentState != oldWidget.documentState) {
      if (widget.documentState != null) {
        // Temporarily remove listener to prevent notifications during programmatic update
        _codeController.removeListener(_onCodeChanged);

        // Update to new document state
        _currentFile = widget.documentState!.filePath;

        _codeController.text = widget.documentState!.content;
        if (widget.documentState!.language != null) {
          _codeController.language = widget.documentState!.language;
        }

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
        fileName: path.basename(_currentFile),
        fileSizeMB: _fileSizeMB,
      );
    }

    return Consumer(
      builder: (context, ref, _) {
        final openDocuments = ref.watch(openDocumentsProvider);
        final activeIndex = ref.watch(activeDocumentIndexProvider);

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
                ref.read(activeDocumentIndexProvider.notifier).state = newIndex;
              },
              onToggleDiffView: () {
                _toggleDiffView();
              },
              onToggleSearch: _toggleSearch,
              onSave: () {
                _saveFile();
              },
              onClose: EditorScreen.closeCurrentEditor,
            ),

            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _currentFile.isEmpty
                  ? const Center(child: Text('No file selected'))
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
                              caseSensitive: _caseSensitive,
                              wholeWord: _wholeWord,
                              currentMatchIndex: _currentMatchIndex,
                              matchCount: _searchMatches.length,
                              onSearchChanged: _performSearch,
                              onClose: _closeSearch,
                              onPreviousMatch: _previousMatch,
                              onNextMatch: _nextMatch,
                              onCaseSensitiveChanged: (value) {
                                setState(() {
                                  _caseSensitive = value;
                                  if (_searchQuery.isNotEmpty) {
                                    _performSearch(_searchQuery);
                                  }
                                });
                              },
                              onWholeWordChanged: (value) {
                                setState(() {
                                  _wholeWord = value;
                                  if (_searchQuery.isNotEmpty) {
                                    _performSearch(_searchQuery);
                                  }
                                });
                              },
                            ),
                          // Editor content
                          Expanded(
                            child: CodeCrafter(
                              key: _codeCrafterKey,
                              controller: _codeController,
                              enableGutterDivider: false, // they have a bug
                              gutterStyle: GutterStyle(
                                dividerColor: Colors.grey.withAlpha(
                                  AppSize.gutterDividerAlpha.toInt(),
                                ),
                                dividerThickness: AppSize.borderThin,
                                lineNumberStyle: TextStyle(
                                  // fontFamily: 'monospace',
                                  letterSpacing: -1,

                                  color: Theme.of(context).colorScheme.onSurface
                                      .withValues(alpha: AppOpacity.disabled),
                                ),
                              ),

                              // textStyle: const TextStyle(fontFamily: 'monospace'),
                              editorTheme: _getCodeTheme(),
                            ),
                          ),
                          // Status bar
                          EditorScreenStatusBar(
                            showDiffView: _showDiffView,
                            regionsExpanded: _regionsExpanded,
                            currentLineNumber: _getCurrentLineNumber(),
                            currentColumnNumber: _getCurrentColumnNumber(),
                            currentMatchIndex: _currentMatchIndex,
                            matchCount: _searchMatches.length,
                            canFormat:
                                !_showDiffView &&
                                (_currentFile.endsWith('.dart') ||
                                    _currentFile.endsWith('.json') ||
                                    _currentFile.endsWith('.arb')),
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

  /// Handles `_EditorScreenState.findEditableText`.
  EditableText? findEditableText(BuildContext context) {
    EditableText? result;
    context.visitChildElements((element) {
      if (element.widget is EditableText) {
        result = element.widget as EditableText;
      } else {
        result = findEditableText(element);
      }
      if (result != null) return;
    });
    return result;
  }

  /// Handles `_EditorScreenState.findFocusableElement`.
  FocusNode? findFocusableElement(BuildContext context) {
    FocusNode? result;
    void search(Element element) {
      final widget = element.widget;
      if (widget is EditableText) {
        result = widget.focusNode;
        return;
      }
      element.visitChildren(search);
    }

    context.visitChildElements(search);
    return result;
  }

  Widget _buildDiffView() {
    if (_diffOldText == null || _diffNewText == null) {
      return const Center(child: Text('No diff data available'));
    }

    return SideBySideDiff(oldText: _diffOldText!, newText: _diffNewText!);
  }

  /// Closes the search UI and resets all in-memory search state.
  void _closeSearch() {
    if (!mounted) return;
    setState(() {
      _showSearch = false;
      _searchController.clear();
      _searchQuery = '';
      _searchMatches.clear();
      _currentMatchIndex = -1;
    });
    _searchFocusNode.unfocus();
  }

  /// Scrolls the editor so the current text selection is visible.
  void _ensureSelectionVisible() {
    if (!mounted || _codeController.selection.isCollapsed) return;

    try {
      // Find the CodeCrafter widget in the tree
      final codeCrafterElement = _codeCrafterKey.currentContext;
      if (codeCrafterElement == null) return;

      // Calculate line number
      final text = _codeController.text;
      final selectionStart = _codeController.selection.baseOffset;
      final textBeforeSelection = text.substring(0, selectionStart);
      final lineNumber = textBeforeSelection.split('\n').length;

      // Find all scrollables and choose the best one
      final List<ScrollableState> allScrollables = [];

      void findAllScrollables(Element element) {
        if (element.widget is Scrollable) {
          final scrollableState = element
              .findAncestorStateOfType<ScrollableState>();
          if (scrollableState != null) {
            allScrollables.add(scrollableState);
          }
        }
        element.visitChildElements(findAllScrollables);
      }

      codeCrafterElement.visitChildElements(findAllScrollables);

      // Choose the best scrollable (one with reasonable max extent, not infinite)
      ScrollableState? mainEditorScrollable;
      for (final scrollable in allScrollables) {
        final maxExtent = scrollable.position.maxScrollExtent;
        if (maxExtent < EditorConfig.scrollableExtentMax &&
            maxExtent > EditorConfig.scrollableExtentMin) {
          // Reasonable bounds
          mainEditorScrollable = scrollable;
          break;
        }
      }

      // If no scrollable with reasonable bounds found, use the first one
      if (mainEditorScrollable == null && allScrollables.isNotEmpty) {
        mainEditorScrollable = allScrollables.first;
      }

      // Scroll the main editor scrollable
      if (mainEditorScrollable != null) {
        final double targetScrollOffset =
            (lineNumber - EditorConfig.contextLinesAboveTarget) *
            EditorConfig.lineHeight; // Start lines above target
        final double clampedOffset = targetScrollOffset.clamp(
          0.0,
          mainEditorScrollable.position.maxScrollExtent,
        );

        // Only scroll vertically, don't affect horizontal position
        if (mainEditorScrollable.position.pixels != clampedOffset) {
          mainEditorScrollable.position.jumpTo(clampedOffset);
        }
      } else {
        _logger.warning('Main editor scrollable not found, using fallback');
        // Fallback: Try Scrollable.ensureVisible
        Scrollable.ensureVisible(
          codeCrafterElement,
          duration: AppDuration.editorScroll,
          curve: Curves.easeOut,
          alignment: AppOpacity.divider, // Center the selection in the viewport
        );
      }
    } catch (e) {
      _logger.severe('Scrolling error: $e');
    }
  }

  /// Formats the current file using Dart formatter or JSON pretty-printing.
  Future<void> _formatFile() async {
    if (_currentFile.isEmpty) return;

    final extension = _currentFile.split('.').last.toLowerCase();
    final isDartFile = extension == 'dart';
    final isJsonFile = extension == 'json' || extension == 'arb';

    // Check if file type is supported for formatting
    if (!isDartFile && !isJsonFile) {
      MessageBox.showInfo(
        context,
        'Formatting is currently only supported for Dart, JSON, and ARB files',
      );
      return;
    }

    try {
      setState(() => _isLoading = true);

      ProcessResult result;

      if (isDartFile) {
        // Run dart format on Dart files
        result = await Process.run('dart', ['format', _currentFile]);
      } else {
        // For JSON/ARB files, use manual JSON formatting
        result = await _formatJsonManually(_currentFile);
      }

      if (result.exitCode == 0) {
        // Format successful, reload the file content
        final file = File(_currentFile);
        final formattedContent = await file.readAsString();

        if (mounted) {
          // Use addPostFrameCallback to ensure we're not in the middle of a build/layout
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              // Update the controller with formatted content
              _codeController.text = formattedContent;
              _savedText = formattedContent;

              setState(() {
                _isDirty = false;
              });

              // Update document state
              if (widget.documentState != null) {
                widget.documentState!.content = formattedContent;
                widget.documentState!.isDirty = false;
              }

              MessageBox.showSuccess(context, 'File formatted successfully');
            }
          });
        }
      } else {
        if (mounted) {
          MessageBox.showError(
            context,
            'Error formatting file: ${result.stderr.toString().trim()}',
          );
        }
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

  /// Formats JSON or ARB content by decoding and re-encoding with indentation.
  Future<ProcessResult> _formatJsonManually(String filePath) async {
    try {
      final file = File(filePath);
      final content = await file.readAsString();

      // Simple JSON validation and formatting
      // This is a basic implementation - for production, consider using a proper JSON formatter
      final dynamic jsonData = jsonDecode(content);
      final formattedJson = JsonEncoder.withIndent('  ').convert(jsonData);

      await file.writeAsString(formattedJson);
      return ProcessResult(0, 0, '', ''); // Mock successful result
    } catch (e) {
      return ProcessResult(
        1,
        1,
        '',
        'Manual JSON formatting failed: $e',
      ); // Mock error result
    }
  }

  /// Returns syntax highlight styles for the code editor based on active theme.
  Map<String, TextStyle> _getCodeTheme() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseTextColor = Theme.of(context).colorScheme.onPrimary;

    return {
      'root': TextStyle(
        backgroundColor: Theme.of(context).colorScheme.surface,
        color: Theme.of(context).colorScheme.onSurface,
      ),
      'comment': TextStyle(
        color: isDark
            ? Colors.green[AppShade.soft]
            : Colors.green[AppShade.deep],
      ),
      'keyword': TextStyle(
        color: isDark
            ? Colors.purple[AppShade.soft]
            : Colors.purple[AppShade.strong],
        fontWeight: FontWeight.bold,
      ),
      'string': TextStyle(
        color: isDark ? Colors.red[AppShade.soft] : Colors.red[AppShade.strong],
      ),
      'number': TextStyle(
        color: isDark
            ? Colors.blue[AppShade.soft]
            : Colors.blue[AppShade.strong],
      ),
      'variable': TextStyle(color: isDark ? Colors.white70 : Colors.black87),
      'class': TextStyle(
        color: isDark
            ? Colors.blue[AppShade.soft]
            : Colors.blue[AppShade.strong],
        fontWeight: FontWeight.bold,
      ),
      'function': TextStyle(
        color: isDark
            ? Colors.blue[AppShade.muted]
            : Colors.blue[AppShade.strong],
      ),
      'operator': TextStyle(color: baseTextColor, fontWeight: FontWeight.bold),
    };
  }

  /// Computes the 1-based column number for the current cursor position.
  int _getCurrentColumnNumber() {
    if (_codeController.text.isEmpty) {
      return 1;
    }

    final offset = _codeController.selection.base.offset;
    if (offset <= 0) {
      return 1;
    }

    final textBeforeCursor = _codeController.text.substring(0, offset);
    final lastNewlineIndex = textBeforeCursor.lastIndexOf('\n');

    // If no newline found, cursor is on first line
    if (lastNewlineIndex == -1) {
      return offset + 1; // +1 because columns are 1-indexed
    }

    // Return characters from the last newline to cursor position
    return offset - lastNewlineIndex; // This gives 1-indexed column
  }

  int _getCurrentLineNumber() {
    if (_codeController.text.isEmpty) return 1;

    final offset = _codeController.selection.base.offset;
    if (offset <= 0) return 1;

    final textBeforeCursor = _codeController.text.substring(0, offset);
    final lines = textBeforeCursor.split('\n');
    return lines.length;
  }

  /// Returns a human-readable language label from the current file extension.
  String _getFileLanguage() {
    final ext = _currentFile.split('.').last.toLowerCase();
    switch (ext) {
      case 'dart':
        return 'Dart';
      case 'yaml':
      case 'yml':
        return 'YAML';
      case 'json':
        return 'JSON';
      case 'js':
        return 'js';
      case 'xml':
      case 'html':
        return ext.toUpperCase();
      default:
        return 'Text';
    }
  }

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

  /// Loads git diff counters for every open document.
  Future<void> _loadGitDiffStatsForAllDocuments(
    List<DocumentState> documents,
  ) async {
    final futures = <Future>[];
    for (final doc in documents) {
      futures.add(_loadGitDiffStatsForFile(doc.filePath));
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
      final gitService = GitService();
      final isGitRepo = await gitService.isGitRepository(
        path.dirname(filePath),
      );
      if (!isGitRepo) {
        _allGitDiffStats[filePath] = null;
        return;
      }

      final stats = await gitService.getFileDiffStats(
        path.dirname(filePath),
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

    // Basic validation
    if (_codeController.text.isEmpty || lineNumber < 1) {
      return;
    }

    final lines = _codeController.text.split('\n');
    if (lineNumber > lines.length) {
      return;
    }

    // Calculate the character offset for the target line
    int offset = 0;
    for (int i = 0; i < lineNumber - 1 && i < lines.length; i++) {
      offset += lines[i].length + 1; // +1 for the newline character
    }

    // Add column offset within the line (column is 1-indexed, so subtract 1)
    final targetLine = lines[lineNumber - 1];
    final columnOffset = (column - 1).clamp(0, targetLine.length);
    offset += columnOffset;

    // Clamp offset
    if (offset < 0) offset = 0;
    if (offset > _codeController.text.length) {
      offset = _codeController.text.length;
    }

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
      final focusNode = findFocusableElement(context);
      if (focusNode != null) {
        focusNode.requestFocus();
      } else {
        // Fallback: try to request focus on the current focus scope
        FocusScope.of(context).requestFocus();
      }
    });
  }

  /// Selects and reveals the search match at the given match index.
  void _navigateToMatch(int index) {
    if (index < 0 || index >= _searchMatches.length) return;

    final offset = _searchMatches[index];

    // Set selection to highlight the found text
    _codeController.selection = TextSelection(
      baseOffset: offset,
      extentOffset: offset + _searchQuery.length,
    );

    setState(() {
      _currentMatchIndex = index;
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
    if (_searchMatches.isEmpty) return;
    final nextIndex = (_currentMatchIndex + 1) % _searchMatches.length;
    _navigateToMatch(nextIndex);

    // Request focus on editor when navigating with keyboard shortcuts
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final focusNode = findFocusableElement(context);
        if (focusNode != null) {
          focusNode.requestFocus();
        }
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

    // Update document state if we have document state
    if (widget.documentState != null) {
      widget.documentState!.content = _codeController.text;
      widget.documentState!.selection = _codeController.selection;
      widget.documentState!.isDirty = _isDirty;
    }

    // Notify outline panel to refresh when content changes
    widget.onContentChanged?.call();

    // Notify cursor position changes
    final currentLine = _getCurrentLineNumber();
    EditorScreen.onCursorPositionChanged?.call(currentLine);
  }

  /// Recomputes search matches for the current query and options.
  void _performSearch(String query) {
    if (query.isEmpty) {
      setState(() {
        _searchMatches.clear();
        _currentMatchIndex = -1;
      });
      return;
    }

    final text = _codeController.text;
    final matches = <int>[];
    final searchText = _caseSensitive ? query : query.toLowerCase();
    final content = _caseSensitive ? text : text.toLowerCase();

    int start = 0;
    while (true) {
      final index = content.indexOf(searchText, start);
      if (index == -1) break;

      if (_wholeWord) {
        // Check if it's a whole word
        final before =
            index == 0 || !RegExp(r'\w').hasMatch(content[index - 1]);
        final after =
            index + searchText.length == content.length ||
            !RegExp(r'\w').hasMatch(content[index + searchText.length]);
        if (before && after) {
          matches.add(index);
        }
      } else {
        matches.add(index);
      }

      start = index + 1;
    }

    setState(() {
      _searchMatches = matches;
      _currentMatchIndex = matches.isNotEmpty ? 0 : -1;
      _searchQuery = query;
    });

    if (matches.isNotEmpty) {
      _navigateToMatch(0);
    }
  }

  /// Navigates to the previous search match, wrapping at the start.
  void _previousMatch() {
    if (_searchMatches.isEmpty) return;
    final prevIndex = _currentMatchIndex <= 0
        ? _searchMatches.length - 1
        : _currentMatchIndex - 1;
    _navigateToMatch(prevIndex);

    // Request focus on editor when navigating with keyboard shortcuts
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final focusNode = findFocusableElement(context);
        if (focusNode != null) {
          focusNode.requestFocus();
        }
      }
    });
  }

  /// Persists current editor content to disk and clears dirty state.
  Future<void> _saveFile() async {
    if (_currentFile.isEmpty) return;

    try {
      final file = File(_currentFile);
      await file.writeAsString(_codeController.text);

      if (mounted) {
        setState(() {
          _savedText = _codeController.text;
          _isDirty = false;
        });

        // Update document state if we have document state
        if (widget.documentState != null) {
          widget.documentState!.isDirty = false;
        }

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

    // Note: Actual folding functionality will be implemented when CodeCrafter
    // supports folding operations. For now, this manages the UI state and icon.
    // Future implementation may use LSP requests or direct folding methods
    // depending on CodeCrafter's API.

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
      final gitService = GitService();
      final isGitRepo = await gitService.isGitRepository(
        path.dirname(_currentFile),
      );

      if (!isGitRepo) {
        MessageBox.showError(context, 'Not a Git repository');
        return;
      }

      final diff = await gitService.getFileDiff(
        path.dirname(_currentFile),
        _currentFile,
      );

      if (!mounted) return;

      if (diff.isEmpty || diff.startsWith('Error')) {
        MessageBox.showInfo(context, 'No changes to show');
        return;
      }

      // Get the original file content (HEAD version) for oldText
      String oldText = '';
      try {
        final projectPath = path.dirname(_currentFile);
        // Calculate relative path from git repo root
        final gitRootResult = await Process.run('git', [
          'rev-parse',
          '--show-prefix',
        ], workingDirectory: projectPath);
        String relativePath;
        if (gitRootResult.exitCode == 0) {
          final prefix = gitRootResult.stdout.toString().trim();
          if (prefix.isNotEmpty) {
            // Remove the prefix from the file path to get relative path from repo root
            final fileName = path.basename(_currentFile);
            final dirPath = path.dirname(_currentFile);
            final relativeDir = path.relative(dirPath, from: projectPath);
            relativePath = relativeDir.isEmpty
                ? fileName
                : path.join(relativeDir, fileName);
          } else {
            relativePath = path.basename(_currentFile);
          }
        } else {
          // Fallback to just basename if we can't determine git root
          relativePath = path.basename(_currentFile);
        }

        _logger.info('Getting HEAD content for: $relativePath in $projectPath');
        oldText = await gitService.getFileContentAtRevision(
          projectPath,
          relativePath,
          'HEAD',
        );
        _logger.info('Got HEAD content, length: ${oldText.length}');
      } catch (e) {
        // If HEAD doesn't exist (new file), oldText remains empty
        _logger.warning('Could not get HEAD version of file: $e');
        // For debugging, let's also try to get the current working content as a fallback
        try {
          final file = File(_currentFile);
          if (await file.exists()) {
            final currentContent = await file.readAsString();
            _logger.info(
              'Current file content length: ${currentContent.length}',
            );
            // Don't set oldText to current content, that would make diff empty
          }
        } catch (fileError) {
          _logger.warning('Could not read current file: $fileError');
        }
      }

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

  /// Toggles the search UI and restores query input state.
  void _toggleSearch() {
    if (!mounted) return;
    setState(() {
      if (_showSearch) {
        _closeSearch();
      } else {
        _showSearch = true;
        _searchController.text = _searchQuery;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _searchFocusNode.requestFocus();
          }
        });
      }
    });
  }
}
