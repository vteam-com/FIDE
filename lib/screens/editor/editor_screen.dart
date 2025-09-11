// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'dart:io';
import 'package:code_text_field/code_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;
import 'package:highlight/languages/dart.dart';
import 'package:highlight/languages/yaml.dart';

class EditorScreen extends ConsumerStatefulWidget {
  final String filePath;

  const EditorScreen({super.key, required this.filePath});

  @override
  ConsumerState<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends ConsumerState<EditorScreen> {
  late CodeController _codeController;
  late String _currentFile;
  bool _isDirty = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _currentFile = widget.filePath;
    _codeController = CodeController(
      text: _currentFile.isNotEmpty
          ? '// Loading...\n'
          : '// No file selected\n',
      language: _getLanguageForFile(_currentFile),
    )..addListener(_onCodeChanged);

    if (_currentFile.isNotEmpty) {
      _loadFile(_currentFile);
    }
  }

  // Get the appropriate language mode based on file extension
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

  Future<void> _loadFile(String filePath) async {
    if (filePath.isEmpty) return;

    setState(() {
      _isLoading = true;
      _currentFile = filePath;
    });

    try {
      final file = File(filePath);
      if (await file.exists()) {
        final content = await file.readAsString();
        final language = _getLanguageForFile(filePath);

        if (mounted) {
          setState(() {
            _codeController.dispose();
            _codeController = CodeController(text: content, language: language)
              ..addListener(_onCodeChanged);
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

  void _onCodeChanged() {
    if (!_isDirty) {
      setState(() => _isDirty = true);
    }
  }

  String _getTitleForFile(String filePath) {
    if (filePath.isEmpty) return 'Untitled';
    return path.basename(filePath);
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

  Map<String, TextStyle> _getCodeTheme() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseTextColor = isDark ? Colors.white : Colors.black;

    return {
      'root': TextStyle(color: baseTextColor),
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

  @override
  void dispose() {
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(_getTitleForFile(_currentFile)),
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
            icon: const Icon(Icons.save),
            onPressed: _isDirty ? _saveFile : null,
            tooltip: 'Save',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _currentFile.isEmpty
          ? const Center(child: Text('No file selected'))
          : Column(
              children: [
                Expanded(
                  child: CodeTheme(
                    data: CodeThemeData(styles: _getCodeTheme()),
                    child: CodeField(
                      controller: _codeController,
                      textStyle: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 14,
                      ),
                      expands: true,
                      wrap: true,
                    ),
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
                        'Ln ${_codeController.selection.base.offset + 1}',
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
    );
  }
}
