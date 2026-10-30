// ignore_for_file:  use_build_context_synchronously

import 'package:fide/constants/constants.dart';
import 'package:fide/models/status_tone.dart';
import 'package:fide/widgets/badge_status.dart';
import 'package:fide/widgets/compact_icon_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Represents `MessageWidget`.
class MessageWidget extends StatefulWidget {
  const MessageWidget({
    super.key,
    required this.message,
    this.type = StatusTone.info,
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

  final StatusTone type;

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
      duration: AppDuration.messageAnimation,
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
    String semanticLabel;

    switch (widget.type) {
      case StatusTone.success:
        backgroundColor = colorScheme.primaryContainer;
        foregroundColor = colorScheme.onPrimaryContainer;
        semanticLabel = 'Success message';
        break;
      case StatusTone.warning:
        backgroundColor = colorScheme.tertiaryContainer;
        foregroundColor = colorScheme.onTertiaryContainer;
        semanticLabel = 'Warning message';
        break;
      case StatusTone.error:
        backgroundColor = colorScheme.errorContainer;
        foregroundColor = colorScheme.onErrorContainer;
        semanticLabel = 'Error message';
        break;
      case StatusTone.info:
      case StatusTone.neutral:
        backgroundColor = colorScheme.secondaryContainer;
        foregroundColor = colorScheme.onSecondaryContainer;
        semanticLabel = 'Information message';
        break;
    }

    return FadeTransition(
      opacity: _fadeAnimation,
      // Shown in an overlay, outside any Material: this one gives the text
      // the theme's default style (no debug underline) and the buttons
      // their ink
      child: Material(
        type: MaterialType.transparency,
        child: Tooltip(
          message: semanticLabel,
          child: Container(
            margin: AppPadding.messageMargin,
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(AppRadius.medium),
              border: Border.all(
                color: foregroundColor.withValues(alpha: AppOpacity.selected),
                width: AppSize.borderThin,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: AppOpacity.subtle),
                  blurRadius: AppSpacing.tiny,
                  offset: const Offset(0, AppSpacing.micro),
                ),
              ],
            ),
            child: Padding(
              padding: AppPadding.actionTabContent,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    widget.type.icon,
                    color: foregroundColor,
                    size: AppIconSize.large,
                  ),
                  const SizedBox(width: AppSpacing.large),
                  Expanded(
                    child: Text(
                      widget.message,
                      style: AppTextStyle.label.copyWith(
                        color: foregroundColor,
                      ),
                    ),
                  ),
                  if (widget.showCopyButton) ...[
                    const SizedBox(width: AppSpacing.medium),
                    SizedBox(
                      height: AppSize.compactActionButton,
                      child: _showCopiedText
                          ? Center(
                              child: AnimatedOpacity(
                                opacity: _showCopiedText ? 1.0 : 0.0,
                                duration: AppDuration.copiedBadgeFade,
                                child: BadgeStatus.success(text: 'Copied'),
                              ),
                            )
                          : CompactIconButton(
                              icon: Icons.copy,
                              color: foregroundColor.withValues(
                                alpha: AppOpacity.secondaryText,
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
                                    AppDuration.copiedBadgeVisible,
                                    () {
                                      if (mounted) {
                                        setState(() => _showCopiedText = false);
                                      }
                                    },
                                  );
                                }
                              },
                              tooltip: 'Copy message',
                            ),
                    ),
                  ],
                  if (widget.showCloseButton) ...[
                    const SizedBox(width: AppSpacing.tiny),
                    CompactIconButton(
                      icon: Icons.close,
                      color: foregroundColor.withValues(
                        alpha: AppOpacity.secondaryText,
                      ),
                      onPressed: _dismiss,
                      tooltip: 'Close message',
                    ),
                  ],
                ],
              ),
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
