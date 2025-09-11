// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum MessageType { success, warning, error, info }

class MessageWidget extends StatefulWidget {
  final String message;
  final MessageType type;
  final Duration? duration;
  final bool showCloseButton;
  final bool showCopyButton;
  final VoidCallback? onClose;
  final bool autoDismiss;

  const MessageWidget({
    super.key,
    required this.message,
    this.type = MessageType.info,
    this.duration,
    this.showCloseButton = true,
    this.showCopyButton = false,
    this.onClose,
    this.autoDismiss = true,
  });

  @override
  State<MessageWidget> createState() => _MessageWidgetState();
}

class _MessageWidgetState extends State<MessageWidget>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();

    if (widget.autoDismiss && widget.duration != null) {
      Future.delayed(widget.duration!, () {
        if (mounted) {
          _dismiss();
        }
      });
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _dismiss() {
    _animationController.reverse().then((_) {
      widget.onClose?.call();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    Color backgroundColor;
    Color foregroundColor;
    IconData icon;
    String semanticLabel;

    switch (widget.type) {
      case MessageType.success:
        backgroundColor = colorScheme.primaryContainer;
        foregroundColor = colorScheme.onPrimaryContainer;
        icon = Icons.check_circle;
        semanticLabel = 'Success message';
        break;
      case MessageType.warning:
        backgroundColor = colorScheme.tertiaryContainer;
        foregroundColor = colorScheme.onTertiaryContainer;
        icon = Icons.warning;
        semanticLabel = 'Warning message';
        break;
      case MessageType.error:
        backgroundColor = colorScheme.errorContainer;
        foregroundColor = colorScheme.onErrorContainer;
        icon = Icons.error;
        semanticLabel = 'Error message';
        break;
      case MessageType.info:
        backgroundColor = colorScheme.secondaryContainer;
        foregroundColor = colorScheme.onSecondaryContainer;
        icon = Icons.info;
        semanticLabel = 'Information message';
        break;
    }

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Tooltip(
        message: semanticLabel,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: foregroundColor.withOpacity(0.2),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: foregroundColor, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.message,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: foregroundColor,
                      height: 1.4,
                    ),
                  ),
                ),
                if (widget.showCopyButton) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(
                      Icons.copy,
                      color: foregroundColor.withOpacity(0.7),
                      size: 18,
                    ),
                    onPressed: () async {
                      await Clipboard.setData(
                        ClipboardData(text: widget.message),
                      );
                      // Show a brief confirmation that text was copied
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Message copied to clipboard',
                              style: TextStyle(color: foregroundColor),
                            ),
                            duration: const Duration(seconds: 2),
                            backgroundColor: backgroundColor,
                          ),
                        );
                      }
                    },
                    tooltip: 'Copy message',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                  ),
                ],
                if (widget.showCloseButton) ...[
                  const SizedBox(width: 4),
                  IconButton(
                    icon: Icon(
                      Icons.close,
                      color: foregroundColor.withOpacity(0.7),
                      size: 18,
                    ),
                    onPressed: _dismiss,
                    tooltip: 'Close message',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Convenience methods for showing messages
class MessageHelper {
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
        top: MediaQuery.of(context).padding.top + 8,
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
