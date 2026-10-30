import 'package:fide/providers/editor_commands.dart';
import 'package:fide/widgets/message_box.dart';
import 'package:flutter/material.dart';

/// "Go to Line" dialog for the active editor.
class GotoLineDialog {
  /// Shows the dialog; a valid entry moves [editor]'s caret to that line.
  static Future<void> show(BuildContext context, EditorCommands editor) async {
    final value = await MessageBox.promptForText(
      context,
      title: 'Go to Line',
      labelText: 'Line number',
      hintText: 'Enter line number',
      confirmLabel: 'Go',
      keyboardType: TextInputType.number,
    );
    if (value == null || value.isEmpty) return;

    final lineNumber = int.tryParse(value);
    if (lineNumber != null && lineNumber > 0) {
      editor.navigateToLine(lineNumber);
    } else if (context.mounted) {
      MessageBox.showError(context, 'Please enter a valid line number');
    }
  }
}
