// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'dart:io';
import 'package:code_text_field/code_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;
import 'package:highlight/languages/dart.dart';
import 'package:highlight/languages/yaml.dart';
import 'package:flutter_ide/services/editor_service.dart';
import 'package:flutter_ide/screens/explorer/explorer_screen.dart';
import 'package:flutter_ide/widgets/save_file_dialog.dart';

class EditorScreen extends ConsumerStatefulWidget {
  const EditorScreen({super.key});

  @override
  ConsumerState<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends ConsumerState<EditorScreen> {
  late CodeController _codeController;
  String _currentFile = 'untitled.dart';
  bool _isDirty = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _codeController = CodeController(
      text: '// Select a file to edit\n',
      language: dart,
    )..addListener(_onCodeChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Set up file change listener once when the widget is first built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final currentPath = ref.read(editorServiceProvider);
      if (currentPath != null) {
        _loadFile(currentPath);
      }

      // Set up listener for future changes
      ref.listenManual<String?>(editorServiceProvider, (previous, next) {
        if (next != null) {
          _loadFile(next);
        }
      });
    });
  }

  void _onCodeChanged() {
    if (!_isDirty) {
      setState(() => _isDirty = true);
    }
  }

  Future<void> _loadFile(String filePath) async {
    if (!mounted) return;

    setState(() => _isLoading = true);

    try {
      final file = File(filePath);
      final content = await file.readAsString();

      if (!mounted) return;

      setState(() {
        _currentFile = path.basename(filePath);
        _codeController = CodeController(
          text: content,
          language: _getLanguageForFile(_currentFile) ?? dart,
        )..addListener(_onCodeChanged);
        _isDirty = false;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading file: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  dynamic _getLanguageForFile(String filename) {
    final ext = filename.split('.').last.toLowerCase();
    switch (ext) {
      case 'dart':
        return dart;
      case 'yaml':
      case 'yml':
        return yaml;
      default:
        return null; // Default to plain text
    }
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

  @override
  void dispose() {
    _codeController.removeListener(_onCodeChanged);
    _codeController.dispose();
    super.dispose();
  }

  String? _getCurrentProjectRoot() {
    final currentPath = ref.read(editorServiceProvider);
    if (currentPath == null) return null;
    
    // If the current path is a file, get its parent directory
    if (FileSystemEntity.isFileSync(currentPath)) {
      return Directory(path.dirname(currentPath)).path;
    }
    // If it's a directory, use it as is
    return currentPath;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final currentProjectRoot = _getCurrentProjectRoot();

    // Set up keyboard shortcuts
    return FocusableActionDetector(
      autofocus: true,
      shortcuts: {
        const SingleActivator(LogicalKeyboardKey.keyS, meta: true):
            const ActivateIntent(),
        const SingleActivator(LogicalKeyboardKey.keyS, control: true):
            const ActivateIntent(),
      },
      actions: {
        ButtonActivateIntent: CallbackAction(onInvoke: (_) => _saveFile()),
      },
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Project Explorer
          Container(
            width: 280,
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[900] : Colors.grey[100],
              border: Border(
                right: BorderSide(
                  color: Theme.of(context).dividerColor,
                  width: 1,
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (currentProjectRoot != null)
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      children: [
                        const Icon(Icons.folder, size: 16, color: Colors.blue),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            path.basename(currentProjectRoot),
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                const Divider(height: 1, thickness: 1),
                Expanded(
                  child: ExplorerScreen(
                    onFileSelected: () {
                      // File opening is handled by the editor service listener
                    },
                  ),
                ),
              ],
            ),
          ),
          // Main content area
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Editor toolbar
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[900] : Colors.grey[100],
                    border: Border(
                      bottom: BorderSide(
                        color: Theme.of(context).dividerColor,
                        width: 1,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.description,
                        size: 18,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _currentFile,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const Spacer(),
                      if (_isDirty)
                        IconButton(
                          icon: const Icon(Icons.save, size: 20),
                          onPressed: _saveFile,
                          tooltip: 'Save (Ctrl+S / Cmd+S)',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          iconSize: 20,
                        ),
                    ],
                  ),
                ),
                // Code editor
                Expanded(
                  child: Stack(
                    children: [
                      CodeField(
                        controller: _codeController,
                        textStyle: const TextStyle(
                          fontFamily: 'RobotoMono',
                          fontSize: 14,
                          height: 1.5,
                        ),
                        background: isDark ? Colors.grey[900] : Colors.grey[50],
                        expands: true,
                        wrap: true,
                        lineNumberStyle: LineNumberStyle(
                          textStyle: TextStyle(
                            color: isDark ? Colors.grey[500] : Colors.grey[700],
                          ),
                        ),
                      ),
                      if (_isLoading)
                        Container(
                          color: Colors.black.withOpacity(0.5),
                          child: const Center(
                            child: CircularProgressIndicator(),
                          ),
                        ),
                    ],
                  ),
                ),
                // Status bar
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[900] : Colors.grey[100],
                    border: Border(
                      top: BorderSide(
                        color: Theme.of(context).dividerColor,
                        width: 1,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(
                        'Ln ${_codeController.selection.base.offset + 1}, ',
                        style: const TextStyle(fontSize: 12),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        'Col ${_codeController.selection.extent.offset - _codeController.selection.start + 1}',
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
          ),
        ],
      ),
    );
  }

  Future<void> _saveFile() async {
    var currentPath = ref.read(editorServiceProvider);

    // If no file is open, show save dialog
    final currentContext = context;
    if (currentPath == null || !await File(currentPath).exists()) {
      final result = await showDialog<String>(
        context: currentContext,
        builder: (context) => SaveFileDialog(initialName: _currentFile),
      );

      if (result == null || result.isEmpty) return;

      // Update the current path in the editor service
      ref.read(editorServiceProvider.notifier).updateCurrentPath(result);
      currentPath = result;
      setState(() => _currentFile = path.basename(currentPath!));
    }

    try {
      final file = File(currentPath);
      await file.writeAsString(_codeController.text);
      setState(() => _isDirty = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('File saved successfully'),
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving file: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }
}
