import 'package:flutter/material.dart';
import '../widgets/message_widget.dart';

// Convenience methods for showing messages
class MessageBox {
  static void showSuccess(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 4),
    bool showCloseButton = true,
    bool showCopyButton = false,
  }) {
    _showMessage(
      context,
      message,
      MessageType.success,
      duration: duration,
      showCloseButton: showCloseButton,
      showCopyButton: showCopyButton,
    );
  }

  static void showWarning(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 6),
    bool showCloseButton = true,
    bool showCopyButton = false,
  }) {
    _showMessage(
      context,
      message,
      MessageType.warning,
      duration: duration,
      showCloseButton: showCloseButton,
      showCopyButton: showCopyButton,
    );
  }

  static void showError(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 8),
    bool showCloseButton = true,
    bool showCopyButton = true,
  }) {
    _showMessage(
      context,
      message,
      MessageType.error,
      duration: duration,
      showCloseButton: showCloseButton,
      showCopyButton: showCopyButton,
    );
  }

  static void showInfo(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 4),
    bool showCloseButton = true,
    bool showCopyButton = false,
  }) {
    _showMessage(
      context,
      message,
      MessageType.info,
      duration: duration,
      showCloseButton: showCloseButton,
      showCopyButton: showCopyButton,
    );
  }

  static void _showMessage(
    BuildContext context,
    String message,
    MessageType type, {
    required Duration duration,
    required bool showCloseButton,
    required bool showCopyButton,
  }) {
    final overlay = Overlay.of(context);
    final overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        bottom: MediaQuery.of(context).padding.bottom + 8,
        left: 0,
        right: 0,
        child: MessageWidget(
          message: message,
          type: type,
          duration: duration,
          showCloseButton: showCloseButton,
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
