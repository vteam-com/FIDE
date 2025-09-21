// ignore_for_file: deprecated_member_use, use_build_context_synchronously, avoid_print

import 'dart:io';
import 'package:fide/panels/center/large_file_message.dart';
import 'package:fide/providers/app_providers.dart';
import 'package:flutter_code_crafter/code_crafter.dart';
import 'package:fide/utils/message_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as path;
import 'package:url_launcher/url_launcher.dart';
import 'package:fide/utils/file_type_utils.dart';
import 'package:fide/models/document_state.dart';

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

  static void closeCurrentEditor() {
    _currentEditor?.widget.onClose?.call();
  }

  @override
  State<EditorScreen> createState() => _EditorScreenState();

  static void navigateToLine(int lineNumber, {int column = 1}) {
    _currentEditor?._navigateToLine(lineNumber, column: column);
  }

  static void saveCurrentEditor() {
    _currentEditor?._saveFile();
  }
}

class _EditorScreenState extends State<EditorScreen> {
  final Logger _logger = Logger('EditorScreenState');

  late CodeCrafterController _codeController;

  late GlobalKey _codeCrafterKey;

  late String _currentFile;

  bool _isDirty = false;

  bool _isLoading = false;
  bool _isLargeFile = false;
  double _fileSizeMB = 0.0;

  // Search functionality
  bool _showSearch = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  List<int> _searchMatches = [];
  int _currentMatchIndex = -1;
  bool _caseSensitive = false;
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

    // Initialize from document state (always provided by CenterPanel)
    _codeController.text = widget.documentState!.content;
    _codeController.selection = widget.documentState!.selection;
    if (widget.documentState!.language != null) {
      _codeController.language = widget.documentState!.language;
    }
    _isDirty = widget.documentState!.isDirty;

    _codeController.addListener(_onCodeChanged);

    // Register this editor as the current editor for global save access
    EditorScreen._currentEditor = this;
  }

  @override
  void dispose() {
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

    // Remove listener before disposing controller
    _codeController.removeListener(_onCodeChanged);
    _codeController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(EditorScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Check if document state changed
    if (widget.documentState != oldWidget.documentState) {
      if (widget.documentState != null) {
        // Update to new document state
        _currentFile = widget.documentState!.filePath;

        // Temporarily remove listener to avoid triggering during programmatic update
        _codeController.removeListener(_onCodeChanged);

        _codeController.text = widget.documentState!.content;
        _codeController.selection = widget.documentState!.selection;
        if (widget.documentState!.language != null) {
          _codeController.language = widget.documentState!.language;
        }

        // Re-add listener
        _codeController.addListener(_onCodeChanged);

        setState(() {
          _isDirty = widget.documentState!.isDirty;
          _isLoading = false;
          _isLargeFile = false; // Reset large file flag for new file
          _fileSizeMB = 0.0;
        });
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
      builder: (context, ref, child) {
        final openDocuments = ref.watch(openDocumentsProvider);
        final activeIndex = ref.watch(activeDocumentIndexProvider);

        return Scaffold(
          appBar: AppBar(
            title: Row(
              children: [
                // Document dropdown
                if (openDocuments.isNotEmpty)
                  DropdownButton<int>(
                    value: activeIndex,
                    items: openDocuments.asMap().entries.map((entry) {
                      final index = entry.key;
                      final doc = entry.value;
                      return DropdownMenuItem<int>(
                        value: index,
                        child: Text(
                          doc.fileName,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontSize: 14,
                          ),
                        ),
                      );
                    }).toList(),
                    onChanged: (newIndex) {
                      if (newIndex != null) {
                        ref.read(activeDocumentIndexProvider.notifier).state =
                            newIndex;
                      }
                    },
                    underline: const SizedBox.shrink(),
                    icon: Icon(
                      Icons.arrow_drop_down,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
              ],
            ),
            actions: [
              if (_isDirty)
                const Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 8.0,
                  ),
                  child: Center(
                    child: Text(
                      'Unsaved Changes',
                      style: TextStyle(
                        color: Colors.orange,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ),
              IconButton(
                icon: const Icon(Icons.search),
                onPressed: _toggleSearch,
                tooltip: 'Find (Cmd+F)',
              ),
              IconButton(
                icon: const Icon(Icons.download),
                onPressed: _isDirty ? _saveFile : null,
                tooltip: 'Save',
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: widget.onClose,
                tooltip: 'Close Editor',
              ),
            ],
          ),
          body: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _currentFile.isEmpty
              ? const Center(child: Text('No file selected'))
              : !_isFileTypeSupported(_currentFile)
              ? _buildUnsupportedFileView()
              : _isImageFile(_currentFile)
              ? _buildImageView()
              : RawKeyboardListener(
                  focusNode: FocusNode(),
                  onKey: _handleKeyEvent,
                  child: Column(
                    children: [
                      // Search bar (only visible when searching)
                      if (_showSearch) _buildSearchBar(),
                      // Editor content
                      Expanded(
                        child: CodeCrafter(
                          key: _codeCrafterKey,
                          controller: _codeController,
                          enableGutterDivider: false, // they have a bug
                          gutterStyle: GutterStyle(
                            dividerColor: Colors.grey.withAlpha(100),
                            dividerThickness: 1,
                            lineNumberStyle: TextStyle(
                              // fontFamily: 'monospace',
                              letterSpacing: -1,

                              color: Theme.of(
                                context,
                              ).colorScheme.onSurface.withOpacity(0.5),
                            ),
                          ),

                          // textStyle: const TextStyle(fontFamily: 'monospace'),
                          editorTheme: _getCodeTheme(),
                        ),
                      ),
                      // Status bar
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        child: Row(
                          children: [
                            Text(
                              'Ln ${_getCurrentLineNumber()}',
                              style: const TextStyle(fontSize: 12),
                            ),
                            const SizedBox(width: 16),
                            Text(
                              'Col ${_getCurrentColumnNumber()}',
                              style: const TextStyle(fontSize: 12),
                            ),
                            if (_searchMatches.isNotEmpty) ...[
                              const SizedBox(width: 16),
                              Text(
                                '${_currentMatchIndex + 1} of ${_searchMatches.length}',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ],
                            const Spacer(),
                            Text(
                              _getFileLanguage(),
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
        );
      },
    );
  }

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

  Widget _buildImageView() {
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Image display with error handling
            Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.8,
                maxHeight: MediaQuery.of(context).size.height * 0.7,
              ),
              child: Image.file(
                File(_currentFile),
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.broken_image,
                        size: 64,
                        color: Theme.of(
                          context,
                        ).colorScheme.error.withOpacity(0.5),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Failed to load image',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              color: Theme.of(context).colorScheme.error,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'The image file may be corrupted or unsupported',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withOpacity(0.6),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            // Image info
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest.withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Text(
                    'Image Preview',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Size: ${(widget.documentState!.content.length / 1024).round()}KB • ${path.extension(_currentFile).toUpperCase().substring(1)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUnsupportedFileView() {
    final extension = _currentFile.split('.').last.toLowerCase();
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.insert_drive_file_outlined,
            size: 64,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              ),
              children: [
                const TextSpan(text: 'The file type '),
                TextSpan(
                  text: '.${extension.toUpperCase()}',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const TextSpan(text: ' is not yet supported'),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.primaryContainer.withOpacity(0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                Text(
                  'Request this feature at',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withOpacity(0.6),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                InkWell(
                  onTap: () async {
                    const urlString =
                        'https://github.com/vteam-com/FIDE/issues';
                    try {
                      final url = Uri.parse(urlString);
                      if (Platform.isMacOS) {
                        await launchUrl(url, mode: LaunchMode.platformDefault);
                      } else {
                        await launchUrl(
                          url,
                          mode: LaunchMode.externalApplication,
                        );
                      }
                    } catch (e) {
                      // Fallback: try to launch without checking if URL can be launched
                      try {
                        final url = Uri.parse(urlString);
                        await launchUrl(url, mode: LaunchMode.platformDefault);
                      } catch (fallbackError) {
                        if (mounted) {
                          MessageHelper.showError(
                            context,
                            'Could not open link: $urlString ${fallbackError.toString()}',
                            showCopyButton: true,
                          );
                        }
                      }
                    }
                  },
                  child: Text(
                    'github.com/vteam-com/FIDE/issues',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w500,
                      decoration: TextDecoration.underline,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Currently supported: Most text files including\n'
            'programming languages, web files, configs, scripts, and images',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Map<String, TextStyle> _getCodeTheme() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseTextColor = Theme.of(context).colorScheme.onPrimary;

    return {
      'root': TextStyle(
        backgroundColor: Theme.of(context).colorScheme.surface,
        color: Theme.of(context).colorScheme.onSurface,
      ),
      'comment': TextStyle(
        color: isDark ? Colors.green[300] : Colors.green[800],
      ),
      'keyword': TextStyle(
        color: isDark ? Colors.purple[300] : Colors.purple[700],
        fontWeight: FontWeight.bold,
      ),
      'string': TextStyle(color: isDark ? Colors.red[300] : Colors.red[700]),
      'number': TextStyle(color: isDark ? Colors.blue[300] : Colors.blue[700]),
      'variable': TextStyle(color: isDark ? Colors.white70 : Colors.black87),
      'class': TextStyle(
        color: isDark ? Colors.blue[300] : Colors.blue[700],
        fontWeight: FontWeight.bold,
      ),
      'function': TextStyle(
        color: isDark ? Colors.blue[200] : Colors.blue[700],
      ),
      'operator': TextStyle(color: baseTextColor, fontWeight: FontWeight.bold),
    };
  }

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

  bool _isFileTypeSupported(String filePath) {
    return FileTypeUtils.isSourceFile(filePath);
  }

  bool _isImageFile(String filePath) {
    return FileTypeUtils.isImageFile(filePath);
  }

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

  void _onCodeChanged() {
    // Check if widget is still mounted before calling setState
    if (!mounted) return;

    // Always trigger a rebuild when selection or text changes
    setState(() {
      // Mark as dirty if text has changed and wasn't already dirty
      if (!_isDirty) {
        _isDirty = true;
      }
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

  Future<void> _saveFile() async {
    if (_currentFile.isEmpty) return;

    try {
      final file = File(_currentFile);
      await file.writeAsString(_codeController.text);

      if (mounted) {
        setState(() => _isDirty = false);

        // Update document state if we have document state
        if (widget.documentState != null) {
          widget.documentState!.isDirty = false;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('File saved successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error saving file: $e')));
      }
    }
  }

  // Search functionality methods
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
        if (maxExtent < 1000000 && maxExtent > 100) {
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
        const double lineHeight = 20.0; // More conservative line height
        final double targetScrollOffset =
            (lineNumber - 3) * lineHeight; // Start 3 lines above target
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
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOut,
          alignment: 0.3, // Center the selection in the viewport
        );
      }
    } catch (e) {
      _logger.severe('Scrolling error: $e');
    }
  }

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

  void _toggleSearch() {
    setState(() {
      if (_showSearch) {
        _closeSearch();
      } else {
        _showSearch = true;
        _searchController.text = _searchQuery;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            // Focus the search field
            // We'll handle this in the build method
          }
        });
      }
    });
  }

  void _closeSearch() {
    setState(() {
      _showSearch = false;
      _searchController.clear();
      _searchQuery = '';
      _searchMatches.clear();
      _currentMatchIndex = -1;
    });
  }

  void _handleKeyEvent(RawKeyEvent event) {
    if (event is RawKeyDownEvent) {
      final isCmd = event.isMetaPressed || event.isControlPressed;
      if (isCmd && event.logicalKey == LogicalKeyboardKey.keyF) {
        _toggleSearch();
        return;
      }

      if (_showSearch) {
        if (event.logicalKey == LogicalKeyboardKey.escape) {
          _closeSearch();
        } else if (event.logicalKey == LogicalKeyboardKey.enter) {
          _nextMatch();
        } else if (event.logicalKey == LogicalKeyboardKey.f3) {
          if (event.isShiftPressed) {
            _previousMatch();
          } else {
            _nextMatch();
          }
        }
      }
    }
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withOpacity(0.5),
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
            width: 1,
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: 'Find in file...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    isDense: true,
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surface,
                  ),
                  onChanged: _performSearch,
                  onSubmitted: (_) => _nextMatch(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: _closeSearch,
                tooltip: 'Close (Esc)',
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              SizedBox(
                height: 24,
                child: Checkbox(
                  value: _caseSensitive,
                  onChanged: (value) {
                    setState(() {
                      _caseSensitive = value ?? false;
                      if (_searchQuery.isNotEmpty) {
                        _performSearch(_searchQuery);
                      }
                    });
                  },
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
              ),
              const Text('Case sensitive', style: TextStyle(fontSize: 12)),
              const SizedBox(width: 12),
              SizedBox(
                height: 24,
                child: Checkbox(
                  value: _wholeWord,
                  onChanged: (value) {
                    setState(() {
                      _wholeWord = value ?? false;
                      if (_searchQuery.isNotEmpty) {
                        _performSearch(_searchQuery);
                      }
                    });
                  },
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
              ),
              const Text('Whole word', style: TextStyle(fontSize: 12)),
              const Spacer(),
              if (_searchMatches.isNotEmpty) ...[
                IconButton(
                  icon: const Icon(Icons.keyboard_arrow_up, size: 18),
                  onPressed: _previousMatch,
                  tooltip: 'Previous (Shift+F3)',
                  visualDensity: VisualDensity.compact,
                ),
                IconButton(
                  icon: const Icon(Icons.keyboard_arrow_down, size: 18),
                  onPressed: _nextMatch,
                  tooltip: 'Next (F3)',
                  visualDensity: VisualDensity.compact,
                ),
                const SizedBox(width: 8),
                Text(
                  '${_currentMatchIndex + 1} of ${_searchMatches.length}',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
