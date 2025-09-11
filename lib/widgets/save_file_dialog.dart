import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;

class SaveFileDialog extends StatefulWidget {
  const SaveFileDialog({super.key, this.initialName = 'untitled.dart'});

  final String initialName;

  @override
  State<SaveFileDialog> createState() => _SaveFileDialogState();
}

class _SaveFileDialogState extends State<SaveFileDialog> {
  late final TextEditingController _controller;

  String? _directory;

  final bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Save File'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _controller,
            decoration: const InputDecoration(
              labelText: 'File name',
              border: OutlineInputBorder(),
            ),
            autofocus: true,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Text('Directory: '),
              Expanded(
                child: Text(
                  _directory ?? 'Not selected',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              TextButton(
                onPressed: _selectDirectory,
                child: const Text('Change'),
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isSaving || _controller.text.isEmpty
              ? null
              : () {
                  final fileName = _controller.text.trim();
                  final filePath = path.join(
                    _directory ?? '',
                    fileName.endsWith('.dart') ? fileName : '$fileName.dart',
                  );
                  Navigator.pop(context, filePath);
                },
          child: _isSaving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save'),
        ),
      ],
    );
  }

  Future<void> _selectDirectory() async {
    // TODO: Implement directory selection
    // For now, we'll just use the documents directory
    final directory = '/path/to/documents';
    setState(() => _directory = directory);
  }
}
