import 'package:fide/constants/constants.dart';
import 'package:fide/models/status_tone.dart';
import 'package:fide/widgets/app_text_field.dart';
import 'package:fide/widgets/message_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Convenience methods for showing messages
/// Represents `MessageBox`.
class MessageBox {
  /// Shows an error message overlay, with a button to copy the text.
  static void showError(BuildContext context, String message) {
    _showMessage(context, message, StatusTone.error);
  }

  /// Shows an informational message overlay.
  static void showInfo(BuildContext context, String message) {
    _showMessage(context, message, StatusTone.info);
  }

  /// Shows a success message overlay.
  static void showSuccess(BuildContext context, String message) {
    _showMessage(context, message, StatusTone.success);
  }

  /// Shows a warning message overlay.
  static void showWarning(BuildContext context, String message) {
    _showMessage(context, message, StatusTone.warning);
  }

  /// Copies [text] to the clipboard and confirms it with [confirmation].
  static void copyToClipboard(
    BuildContext context,
    String text, {
    String confirmation = 'Copied to clipboard',
  }) {
    Clipboard.setData(ClipboardData(text: text));
    showSuccess(context, confirmation);
  }

  /// Shows read-only [content] under [title] with a Close button before
  /// any extra [actions]; [content] scrolls unless [scrollable] is false, for
  /// content that sizes and scrolls itself.
  static Future<void> showDetails(
    BuildContext context, {
    required Widget title,
    required Widget content,
    List<Widget> actions = const [],
    bool scrollable = true,
  }) {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: title,
        content: scrollable ? SingleChildScrollView(child: content) : content,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          ...actions,
        ],
      ),
    );
  }

  /// Asks for a line of text, starting from [initialText]; resolves to the
  /// trimmed text when [confirmLabel] is pressed, null on Cancel or
  /// dismissal; [keyboardType] picks the on-screen keyboard.
  static Future<String?> promptForText(
    BuildContext context, {
    required String title,
    required String labelText,
    required String hintText,
    required String confirmLabel,
    String initialText = '',
    TextInputType? keyboardType,
  }) async {
    // Not disposed here: the dialog's field still uses it while the route
    // animates out after showDialog returns
    final controller = TextEditingController(text: initialText);
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: AppTextField(
          controller: controller,
          labelText: labelText,
          hintText: hintText,
          keyboardType: keyboardType,
          autofocus: true,
          onSubmitted: (text) => Navigator.of(context).pop(text.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
  }

  /// Asks the user to confirm a destructive action; resolves true only when
  /// [confirmLabel] is pressed, false on Cancel or dismissal.
  static Future<bool> confirm(
    BuildContext context, {
    required String title,
    required String message,
    required String confirmLabel,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  /// Presents an overlay message bar of [type], dismissed automatically
  /// after that type's display duration.
  static void _showMessage(
    BuildContext context,
    String message,
    StatusTone type,
  ) {
    final duration = switch (type) {
      StatusTone.success => AppDuration.messageSuccess,
      StatusTone.warning => AppDuration.messageWarning,
      StatusTone.error => AppDuration.messageError,
      StatusTone.info || StatusTone.neutral => AppDuration.messageInfo,
    };
    // Errors are the messages users need to copy into reports
    final showCopyButton = type == StatusTone.error;
    final overlay = Overlay.of(context);
    final overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        bottom: MediaQuery.of(context).padding.bottom + AppSpacing.medium,
        left: 0,
        right: 0,
        child: MessageWidget(
          message: message,
          type: type,
          duration: duration,
          showCloseButton: true,
          showCopyButton: showCopyButton,
          onClose: () {
            // This will be called when the message is dismissed
          },
        ),
      ),
    );

    overlay.insert(overlayEntry);

    // Auto remove after duration
    Future.delayed(duration, () {
      if (overlayEntry.mounted) {
        overlayEntry.remove();
      }
    });
  }
}
