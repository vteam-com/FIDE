// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'badge_status.dart';

enum MessageType { success, warning, error, info }

class MessageWidget extends StatefulWidget {
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

  final bool autoDismiss;

  final Duration? duration;

  final String message;

  final VoidCallback? onClose;

  final bool showCloseButton;

  final bool showCopyButton;

  final MessageType type;

  @override
  State<MessageWidget> createState() => _MessageWidgetState();
}

class _MessageWidgetState extends State<MessageWidget>
    with TickerProviderStateMixin {
  late AnimationController _animationController;

  late Animation<double> _fadeAnimation;

  bool _showCopiedText = false;

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
                  SizedBox(
                    height: 32,
                    child: _showCopiedText
                        ? Center(
                            child: AnimatedOpacity(
                              opacity: _showCopiedText ? 1.0 : 0.0,
                              duration: const Duration(milliseconds: 200),
                              child: BadgeStatus.success(text: 'Copied'),
                            ),
                          )
                        : IconButton(
                            icon: Icon(
                              Icons.copy,
                              color: foregroundColor.withOpacity(0.7),
                              size: 18,
                            ),
                            onPressed: () async {
                              await Clipboard.setData(
                                ClipboardData(text: widget.message),
                              );
                              // Show "Copied" in place of the button
                              if (mounted) {
                                setState(() => _showCopiedText = true);
                                // Hide "Copied" after 1.5 seconds
                                Future.delayed(
                                  const Duration(milliseconds: 1500),
                                  () {
                                    if (mounted) {
                                      setState(() => _showCopiedText = false);
                                    }
                                  },
                                );
                              }
                            },
                            tooltip: 'Copy message',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
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

  void _dismiss() {
    _animationController.reverse().then((_) {
      widget.onClose?.call();
    });
  }
}
