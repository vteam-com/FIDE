import 'package:fide/constants/constants.dart';
import 'package:fide/widgets/message_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Convenience methods for showing messages
/// Represents `MessageBox`.
class MessageBox {
  /// Shows an error message overlay, with a button to copy the text.
  static void showError(BuildContext context, String message) {
    _showMessage(context, message, MessageType.error);
  }

  /// Shows an informational message overlay.
  static void showInfo(BuildContext context, String message) {
    _showMessage(context, message, MessageType.info);
  }

  /// Shows a success message overlay.
  static void showSuccess(BuildContext context, String message) {
    _showMessage(context, message, MessageType.success);
  }

  /// Shows a warning message overlay.
  static void showWarning(BuildContext context, String message) {
    _showMessage(context, message, MessageType.warning);
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
    MessageType type,
  ) {
    final duration = switch (type) {
      MessageType.success => AppDuration.messageSuccess,
      MessageType.warning => AppDuration.messageWarning,
      MessageType.error => AppDuration.messageError,
      MessageType.info => AppDuration.messageInfo,
    };
    // Errors are the messages users need to copy into reports
    final showCopyButton = type == MessageType.error;
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
