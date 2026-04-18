import 'package:fide/models/constants.dart';
import 'package:fide/widgets/message_widget.dart';
import 'package:flutter/material.dart';

// Convenience methods for showing messages
/// Represents `MessageBox`.
class MessageBox {
  /// Shows a success message overlay.
  static void showSuccess(
    BuildContext context,
    String message, {
    Duration duration = AppDuration.messageSuccess,
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

  /// Shows a warning message overlay.
  static void showWarning(
    BuildContext context,
    String message, {
    Duration duration = AppDuration.messageWarning,
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

  /// Shows an error message overlay.
  static void showError(
    BuildContext context,
    String message, {
    Duration duration = AppDuration.messageError,
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

  /// Shows an informational message overlay.
  static void showInfo(
    BuildContext context,
    String message, {
    Duration duration = AppDuration.messageInfo,
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

  /// Core implementation that presents an overlay message bar with the given [type] and [duration].
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
        bottom: MediaQuery.of(context).padding.bottom + AppSpacing.medium,
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
