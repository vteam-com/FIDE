// ignore_for_file:  use_build_context_synchronously, avoid_print

import 'package:code_forge/code_forge.dart';
import 'package:fide/constants/constants.dart';
import 'package:fide/models/document_state.dart';
import 'package:fide/models/editor_diff_outcome.dart';
import 'package:fide/models/editor_search.dart';
import 'package:fide/models/readable_error.dart';
import 'package:fide/models/text_offsets.dart';
import 'package:fide/panels/center/editor/code_folding.dart';
import 'package:fide/panels/center/editor/completion_row.dart';
import 'package:fide/panels/center/editor/editor_diagnostics.dart';
import 'package:fide/panels/center/editor/editor_popup_style.dart';
import 'package:fide/panels/center/editor/editor_screen_audio_view.dart';
import 'package:fide/panels/center/editor/editor_screen_font_view.dart';
import 'package:fide/panels/center/editor/editor_screen_header.dart';
import 'package:fide/panels/center/editor/editor_screen_image_diff_view.dart';
import 'package:fide/panels/center/editor/editor_screen_image_view.dart';
import 'package:fide/panels/center/editor/editor_screen_markdown_view.dart';
import 'package:fide/panels/center/editor/editor_screen_search_bar.dart';
import 'package:fide/panels/center/editor/editor_screen_status_bar.dart';
import 'package:fide/panels/center/editor/editor_screen_unsupported_file_view.dart';
import 'package:fide/panels/center/editor/editor_search_controller.dart';
import 'package:fide/panels/center/editor/editor_session.dart';
import 'package:fide/providers/active_editor.dart';
import 'package:fide/providers/app_providers.dart';
import 'package:fide/providers/editor_navigation.dart';
import 'package:fide/providers/markdown_preview_notifier.dart';
import 'package:fide/providers/service_providers.dart';
import 'package:fide/providers/ui_state_providers.dart';
import 'package:fide/services/code_formatter.dart';
import 'package:fide/services/dart_language_server.dart';
import 'package:fide/services/editor_commands.dart';
import 'package:fide/services/file_type_utils.dart';
import 'package:fide/services/reference_finder.dart';
import 'package:fide/theme/app_theme.dart';
import 'package:fide/widgets/empty_state.dart';
import 'package:fide/widgets/loading_indicator.dart';
import 'package:fide/widgets/message_box.dart';
import 'package:fide/widgets/sdk_material_localizations.dart';
import 'package:fide/widgets/side_by_side_diff.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;

/// Full-featured code editor widget with syntax highlighting, search, diff view, and file-save support.
///
/// Shows the open document of [filePath]: it loads the document's text
/// and caret when the file changes, and watches only the document's
/// fields it renders, so edits don't rebuild it through the open
/// documents.
///
/// With the project's Dart language server, it completes the code, shows
/// the documentation of what the pointer rests on and the parameters of
/// the call typed, and underlines the problems of the code as typed.
class EditorScreen extends ConsumerStatefulWidget {
  /// Creates the editor of the open [filePath], using [languageServer]
  /// when there is one.
  const EditorScreen({
    super.key,
    required this.filePath,
    this.languageServer,
    this.onClose,
  });

  /// The open file to show.
  final String filePath;

  /// The project's Dart language server, which the editor uses for as
  /// long as it lives; none when null.
  final DartLanguageServer? languageServer;

  /// Closes the editor's file, from its header's Close or a command.
  final VoidCallback? onClose;

  @override
  ConsumerState<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends ConsumerState<EditorScreen>
    implements EditorCommands {
  late final ActiveEditor _activeEditor;

  bool _appIsActive = true;

  Map<String, TextStyle>? _codeTheme;

  ThemeData? _codeThemeSource;

  bool _editorHasFocus = false;

  /// Whether the press under way is a primary click with the
  /// [_isDefinitionKeyPressed] key down, which goes to the definition of
  /// the name it puts the caret on.
  bool _isDefinitionClick = false;

  bool _isDisposed = false;

  /// The session's dirty flag as last shown; the session's changes rebuild
  /// the editor only when it changes, a caret move rebuilding just the
  /// status bar.
  bool _isDirtyShown = false;

  bool _isLoading = false;

  late final AppLifecycleListener _lifecycleListener;

  /// Writes the unsaved edits of the view showing a media file, such as a
  /// trimmed sound; null while it has none.
  AsyncCallback? _mediaSave;

  final Logger _logger = Logger('EditorScreenState');

  bool _regionsExpanded = true;

  /// The document's text, dirty state, saves, formatting and diff.
  late final EditorSession _session = EditorSession(
    documents: ref.read(openDocumentsProvider.notifier),
    formatter: ref.read(codeFormatterProvider),
    git: ref.read(gitServiceProvider),
    languageServer: widget.languageServer,
  )..addListener(_onSessionChanged);

  /// The problems the editor underlines: the language server's and the
  /// project's quality findings.
  late final EditorDiagnostics _diagnostics = EditorDiagnostics(
    _codeController,
    server: widget.languageServer?.diagnostics,
  );

  /// Find and replace in the editor's text.
  late final EditorSearchController _search = EditorSearchController(
    _session.code,
    onMatchSelected: _revealSelectionAfterFrame,
  )..addListener(_onSearchChanged);

  /// Receives the find bar's Escape and Enter keys.
  final FocusNode _searchKeysFocusNode = FocusNode();

  bool _showDiffView = false;

  /// Whether going to a line made this Markdown file show its text though
  /// View as Markdown is on; only until another file shows or the toggle
  /// is used, so the choice still holds for the next Markdown file.
  bool _showsLine = false;

  /// The editor's text and selection.
  CodeForgeController get _codeController => _session.code;

  /// The file loaded, empty while none is.
  String get _currentFile => _session.filePath;

  @override
  void initState() {
    super.initState();

    _loadDocument();

    _diagnostics.show(_currentFile, ref.read(qualityIssuesProvider));
    ref.listenManual(qualityIssuesProvider, (_, issues) {
      _diagnostics.show(_currentFile, issues);
      setState(() {}); // The status bar shows the cursor line's findings
    });

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

    _activeEditor.detach(this);

    _lifecycleListener.dispose();

    _search
      ..removeListener(_onSearchChanged)
      ..dispose();
    _searchKeysFocusNode.dispose();
    _diagnostics.dispose();
    // Auto-saves unsaved changes
    _session
      ..removeListener(_onSessionChanged)
      ..dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(EditorScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Only a different file means the editor must load new content
    if (widget.filePath != oldWidget.filePath) {
      // The diff shown was the previous file's; showing it again loads
      // this file's
      _showDiffView = false;
      _showsLine = false;
      _mediaSave = null;
      _loadDocument();
      _diagnostics.show(_currentFile, ref.read(qualityIssuesProvider));
      setState(() => _isLoading = false);

      // Set selection safely after the build cycle, checking mounted status and not disposed
      if (mounted && !_isDisposed) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final document = _document;
          if (mounted && !_isDisposed && document != null) {
            _session.restoreSelection(document.selection);
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // The tabs and whether the file shows as plain text, not the text or
    // caret, which change on each edit
    final tabs = ref.watch(openDocumentsProvider.select((d) => d.tabs));
    ref.watch(
      openDocumentsProvider.select(
        (d) => d.documentOf(widget.filePath)?.asPlainText,
      ),
    );
    ref.watch(markdownPreviewProvider);

    return Column(
      children: [
        EditorScreenHeader(
          filePaths: tabs.filePaths,
          activeIndex: tabs.activeIndex,
          currentFile: _currentFile,
          viewKind: _viewKind,
          isDirty: _pendingSave != null,
          showDiffView: _showDiffView,
          showMarkdown: _showsMarkdown,
          onShowMarkdown: _canShowMarkdown ? _showMarkdown : null,
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
  }

  /// The open document of [EditorScreen.filePath], or null once it is
  /// closed.
  DocumentState? get _document =>
      ref.read(openDocumentsProvider).documentOf(widget.filePath);

  /// Loads the open document of [EditorScreen.filePath] into the session.
  void _loadDocument() {
    _session.load(_document ?? DocumentState(filePath: widget.filePath));
    _isDirtyShown = _session.isDirty;
  }

  /// The editor's body: a loading or empty state while there is no
  /// content, else the view [_currentFile]'s kind calls for.
  Widget _buildContent() {
    if (_isLoading) return const LoadingIndicator();
    if (_currentFile.isEmpty) {
      return const EmptyState(message: 'No file selected');
    }
    return switch (_viewKind) {
      FileViewKind.unsupported => EditorScreenUnsupportedFileView(
        filePath: _currentFile,
        onOpenAsPlainText: _openAsPlainText,
      ),
      FileViewKind.image =>
        _showDiffView
            ? EditorScreenImageDiffView(filePath: _currentFile)
            : EditorScreenImageView(filePath: _currentFile),
      FileViewKind.audio => EditorScreenAudioView(
        filePath: _currentFile,
        onSaveChanged: (save) => setState(() => _mediaSave = save),
      ),
      FileViewKind.font => EditorScreenFontView(filePath: _currentFile),
      FileViewKind.code =>
        _showDiffView
            ? _buildDiffView()
            : _showsMarkdown
            ? EditorScreenMarkdownView(
                filePath: _currentFile,
                text: _codeController.text,
              )
            : _buildCodeView(),
    };
  }

  /// Whether [_currentFile] is Markdown shown in the code editor, which can
  /// also show it rendered.
  bool get _canShowMarkdown =>
      _viewKind == FileViewKind.code && FileTypeUtils.isMarkdown(_currentFile);

  /// Whether [_currentFile] shows as rendered Markdown: the user chose it
  /// for Markdown files, and neither the diff view, which shows the text's
  /// changes, nor a line gone to shows instead.
  bool get _showsMarkdown =>
      !_showDiffView &&
      !_showsLine &&
      _canShowMarkdown &&
      ref.read(markdownPreviewProvider);

  /// Shows Markdown files rendered when [show], else as their text,
  /// leaving the diff view, and remembers the choice.
  void _showMarkdown(bool show) {
    if (_showDiffView) _toggleDiffView();
    setState(() => _showsLine = false);
    ref.read(markdownPreviewProvider.notifier).setPreview(show);
  }

  /// How [_currentFile] shows: as code once opened as plain text, else as
  /// its type calls for.
  FileViewKind get _viewKind => (_document?.asPlainText ?? false)
      ? FileViewKind.code
      : FileTypeUtils.viewKindOf(_currentFile);

  /// Shows [_currentFile] as plain text, or says why it can't.
  Future<void> _openAsPlainText() async {
    final opened = await ref
        .read(openDocumentsProvider.notifier)
        .openAsPlainText(_currentFile);
    if (!opened && mounted) {
      MessageBox.showError(
        context,
        '${p.basename(_currentFile)} is not a text file the editor can open',
      );
    }
  }

  /// The code editor with its find bar and status bar.
  Widget _buildCodeView() {
    // CodeForge reads its popups' styles once, so a new theme makes a new
    // one, styled by the theme a theme change animates to, not by a frame
    // of the animation
    final brightness = Theme.of(context).brightness;
    final popupTheme = AppTheme.of(brightness);
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
                // Sees each click after CodeForge has put the caret there
                child: Listener(
                  onPointerDown: _onCodePointerDown,
                  onPointerUp: _onCodePointerUp,
                  // CodeForge is built with the SDK's Material library
                  child: SdkMaterialLocalizations(
                    child: CodeForge(
                      key: ValueKey(brightness),
                      controller: _codeController,
                      // With a language server CodeForge needs the
                      // file, which the session already shows it, if any
                      filePath: _codeController.openedFile ?? '',
                      language:
                          _document?.language ??
                          FileTypeUtils.languageForFile(_currentFile),
                      gutterStyle: GutterStyle(
                        lineNumberStyle: AppTextStyle.lineNumber(context),
                      ),
                      editorTheme: _getCodeTheme(),
                      suggestionStyle: EditorPopupStyle.suggestions(popupTheme),
                      lspSuggestionBuilder: (_, completion, isSelected) =>
                          CompletionRow(
                            completion: completion,
                            isSelected: isSelected,
                          ),
                      hoverDetailsStyle: EditorPopupStyle.hover(popupTheme),
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Status bar, rebuilt alone as the caret moves
          ListenableBuilder(
            listenable: _session,
            builder: (_, _) => EditorScreenStatusBar(
              showDiffView: _showDiffView,
              regionsExpanded: _regionsExpanded,
              currentLineNumber: _getCurrentLineNumber(),
              currentColumnNumber: _getCurrentColumnNumber(),
              findings: _diagnostics.onLine(_getCurrentLineNumber() - 1),
              currentMatchIndex: _search.currentIndex,
              matchCount: _search.matchCount,
              canFormat: !_showDiffView && _session.canFormat,
              fileLanguage: _getFileLanguage(),
              onToggleAllRegions: _toggleAllRegions,
              onFormatFile: () {
                _formatFile();
              },
            ),
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
  Future<void> goToDefinition() async {
    final finder = ref.read(referenceFinderProvider);
    if (finder == null || _showDiffView || _viewKind != FileViewKind.code) {
      return;
    }
    if (!FileTypeUtils.isDartFile(_currentFile)) {
      MessageBox.showInfo(context, 'Go to Definition reads Dart files only');
      return;
    }
    try {
      final place = await finder.definition(
        filePath: _currentFile,
        offset: _codeController.selection.extentOffset,
        content: _codeController.text,
      );
      if (!mounted) return;
      await openPlace(ref, place);
    } catch (error) {
      final message = ReadableError.describe(error);
      // A newer lookup replaced this one: only its answer shows
      if (mounted && message != ReferenceFinder.superseded) {
        MessageBox.showInfo(context, message);
      }
    }
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

  @override
  void showDiff() {
    if (!_showDiffView) _toggleDiffView();
  }

  Widget _buildDiffView() {
    final diff = _session.diff;
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

    if (!_session.canFormat) {
      MessageBox.showInfo(
        context,
        'Formatting is currently only supported for ${CodeFormatter.supportedDescription} files',
      );
      return;
    }

    try {
      setState(() => _isLoading = true);

      final formattedContent = await _session.format();

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
    _codeTheme = AppTheme.codeTheme(theme);

    return _codeTheme!;
  }

  /// 1-based column of the cursor.
  int _getCurrentColumnNumber() => _cursorPosition.column;

  /// 1-based line of the cursor.
  int _getCurrentLineNumber() => _cursorPosition.line;

  /// Line and column of the cursor in the editor text.
  ({int line, int column}) get _cursorPosition => _session.cursor;

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

  /// Whether the key that makes a click go to the definition is down: ⌘
  /// on macOS, Ctrl elsewhere, as in VS Code.
  static bool get _isDefinitionKeyPressed =>
      defaultTargetPlatform == TargetPlatform.macOS
      ? HardwareKeyboard.instance.isMetaPressed
      : HardwareKeyboard.instance.isControlPressed;

  /// Notes whether [event] starts a click going to a definition.
  void _onCodePointerDown(PointerDownEvent event) {
    _isDefinitionClick =
        event.buttons == kPrimaryButton && _isDefinitionKeyPressed;
  }

  /// Goes to the definition of the name a click going to one put the
  /// caret on; a drag selecting text doesn't.
  void _onCodePointerUp(PointerUpEvent _) {
    if (!_isDefinitionClick) return;
    _isDefinitionClick = false;
    if (_codeController.selection.isCollapsed) goToDefinition();
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

    // The line shows in the text, not in the rendered Markdown
    if (_showsMarkdown) _showsLine = true;

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

  /// Rebuilds when the session's dirty flag changes (the status bar
  /// follows the caret by itself) and publishes the cursor line.
  void _onSessionChanged() {
    if (!mounted || _isDisposed) return;

    final isDirty = _session.isDirty;
    if (isDirty != _isDirtyShown) setState(() => _isDirtyShown = isDirty);

    // Notify cursor position changes
    ref.read(editorCursorLineProvider.notifier).state = _getCurrentLineNumber();
  }

  /// Replaces every search match in one undoable edit and confirms how
  /// many.
  void _replaceAllMatches() {
    final count = _search.replaceAll();
    if (count == 0) return;
    MessageBox.showSuccess(context, EditorSearch.replacedMessage(count));
  }

  /// What Save writes: the code's edits, or the media view's; null without
  /// changes to save, so Save never writes a file it didn't change, such
  /// as an image, whose document holds no text.
  AsyncCallback? get _pendingSave => _viewKind == FileViewKind.code
      ? (_isDirtyShown ? _session.save : null)
      : _mediaSave;

  /// Writes the file's unsaved changes and confirms it; does nothing
  /// without changes.
  Future<void> _saveFile() async {
    final save = _pendingSave;
    if (save == null) return;
    final name = p.basename(_currentFile);
    try {
      await save();
      if (mounted) MessageBox.showSuccess(context, 'Saved $name');
    } catch (error) {
      if (mounted) {
        MessageBox.showError(
          context,
          "Couldn't save $name: ${ReadableError.describe(error)}",
        );
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
      setState(() => _showDiffView = false);
      _session.clearDiff();
      return;
    }

    if (_currentFile.isEmpty) {
      MessageBox.showError(context, 'No file selected');
      return;
    }
    // An image diff reads both versions itself
    if (FileTypeUtils.isImageFile(_currentFile)) {
      setState(() => _showDiffView = true);
      return;
    }

    try {
      final outcome = await _session.loadDiff();
      if (!mounted) return;

      switch (outcome) {
        case EditorDiffOutcome.notGitRepository:
          MessageBox.showError(context, 'Not a Git repository');
        case EditorDiffOutcome.unchanged:
          MessageBox.showInfo(context, 'No changes to show');
        case EditorDiffOutcome.loaded:
          setState(() => _showDiffView = true);
      }
    } catch (e) {
      if (mounted) {
        MessageBox.showError(context, 'Error getting diff: $e');
      }
    }
  }
}
