import 'package:fide/providers/editor_commands.dart';
import 'package:fide/widgets/message_box.dart';
import 'package:flutter/material.dart';

/// "Go to Line" dialog for the active editor.
class GotoLineDialog {
  /// Navigates [editor] to the line number in [value] and closes the dialog.
  static Future<void> _goToLine(
    String value,
    BuildContext context,
    EditorCommands editor,
  ) async {
    if (value.isEmpty) return;

    final lineNumber = int.tryParse(value);
    if (lineNumber != null && lineNumber > 0) {
      // Navigate to the line
      editor.navigateToLine(lineNumber);
      Navigator.of(context).pop();
    } else {
      // Show error for invalid input
      MessageBox.showError(context, 'Please enter a valid line number');
    }
  }

  /// Shows the dialog; a valid entry moves [editor]'s caret to that line.
  static void show(BuildContext context, EditorCommands editor) {
    final TextEditingController lineController = TextEditingController();
    final FocusNode focusNode = FocusNode();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Go to Line'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: lineController,
                focusNode: focusNode,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Line number',
                  hintText: 'Enter line number',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (value) {
                  _goToLine(value, context, editor);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                _goToLine(lineController.text, context, editor);
              },
              child: const Text('Go'),
            ),
          ],
        );
      },
    );

    // Focus the text field when dialog opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      focusNode.requestFocus();
    });
  }
}
