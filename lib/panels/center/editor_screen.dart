// ignore_for_file: deprecated_member_use, use_build_context_synchronously, avoid_print

import 'dart:convert';
import 'dart:io';
import 'package:fide/panels/center/large_file_message.dart';
import 'package:fide/providers/app_providers.dart';
import 'package:flutter_code_crafter/code_crafter.dart';
import 'package:fide/utils/message_box.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as path;
import 'package:url_launcher/url_launcher.dart';
import 'package:fide/utils/file_type_utils.dart';
import 'package:fide/models/document_state.dart';
import 'package:fide/widgets/search_toggle_icons.dart';
import 'package:fide/widgets/diff_counter.dart';
import 'package:fide/widgets/side_by_side_diff.dart';
import 'package:fide/widgets/toggle_experience_mode.dart';
import 'package:fide/services/git_service.dart';

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

  static void formatCurrentFile() {
    _currentEditor?._formatFile();
  }

  static void toggleSearch() {
    _currentEditor?._toggleSearch();
  }

  static void findNext() {
    _currentEditor?._nextMatch();
  }

  static void findPrevious() {
    _currentEditor?._previousMatch();
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
  late FocusNode _searchFocusNode;
  String _searchQuery = '';
  List<int> _searchMatches = [];
  int _currentMatchIndex = -1;
  bool _caseSensitive = false;
  bool _wholeWord = false;

  // Track the saved text to determine if file is dirty
  late String _savedText;

  // Flag to prevent actions after dispose
  bool _isDisposed = false;

  // Git diff stats for all open documents
  final Map<String, GitDiffStats?> _allGitDiffStats = {};

  // Diff view mode
  bool _showDiffView = false;
  String? _diffOldText;
  String? _diffNewText;

  // Code folding state
  bool _regionsExpanded = true;

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
      builder: (context, ref, child) {
        final openDocuments = ref.watch(openDocumentsProvider);
        final activeIndex = ref.watch(activeDocumentIndexProvider);

        // Load git stats for all documents if not already loaded
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _loadGitDiffStatsForAllDocuments(openDocuments);
        });

        return Scaffold(
          appBar: AppBar(
            title: Row(
              children: [
                // Document dropdown on the left
                if (openDocuments.isNotEmpty)
                  DropdownButton<int>(
                    value: activeIndex,
                    items: openDocuments.asMap().entries.map((entry) {
                      final index = entry.key;
                      final doc = entry.value;
                      final gitStats = _allGitDiffStats[doc.filePath];

                      return DropdownMenuItem<int>(
                        value: index,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              doc.fileName,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(width: 8),
                            DiffCounter(gitStats: gitStats),
                          ],
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
                // Spacer to center the toggle button
                Spacer(),
                // Git diff button in the center (only show if there are git changes)
                if (_allGitDiffStats[_currentFile]?.hasChanges ?? false)
                  ToggleExperienceMode(
                    isAlternativeMode: _showDiffView,
                    primaryIcon: Icons.difference,
                    alternativeIcon: Icons.edit,
                    primaryTooltip: 'Show Diff View',
                    alternativeTooltip: 'Back to Editor',
                    onPressed: _toggleDiffView,
                  ),
                Spacer(),
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
                onPressed: _showDiffView ? null : _toggleSearch,
                tooltip: 'Find (Cmd+F)',
              ),
              IconButton(
                icon: const Icon(Icons.download),
                onPressed: _isDirty ? _saveFile : null,
                tooltip: 'Save',
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => EditorScreen.closeCurrentEditor(),
                tooltip: 'Close Editor',
              ),
            ],
          ),
          body: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _currentFile.isEmpty
              ? const Center(child: Text('No file selected'))
              : !FileTypeUtils.isFileSupportedInEditor(_currentFile)
              ? _buildUnsupportedFileView()
              : _isImageFile(_currentFile)
              ? _buildImageView()
              : _showDiffView
              ? _buildDiffView()
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
                            if (_showDiffView)
                              const Text(
                                'Diff View',
                                style: TextStyle(fontSize: 12),
                              )
                            else ...[
                              IconButton(
                                icon: Icon(
                                  _regionsExpanded
                                      ? Icons.unfold_less
                                      : Icons.unfold_more,
                                  size: 16,
                                ),
                                onPressed: _toggleAllRegions,
                                tooltip: _regionsExpanded
                                    ? 'Collapse All Regions (Ctrl+Shift+[)'
                                    : 'Expand All Regions (Ctrl+Shift+])',
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(
                                  minWidth: 24,
                                  minHeight: 24,
                                ),
                              ),
                              const SizedBox(width: 8),
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
                            ],
                            const Spacer(),
                            // Format File button (only show for supported files)
                            if (!_showDiffView &&
                                (_currentFile.endsWith('.dart') ||
                                    _currentFile.endsWith('.json') ||
                                    _currentFile.endsWith('.arb')))
                              IconButton(
                                icon: const Icon(
                                  Icons.format_indent_increase,
                                  size: 16,
                                ),
                                onPressed: _formatFile,
                                tooltip: 'Format File (Shift+Alt+F)',
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(
                                  minWidth: 24,
                                  minHeight: 24,
                                ),
                              ),
                            const SizedBox(width: 8),
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

  Widget _buildDiffView() {
    if (_diffOldText == null || _diffNewText == null) {
      return const Center(child: Text('No diff data available'));
    }

    return SideBySideDiff(oldText: _diffOldText!, newText: _diffNewText!);
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
                          MessageBox.showError(
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

  bool _isImageFile(String filePath) {
    return FileTypeUtils.isImageFile(filePath);
  }

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
            _searchFocusNode.requestFocus();
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
    _searchFocusNode.unfocus();
  }

  void _handleKeyEvent(RawKeyEvent event) {
    if (event is RawKeyDownEvent) {
      if (_showSearch) {
        if (event.logicalKey == LogicalKeyboardKey.escape) {
          _closeSearch();
        } else if (event.logicalKey == LogicalKeyboardKey.enter) {
          _nextMatch();
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
                  focusNode: _searchFocusNode,
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
              SearchToggleIcons(
                caseSensitive: _caseSensitive,
                wholeWord: _wholeWord,
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
