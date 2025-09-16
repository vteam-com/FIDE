// ignore_for_file: deprecated_member_use, use_build_context_synchronously, avoid_print

import 'dart:io';
import 'package:flutter_code_crafter/code_crafter.dart';
import 'package:fide/utils/message_helper.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:url_launcher/url_launcher.dart';
import 'package:highlight/languages/dart.dart';
import 'package:highlight/languages/yaml.dart';
import 'package:fide/utils/file_type_utils.dart';

class EditorScreen extends StatefulWidget {
  const EditorScreen({
    super.key,
    required this.filePath,
    this.onContentChanged,
    this.onClose,
    this.onSave,
  });

  static _EditorScreenState? _currentEditor;

  final String filePath;

  final VoidCallback? onClose;

  final VoidCallback? onContentChanged;

  static void Function(int)? onCursorPositionChanged;

  final VoidCallback? onSave;

  @override
  State<EditorScreen> createState() => _EditorScreenState();

  static void navigateToLine(int lineNumber) {
    print('EditorScreen.navigateToLine called with lineNumber: $lineNumber');
    print('Current editor is null: ${_currentEditor == null}');
    _currentEditor?._navigateToLine(lineNumber);
  }

  static void saveCurrentEditor() {
    _currentEditor?._saveFile();
  }
}

class _EditorScreenState extends State<EditorScreen> {
  late CodeCrafterController _codeController;

  final GlobalKey _codeFieldKey = GlobalKey();

  late String _currentFile;

  late FocusNode _focusNode;

  bool _isDirty = false;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _currentFile = widget.filePath;
    _focusNode = FocusNode();

    _codeController = CodeCrafterController();
    _codeController.text = _currentFile.isNotEmpty
        ? '// Loading...\n'
        : '// No file selected\n';
    _codeController.language = _getLanguageForFile(_currentFile);
    _codeController.addListener(_onCodeChanged);

    if (_currentFile.isNotEmpty) {
      _loadFile(_currentFile);
    }

    // Register this editor as the current editor for global save access
    EditorScreen._currentEditor = this;
  }

  @override
  void dispose() {
    // Unregister this editor if it's the current one
    if (EditorScreen._currentEditor == this) {
      EditorScreen._currentEditor = null;
    }
    _focusNode.dispose();
    _codeController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(EditorScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.filePath != oldWidget.filePath && widget.filePath.isNotEmpty) {
      _loadFile(widget.filePath);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _getTitleForFile(_currentFile),
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
        ),
        actions: [
          if (_isDirty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
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
            icon: const Icon(CupertinoIcons.arrow_down_doc),
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
          : Column(
              children: [
                Expanded(
                  child: CodeCrafter(
                    key: _codeFieldKey,
                    controller: _codeController,
                    focusNode: _focusNode,
                    gutterStyle: GutterStyle(
                      lineNumberStyle: TextStyle(
                        fontFamily: 'monospace',
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                    textStyle: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 14,
                    ),
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
    context.visitChildElements((element) {
      final widget = element.widget;
      if (widget is EditableText) {
        result = widget.focusNode;
      } else {
        result = findFocusableElement(element);
      }
      if (result != null) return;
    });
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
                  FutureBuilder<FileStat>(
                    future: File(_currentFile).stat(),
                    builder: (context, snapshot) {
                      if (snapshot.hasData) {
                        final stat = snapshot.data!;
                        final sizeKB = (stat.size / 1024).round();
                        return Text(
                          'Size: ${sizeKB}KB • ${path.extension(_currentFile).toUpperCase().substring(1)}',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withOpacity(0.7),
                              ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
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

  BuildContext? _findEditableTextContext(BuildContext root) {
    BuildContext? result;

    void visitor(Element element) {
      if (element.widget is EditableText) {
        result = element;
        return;
      }
      element.visitChildren(visitor);
    }

    try {
      (root as Element).visitChildren(visitor);
    } catch (_) {
      // ignore
    }

    return result;
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
      case 'xml':
      case 'html':
        return ext.toUpperCase();
      default:
        return 'Text';
    }
  }

  dynamic _getLanguageForFile(String filePath) {
    if (filePath.isEmpty) return null;
    final extension = filePath.split('.').last.toLowerCase();
    switch (extension) {
      case 'dart':
        return dart;
      case 'yaml':
      case 'yml':
        return yaml;
      case 'json':
        return null; // Use plain text for JSON
      default:
        return null; // Default to plain text
    }
  }

  String _getTitleForFile(String filePath) {
    if (filePath.isEmpty) return 'Untitled';
    return path.basename(filePath);
  }

  bool _isFileTypeSupported(String filePath) {
    return FileTypeUtils.isSourceFile(filePath);
  }

  bool _isImageFile(String filePath) {
    return FileTypeUtils.isImageFile(filePath);
  }

  Future<void> _loadFile(String filePath) async {
    if (filePath.isEmpty) return;

    setState(() {
      _isLoading = true;
      _currentFile = filePath;
    });

    // Skip text loading for image files - they are displayed directly
    if (_isImageFile(filePath)) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      return;
    }

    try {
      final file = File(filePath);
      if (await file.exists()) {
        final content = await file.readAsString();
        final language = _getLanguageForFile(filePath);

        if (mounted) {
          setState(() {
            _focusNode = FocusNode();
            _codeController.dispose();
            _codeController = CodeCrafterController();
            _codeController.text = content;
            _codeController.language = language;
            _codeController.addListener(_onCodeChanged);
            _isDirty = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading file: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _navigateToLine(int lineNumber) {
    // Basic validation
    if (_codeController.text.isEmpty || lineNumber < 1) {
      print('Early return: text is empty or line number invalid');
      return;
    }

    final lines = _codeController.text.split('\n');
    if (lineNumber > lines.length) {
      print(
        'Line number $lineNumber is greater than total lines ${lines.length}',
      );
      return;
    }

    // Calculate the character offset for the target line
    int offset = 0;
    for (int i = 0; i < lineNumber - 1 && i < lines.length; i++) {
      offset += lines[i].length + 1; // +1 for the newline character
    }

    // Clamp offset
    if (offset < 0) offset = 0;
    if (offset > _codeController.text.length) {
      offset = _codeController.text.length;
    }

    // Use a post-frame callback to set the selection and ensure the caret/line is visible
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      try {
        _codeController.selection = TextSelection.collapsed(offset: offset);
      } catch (e) {
        print('Failed to set selection: $e');
      }

      // Give focus to the editor so the caret is shown
      _focusNode.requestFocus();

      // Small delay to allow the editable to update its internal layout
      await Future.delayed(const Duration(milliseconds: 50));

      // Try to use bringIntoView if available, with fallback
      try {
        // Use dynamic call to bringIntoView
        await (_codeController as dynamic).bringIntoView(
          TextPosition(offset: offset),
        );
      } on NoSuchMethodError catch (e) {
        print('bringIntoView not available: $e');
        // Fallback: use Scrollable.ensureVisible on EditableText
        if (_codeFieldKey.currentContext != null) {
          final editableContext = _findEditableTextContext(
            _codeFieldKey.currentContext!,
          );
          if (editableContext != null) {
            try {
              await Scrollable.ensureVisible(
                editableContext,
                alignment: 0.5,
                duration: const Duration(milliseconds: 150),
                curve: Curves.easeInOut,
              );
            } catch (err) {
              print('Scrollable.ensureVisible failed: $err');
            }
          } else {
            print('EditableText context not found for ensureVisible');
          }
        } else {
          print('CodeFieldKey context is null');
        }
      } catch (e) {
        print('bringIntoView failed: $e');
      }

      // Force a rebuild so the caret position is reflected
      if (mounted) setState(() {});
    });
  }

  void _onCodeChanged() {
    // Always trigger a rebuild when selection or text changes
    setState(() {
      // Mark as dirty if text has changed and wasn't already dirty
      if (!_isDirty) {
        _isDirty = true;
      }
    });

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
}
